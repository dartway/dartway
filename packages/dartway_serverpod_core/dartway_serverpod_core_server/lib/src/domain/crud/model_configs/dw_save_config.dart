// ignore_for_file: invalid_use_of_internal_member

import 'dart:async';

import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:serverpod/serverpod.dart';
import '../../../private/dw_singleton.dart';

/// How one model gets saved: who may do it, what makes it valid, and what
/// happens around the write.
///
/// The lifecycle, in order:
/// 1. [allowSave]             — permissions
/// 2. [validateSave]          — validation
/// 3. [beforeSaveTransaction] — prepare the model (inside the transaction)
/// 4. insert/update           — the write itself
/// 5. [afterSaveTransaction]  — further database work (inside the transaction)
/// 6. [afterSaveTransform]    — expected work after the write, outside the
///                              transaction; the caller waits for it
/// 7. [afterSaveSideEffects]  — notifications, async tasks, outside as well;
///                              the caller does not wait for it
///
/// Carries a rejection out of the transaction callback: throwing is the only
/// way to roll a Serverpod transaction back. Private on purpose — it never
/// leaves [DwSaveConfig.save], which turns it into an error response.
class _DwSaveRejection implements Exception {
  const _DwSaveRejection(this.message);

  final String message;
}

/// Note where the transaction starts: steps 1 and 2 run **before** it opens.
/// They see the database as it was a moment ago, so a rule that guards a shared
/// count — seats left, slots free, stock on hand — can be raced by a concurrent
/// save even though [validateSave] said yes to both. Enforce that kind of rule
/// in [beforeSaveTransaction], which runs inside the transaction and can reject
/// the save the same way: return the error text instead of null. [validateSave]
/// is where you check the model; [beforeSaveTransaction] is where you check the
/// world around it.
class DwSaveConfig<T extends TableRow> {
  const DwSaveConfig({
    this.allowAnonymous = false,
    required this.allowSave,
    this.validateSave,
    this.beforeSaveTransaction,
    this.afterSaveTransaction,
    this.afterSaveTransform,
    this.afterSaveSideEffects,
    this.lockInitialModelForUpdate = false,
    this.allowServerOnlyOverwrite = false,
    this.broadcastTo,
  });

  /// Who may save this model, on both insert and update. Required: a model
  /// with no rule is not saved by anyone.

  /// Whether a caller who is not signed in may reach this operation.
  ///
  /// Defaults to `false`: a CRUD endpoint is reachable without a session, so
  /// without this gate the operation is open to the internet. Not configured
  /// means not allowed. Set it to `true` deliberately, and only for data that
  /// genuinely precedes the login screen.
  final bool allowAnonymous;

  final Future<bool> Function(Session session, DwSaveContext<T> saveContext)
  allowSave;

  /// Validates the model. Return the error text to reject the save, or null to
  /// let it through. Runs before the transaction opens — see the note on
  /// [DwSaveConfig].
  final Future<String?> Function(Session session, DwSaveContext<T> saveContext)?
  validateSave;

  /// Prepares the model for the write, and is the place for any rule that must
  /// be evaluated against live data. Runs inside the transaction.
  ///
  /// Return the error text to reject the save — the transaction rolls back and
  /// the client gets that text, exactly as with [validateSave] — or null to let
  /// it through.
  final Future<String?> Function(Session session, DwSaveContext<T> saveContext)?
  beforeSaveTransaction;

  /// Further database work once the model is written. Runs inside the
  /// transaction, so it rolls back with it — including on a rejection: return
  /// the error text to undo the write, or null to keep it.
  final Future<String?> Function(Session session, DwSaveContext<T> saveContext)?
  afterSaveTransaction;

