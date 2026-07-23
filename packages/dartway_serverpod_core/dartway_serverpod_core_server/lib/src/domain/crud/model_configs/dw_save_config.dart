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
/// 6. [afterSaveTransform]    — enrich the model, outside the transaction
/// 7. [afterSaveSideEffects]  — notifications, async tasks, outside as well
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
    required this.allowSave,
    this.validateSave,
    this.beforeSaveTransaction,
    this.afterSaveTransaction,
    this.afterSaveTransform,
    this.afterSaveSideEffects,
    this.lockInitialModelForUpdate = false,
  });

  /// Who may save this model, on both insert and update. Required: a model
  /// with no rule is not saved by anyone.
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

  /// Enriches the saved model before it is returned. Runs **outside** the
  /// transaction and may be slow.
  final Future<void> Function(Session session, DwSaveContext<T> saveContext)?
  afterSaveTransform;

  /// Side effects: notifications, async tasks, anything the caller need not
  /// wait for. Runs **outside** the transaction, non-blocking.
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
      currentUserId: await session.currentUserProfileId,
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

        final context =
            DwSaveContext<T>(
              currentUserId: await session.currentUserProfileId,
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
            transaction: transaction,
          );

    // afterSave — further database work
    if (afterSaveTransaction != null) {
      final error = await afterSaveTransaction!(session, saveContext);
      if (error != null) throw _DwSaveRejection(error);
    }
  }

  /// Everything after the transaction commits — shared by both paths.
  Future<DwApiResponse<DwModelWrapper>> _finishSave(
    Session session,
    DwSaveContext<T> saveContext,
  ) async {
    // --- afterTransform (outside the transaction) ---
    if (afterSaveTransform != null) {
      await afterSaveTransform!(session, saveContext);
    }

    // --- afterSideEffects (outside the transaction, non-blocking) ---
    if (afterSaveSideEffects != null) {
      unawaited(afterSaveSideEffects!(session, saveContext));
    }

    // Collect everything the client should refresh.
    final updatedModels = [
      ...saveContext.beforeUpdates,
      DwModelWrapper(object: saveContext.currentModel),
      ...saveContext.afterUpdates,
    ];

    return DwApiResponse(
      isOk: true,
      value: DwModelWrapper(object: saveContext.currentModel),
      updatedModels: updatedModels,
    );
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
