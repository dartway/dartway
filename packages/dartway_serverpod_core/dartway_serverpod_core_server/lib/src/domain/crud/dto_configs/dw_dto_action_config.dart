import 'dart:async';

import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:serverpod/serverpod.dart';

import '../domain/dw_crud_entity.dart';
import '../../../private/dw_singleton.dart';

class DwDtoActionConfig<DTO extends SerializableModel> with DwCrudEntity<DTO> {
  const DwDtoActionConfig({
    this.allowAnonymous = false,
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
  /// stack trace, which reaches the operator and nobody else. Anything the
  /// caller must be told about belongs in [actionProcessing].
  final Future<void> Function(
    Session session,
    DTO dto,
    List<DwModelWrapper> updatedModels,
  )?
  afterSaveSideEffects;

  /// Runs [actionProcessing] in a transaction, then fires the side effects.
  Future<DwApiResponse<DwModelWrapper>> save(Session session, DTO dto) async {
    // --- transaction block ---
    List<DwModelWrapper> updatedModels = [];

    try {
      await session.db.transaction((transaction) async {
        updatedModels = await actionProcessing(session, transaction, dto);
      });
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
