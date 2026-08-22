import 'dart:async';

import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:serverpod/serverpod.dart';

import '../domain/dw_crud_entity.dart';
import '../../../private/dw_singleton.dart';

/// A refusal by a business rule, thrown from inside
/// [DwDtoActionConfig.actionProcessing].
///
/// The action runs inside a transaction and returns the models it touched, so
/// a rule that discovers halfway through that the answer is no — the message
/// was deleted a second ago, the track belongs to somebody else — has nothing
/// to return its refusal in; and throwing is in any case the only way to roll
/// a Serverpod transaction back. This is the throw that means "no", as opposed
/// to the throw that means "broken": [DwDtoActionConfig.save] catches it, the
/// transaction rolls back, and the caller is answered with [message] word for
/// word. No alert is raised — a rule saying no is not an incident.
///
/// ```dart
/// actionProcessing: (session, transaction, dto) async {
///   final post = await ChatPost.db.findById(session, dto.postId,
///       transaction: transaction);
///   if (post == null) throw const DwActionRejection('This message is gone');
///   ...
/// }
/// ```
///
/// A rule that can be answered before the transaction opens belongs in
/// [DwDtoActionConfig.validateAction] instead, which returns its text rather
/// than throwing it — the same answer to the caller, with no exception in the
/// way.
///
/// Thrown anywhere else, it is an ordinary exception with the ordinary
/// consequences: nothing outside [DwDtoActionConfig.save] knows what it means.
class DwActionRejection implements Exception {
  const DwActionRejection(this.message);

  /// The text the caller is shown, verbatim.
  final String message;

  @override
  String toString() => 'DwActionRejection: $message';
}

/// An action shaped as a save: an arbitrary transaction driven by a DTO that
/// has no table of its own.
///
/// The lifecycle, in order:
/// 1. [validateAction]       — the rules, before the transaction opens
/// 2. [actionProcessing]     — the work itself, inside the transaction
/// 3. [afterSaveSideEffects] — notifications and async tasks, outside it; the
///                             caller does not wait for them
///
/// **Refusing and failing are different answers, and the user can tell them
/// apart.** A refusal carries the text its author wrote — "this message is
/// gone", "you have no access to this track" — and passes through the
/// endpoint untouched. A failure is an incident: the guard around every CRUD
/// method replaces whatever was thrown with "Unexpected error while handling
/// the saveModel request for X" and reports it to [DwAlerts].
///
/// So refuse through [validateAction], or by throwing [DwActionRejection]
/// from inside [actionProcessing] — and not by throwing anything else. A bare
/// `throw Exception('Not enough rights to delete this message')` loses its
/// text on the way out and pages the operator instead of informing the user.
class DwDtoActionConfig<DTO extends SerializableModel> with DwCrudEntity<DTO> {
  const DwDtoActionConfig({
    this.allowAnonymous = false,
    this.validateAction,
    required this.actionProcessing,
    this.afterSaveSideEffects,
  });

  /// Whether a caller who is not signed in may reach this operation.
  ///
  /// Defaults to `false`: a CRUD endpoint is reachable without a session, so
  /// without this gate the operation is open to the internet. Not configured
  /// means not allowed. Set it to `true` deliberately, and only for data that
  /// genuinely precedes the login screen.
  final bool allowAnonymous;

  /// The rules that can be answered before any work starts: who the caller is,
  /// what they are allowed to do, whether the DTO makes sense. Return the
  /// error text to refuse the action — the caller gets it verbatim, nothing is
  /// reported to [DwAlerts], and [actionProcessing] never runs — or null to
  /// let it through.
  ///
  /// Runs **before** the transaction opens, so it reads the database as it was
  /// a moment ago. A rule two callers can race for — a seat, a slot, a
  /// balance — is checked inside [actionProcessing] instead, where the
  /// transaction is, and refused with [DwActionRejection].
  final Future<String?> Function(Session session, DTO dto)? validateAction;