  /// The work that is expected to happen once the model is written, and that
  /// the caller is entitled to hear about: enriching the model before it is
  /// returned, and equally any step whose failure the caller must be told of —
  /// sending a verification code, handing a payment to a provider, calling out
  /// to a system the answer depends on. Runs **outside** the transaction, is
  /// awaited, and may be slow.
  ///
  /// Return the error text to turn the save into an error response, or null to
  /// let it through — the same contract as [validateSave] and
  /// [beforeSaveTransaction]. Throwing also reaches the caller, as the generic
  /// "unexpected error" message; returning the text is how the caller gets one
  /// worth showing.
  ///
  /// **A rejection here does not undo the write.** The transaction committed
  /// two steps ago, so the row stays saved and only the response says no. That
  /// is the intended trade: the alternative — deleting a committed row to
  /// report a failed email — is worse. Write the hook so that the caller
  /// retrying is harmless, and say in the error text that retrying is what
  /// they should do.
  ///
  /// **A rejection stops the two steps that follow**: [afterSaveSideEffects]
  /// does not run and [broadcastTo] sends nothing. Announcing a change to
  /// other users' screens while answering the caller with an error would be
  /// the less coherent of the two, and the row is still there for the next
  /// read.
  ///
  /// Anything the caller need not wait for belongs in [afterSaveSideEffects]
  /// instead — a slow step here is a slow response.
  final Future<String?> Function(Session session, DwSaveContext<T> saveContext)?
  afterSaveTransform;

  /// Side effects: notifications, async tasks, anything the caller need not
  /// wait for. Runs **outside** the transaction, non-blocking.
  ///
  /// **Nobody waits for this hook, so nothing it does can reach the caller —
  /// including its failure.** A throw here does not fail the save: the response
  /// has already been built and says `isOk`. The failure is reported to
  /// [DwAlerts] with the model's name and the stack trace, so it reaches the
  /// operator, and that is the whole of its audience.
  ///
  /// Which makes the choice between the two hooks a question about the user,
  /// not about timing: anything they must be told went wrong goes in
  /// [afterSaveTransform], which is awaited and can reject.
  final Future<void> Function(Session session, DwSaveContext<T> saveContext)?
  afterSaveSideEffects;

  /// Locks and re-reads the initial model inside the save transaction, before
  /// [allowSave] and [validateSave] run, for **updates**.
  ///
  /// By default the rules read the row outside the transaction and only the
  /// write happens inside it, so two concurrent saves of the same row can both
  /// read the same pre-state, both pass their checks, and both write — a lost
  /// update, or a rule quietly bypassed. Turning this on takes the row lock
  /// first, which serialises those saves: the second one waits, then re-reads
  /// what the first one actually wrote and re-runs the rules against it.
  ///
  /// Opt-in, so the default lifecycle is unchanged. Worth turning on for rows
  /// whose rules depend on their own current state (roles, consent flags,
  /// balances, a deletion marker). It has no effect on inserts — there is no
  /// row to lock yet — which is why those still validate before their
  /// transaction.
  final bool lockInitialModelForUpdate;

  /// Lets a save write `null` over a `scope=serverOnly` column that currently
  /// holds a value. Off by default, and the default is the one you want.
  ///
  /// A `serverOnly` field does not exist on the client class at all, so it is
  /// never in the JSON a client sends, and the server's `fromJson` reads the
  /// missing key as `null`. An update writes the whole row, so without this
  /// gate every client save would blank the column — no error, `isOk` in the
  /// response, the value simply gone. Left off, such a column is dropped from
  /// the `UPDATE` and the database keeps what it had.
  ///
  /// The exclusion is deliberately narrow: it applies only when the incoming
  /// model has `null` where the stored row has a value. A
  /// [beforeSaveTransaction] hook that *computes* a `serverOnly` value and
  /// assigns it writes that value normally — which is the whole point of
  /// computing it — because the incoming model is no longer null there.
  ///
  /// That leaves exactly one case this costs you: a hook that means to clear a
  /// `serverOnly` field back to `null`. Turn this on for that config, and
  /// accept that an ordinary client save will then blank the column too.
  ///
  /// **What the hooks see afterwards.** The model is not rebuilt from the
  /// database after the write, so from [afterSaveTransaction] onwards a
  /// `serverOnly` field on `currentModel` still holds what the client sent —
  /// `null` — even though the stored row kept its value. Nothing is lost to the
  /// caller, who cannot see the field either way. A hook that needs the stored
  /// value reads `saveContext.initialModel`.
  final bool allowServerOnlyOverwrite;

  /// The channels everything this save changed is broadcast to — so that one
  /// user's change lands on the other users' screens without a refresh.
  ///
  /// Answered per save, with the context in hand, because the audience usually
  /// depends on the row: a message goes to its chat, a booking to its session,
  /// a catalogue item to everyone. Return an empty list to send nothing.
  ///
  /// ```dart
  /// broadcastTo: (session, ctx) => [AppChannels.catalogue],
  /// broadcastTo: (session, ctx) => ['chat:${ctx.currentModel.chatId}'],
  /// ```
  ///
  /// Subscribers route each arriving model by type into any
  /// `dw.repo.modelList<T>()` they hold, so a list already on screen redraws
  /// itself — no listener to write on either side.
  ///
  /// **Null by default, and the default is the safe one.** A channel is an
  /// audience the framework cannot check: what you send reaches every
  /// subscriber, including users `accessFilter` would never have shown that row
  /// to. Scope the channel to the audience that may see the data; for rows that
  /// belong to one person, notify that person with `session.sendUpdatesToUser`.
  final List<String> Function(Session session, DwSaveContext<T> saveContext)?
  broadcastTo;

  /// Saves [model], running the lifecycle described on [DwSaveConfig].
  Future<DwApiResponse<DwModelWrapper>> save(Session session, T model) async {
    final isInsert = model.id == null;

    // Opt-in serialisation: take the row lock before the rules read the row, so
    // a concurrent save of the same row cannot slip between check and write.
    // Inserts have no row to lock yet, so they keep the default lifecycle.
    if (!isInsert && lockInitialModelForUpdate) {
      return _saveWithLockedInitialModel(session, model);
    }

    final initialModel = isInsert
        ? null
        : await session.db.findById<T>(model.id!);

    if (initialModel == null && !isInsert) {
      return _notFoundResponse(model.id!);
    }

    final saveContext = DwSaveContext<T>(
      currentUserId: session.signedInUserProfileId,
      isInsert: isInsert,
      initialModel: initialModel,
      currentModel: model,
    );

    // --- allowSave ---
    if (true != await allowSave(session, saveContext)) {
      return DwApiResponse.forbidden();
    }

    // --- validateSave ---
    if (validateSave != null) {
      final error = await validateSave!(session, saveContext);
      if (error != null) {
        return DwApiResponse(isOk: false, value: null, error: error);
      }
    }

    // --- transaction block ---
    try {
      await session.db.transaction((transaction) async {
        saveContext.transaction = transaction;
        await _writeInsideTransaction(session, saveContext, transaction);
      });
    } on _DwSaveRejection catch (rejection) {
      // A rule said no. The transaction is rolled back; this is an answer to
      // the caller, not a failure — no alert.
      return DwApiResponse(isOk: false, value: null, error: rejection.message);
    } on DatabaseException catch (e, stackTrace) {
      return _databaseErrorResponse(e, stackTrace);
    }

    return _finishSave(session, saveContext);
  }

  /// The update path with the row held from the first read through the write.
  ///
  /// Everything the default path does *before* the transaction — reading the
  /// initial model, [allowSave], [validateSave] — happens here *inside* it,
  /// against a row locked with `FOR UPDATE`. A concurrent save of the same row
  /// waits, then re-reads what this one committed and re-runs its own rules.
  Future<DwApiResponse<DwModelWrapper>> _saveWithLockedInitialModel(
    Session session,
    T model,
  ) async {
    DwSaveContext<T>? saveContext;
    DwApiResponse<DwModelWrapper>? earlyResponse;

    try {
      await session.db.transaction((transaction) async {
        final initialModel = await session.db.findById<T>(
          model.id!,
          transaction: transaction,
          lockMode: LockMode.forUpdate,
        );
        if (initialModel == null) {
          earlyResponse = _notFoundResponse(model.id!);
          return;
        }

        final context = DwSaveContext<T>(
          currentUserId: session.signedInUserProfileId,
          isInsert: false,
          initialModel: initialModel,
          currentModel: model,
        )..transaction = transaction;
        saveContext = context;

        // --- allowSave (under the lock) ---
        if (true != await allowSave(session, context)) {
          earlyResponse = DwApiResponse.forbidden();
          return;
        }

        // --- validateSave (under the lock) ---
        if (validateSave != null) {
          final error = await validateSave!(session, context);
          if (error != null) {
            earlyResponse = DwApiResponse(
              isOk: false,
              value: null,
              error: error,
            );
            return;
          }
        }

        await _writeInsideTransaction(session, context, transaction);
      });
    } on _DwSaveRejection catch (rejection) {
      return DwApiResponse(isOk: false, value: null, error: rejection.message);
    } on DatabaseException catch (e, stackTrace) {
      return _databaseErrorResponse(e, stackTrace);
    }

    final rejected = earlyResponse;
    if (rejected != null) return rejected;

    return _finishSave(session, saveContext!);
  }