  /// The action itself, inside a transaction: does the work and returns the
  /// models it touched, so the client can refresh them.
  ///
  /// Throw [DwActionRejection] to refuse — the transaction rolls back and the
  /// caller is told why, in the words written here. Any other exception is a
  /// failure: it rolls the transaction back too, but the caller is handed the
  /// generic "unexpected error" message and the operator is paged.
  final Future<List<DwModelWrapper>> Function(
    Session session,
    Transaction transaction,
    DTO dto,
  )
  actionProcessing;

  /// Side effects once the action's transaction has committed. Runs
  /// **outside** it, non-blocking.
  ///
  /// **Nobody waits for this hook, so nothing it does can reach the caller —
  /// including its failure.** The response has already been built and says
  /// `isOk`. A throw is reported to [DwAlerts] with the DTO's name and the
  /// stack trace, which reaches the operator and nobody else — a
  /// [DwActionRejection] included, since by now there is nothing left to
  /// refuse. Anything the caller must be told about belongs in
  /// [actionProcessing].
  final Future<void> Function(
    Session session,
    DTO dto,
    List<DwModelWrapper> updatedModels,
  )?
  afterSaveSideEffects;

  /// Runs [validateAction], then [actionProcessing] in a transaction, then
  /// fires the side effects.
  Future<DwApiResponse<DwModelWrapper>> save(Session session, DTO dto) async {
    // --- validateAction (before the transaction) ---
    if (validateAction != null) {
      final error = await validateAction!(session, dto);
      if (error != null) return _rejectedResponse(error);
    }

    // --- transaction block ---
    List<DwModelWrapper> updatedModels = [];

    try {
      await session.db.transaction((transaction) async {
        updatedModels = await actionProcessing(session, transaction, dto);
      });
    } on DwActionRejection catch (rejection) {
      // A rule said no. The transaction is rolled back; this is an answer to
      // the caller, not a failure — no alert, and the text is the author's.
      return _rejectedResponse(rejection.message);
    } on DatabaseException catch (e, stackTrace) {
      dw.alerts.reportError(
        'Database error while running the ${DTO.toString()} action',
        exception: e,
        stackTrace: stackTrace,
      );
      return DwApiResponse(
        isOk: false,
        value: null,
        error: 'Database error during save: $e',
      );
    }

    // --- afterSideEffects (outside the transaction, non-blocking) ---
    if (afterSaveSideEffects != null) {
      unawaited(_runSideEffects(session, dto, updatedModels));
    }

    return DwApiResponse(
      isOk: true,
      value: DwModelWrapper(object: dto),
      updatedModels: updatedModels,
    );
  }

  /// A refusal, answered in the words the rule was written in.
  ///
  /// Returned rather than thrown, which is the whole point: the endpoint's
  /// guard reports what reaches it and rewrites the message, so a refusal that
  /// travels as an exception arrives at the client as "Unexpected error" and
  /// at the operator as an incident. `notConfigured` and `notAuthenticated`
  /// take the same route out.
  DwApiResponse<DwModelWrapper> _rejectedResponse(String message) =>
      DwApiResponse.refusal(message);

  /// Runs [afterSaveSideEffects] with nobody waiting for it, and makes sure a
  /// failure still lands somewhere — unawaited, it would otherwise go to the
  /// zone's error handler and reach neither the caller nor the operator.
  ///
  /// The call is made inside the try, so a hook that throws before its first
  /// suspension point is caught too.
  Future<void> _runSideEffects(
    Session session,
    DTO dto,
    List<DwModelWrapper> updatedModels,
  ) async {
    try {
      await afterSaveSideEffects!(session, dto, updatedModels);
    } catch (exception, stackTrace) {
      dw.alerts.reportError(
        'Side effect failed after the ${DTO.toString()} action',
        exception: exception,
        stackTrace: stackTrace,
      );
    }
  }
}