  /// beforeSave → write → afterSave, all inside [transaction]. A rejecting rule
  /// throws, which is what rolls the transaction back.
  Future<void> _writeInsideTransaction(
    Session session,
    DwSaveContext<T> saveContext,
    Transaction transaction,
  ) async {
    // beforeSave — prepare the model, and check the rules that need live data.
    if (beforeSaveTransaction != null) {
      final error = await beforeSaveTransaction!(session, saveContext);
      if (error != null) throw _DwSaveRejection(error);
    }

    // the write itself
    saveContext.currentModel = saveContext.isInsert
        ? await session.db.insertRow<T>(
            saveContext.currentModel,
            transaction: transaction,
          )
        : await session.db.updateRow<T>(
            saveContext.currentModel,
            columns: _columnsToWrite(saveContext),
            transaction: transaction,
          );

    // afterSave — further database work
    if (afterSaveTransaction != null) {
      final error = await afterSaveTransaction!(session, saveContext);
      if (error != null) throw _DwSaveRejection(error);
    }
  }

  /// The columns this update may write, or `null` for "all of them" — which is
  /// what [Database.updateRow] means by an absent list, and what every save
  /// that has nothing to protect returns.
  ///
  /// Guards the `serverOnly` columns described on [allowServerOnlyOverwrite]:
  /// one whose incoming value is `null` while the stored row has a value is
  /// left out of the `UPDATE`, so the database keeps what it had.
  ///
  /// **How a `serverOnly` field is recognised without reflection.** The
  /// generator writes two maps for every model — `toJson` carries them,
  /// `toJsonForProtocol` does not — so the difference between the key sets is
  /// the answer, and it costs two map builds.
  ///
  /// **The difference is taken on [DwSaveContext.initialModel], the row as it
  /// is in the database, and that is not interchangeable with taking it on the
  /// type.** Both maps write a key under `if (value != null)`, so a nullable
  /// `serverOnly` column that is null in *this row* is missing from both and
  /// registers as no difference at all. That makes "this type has no
  /// `serverOnly` fields" a property of the row, never of the class — which is
  /// why the result must not be cached per type. A cached negative would turn
  /// one such row into a permanent hole for every other row of the same model.
  ///
  /// The length comparison is the cheap gate that keeps the rest rare:
  /// `toJsonForProtocol` is by construction a subset of `toJson`, so equal
  /// sizes mean equal key sets and there is nothing to protect. Two map builds
  /// against the `findById`, the transaction and the `UPDATE` around them are
  /// microseconds against milliseconds.
  List<Column>? _columnsToWrite(DwSaveContext<T> saveContext) {
    if (allowServerOnlyOverwrite) return null;

    final initialModel = saveContext.initialModel;
    // Inserts never get here — there is no stored row to protect.
    if (initialModel == null || initialModel is! ProtocolSerialization) {
      return null;
    }

    final stored = initialModel.toJson();
    final wire = (initialModel as ProtocolSerialization).toJsonForProtocol();
    if (stored is! Map<String, dynamic> || wire is! Map<String, dynamic>) {
      return null;
    }
    if (stored.length == wire.length) return null;

    final incoming = saveContext.currentModel.toJson();
    if (incoming is! Map<String, dynamic>) return null;

    // A key the wire form drops, holding a value in the database, and absent
    // from what arrived. Both maps omit a null under `if (value != null)`, so
    // "absent from `incoming`" and "explicitly null" are the same thing here —
    // and they should be, since the client cannot express either one.
    final atRisk = {
      for (final key in stored.keys)
        if (!wire.containsKey(key) && incoming[key] == null) key,
    };
    if (atRisk.isEmpty) return null;

    // Keyed by `fieldName`: it is the name the JSON uses, and it is not always
    // the name of the column (`Column.fieldName` falls back to `columnName`
    // only when the model does not remap it).
    //
    // Built from `managedColumns` rather than `columns` because that is what
    // `updateRow` writes when handed no list — starting anywhere else would
    // change more than the one thing this method is for.
    final managedColumns = saveContext.currentModel.table.managedColumns;
    final columns = managedColumns
        .where((column) => !atRisk.contains(column.fieldName))
        .toList();

    // Everything at risk turned out not to be a column — a `!persist` field,
    // say. Nothing to exclude, so hand back the default.
    return columns.length == managedColumns.length ? null : columns;
  }

  /// Everything after the transaction commits — shared by both paths.
  Future<DwApiResponse<DwModelWrapper>> _finishSave(
    Session session,
    DwSaveContext<T> saveContext,
  ) async {
    // --- afterTransform (outside the transaction, awaited) ---
    // A rejection here cannot roll anything back — the transaction committed
    // before this method was called — so the row stays written and only the
    // response says no. See [afterSaveTransform].
    if (afterSaveTransform != null) {
      final error = await afterSaveTransform!(session, saveContext);
      if (error != null) {
        return DwApiResponse(isOk: false, value: null, error: error);
      }
    }

    // --- afterSideEffects (outside the transaction, non-blocking) ---
    if (afterSaveSideEffects != null) {
      unawaited(_runSideEffects(session, saveContext));
    }

    // Collect everything the client should refresh.
    final updatedModels = [
      ...saveContext.beforeUpdates,
      DwModelWrapper(object: saveContext.currentModel),
      ...saveContext.afterUpdates,
    ];

    // The caller gets these back in the response either way; the channels get
    // the same set. Non-blocking: nobody waits on a socket.
    if (broadcastTo != null) {
      final transport = DwUpdatesTransport(wrappedModelUpdates: updatedModels);
      for (final channel in broadcastTo!(session, saveContext)) {
        session.messages.postMessage(channel, transport);
      }
    }

    return DwApiResponse(
      isOk: true,
      value: DwModelWrapper(object: saveContext.currentModel),
      updatedModels: updatedModels,
    );
  }

  /// Runs [afterSaveSideEffects] with nobody waiting for it, and makes sure a
  /// failure still lands somewhere.
  ///
  /// Unawaited, an exception thrown in here goes to the zone's error handler
  /// and no further: the caller already has its `isOk` response and cannot be
  /// told, and without this the operator was not told either — a misconfigured
  /// mail sender failed on every save and the only symptom was users not
  /// receiving anything.
  ///
  /// The call is made **inside** the try rather than awaited from outside it,
  /// so a hook that throws before its first suspension point is caught too;
  /// handed a future, this would have missed exactly those.
  Future<void> _runSideEffects(
    Session session,
    DwSaveContext<T> saveContext,
  ) async {
    try {
      await afterSaveSideEffects!(session, saveContext);
    } catch (exception, stackTrace) {
      dw.alerts.reportError(
        'Side effect failed after saving ${T.toString()}',
        exception: exception,
        stackTrace: stackTrace,
      );
    }
  }

  DwApiResponse<DwModelWrapper> _notFoundResponse(int id) => DwApiResponse(
    isOk: false,
    value: null,
    error: 'Model with id $id not found (possibly deleted earlier)',
  );

  DwApiResponse<DwModelWrapper> _databaseErrorResponse(
    DatabaseException exception,
    StackTrace stackTrace,
  ) {
    // Operators get the full exception through alerts; the caller gets a
    // stable, detail-free message. A raw DatabaseException carries table and
    // constraint names and the offending key value — handing that to a client
    // discloses the schema and, with a unique-constraint violation, whether a
    // given value already exists.
    dw.alerts.reportError(
      'Database error while saving ${T.toString()}',
      exception: exception,
      stackTrace: stackTrace,
    );
    return DwApiResponse(
      isOk: false,
      value: null,
      error: 'Database error during save',
    );
  }
}
