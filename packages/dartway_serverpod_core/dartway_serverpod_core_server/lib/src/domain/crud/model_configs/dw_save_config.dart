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

  /// Saves [model], running the lifecycle described on [DwSaveConfig].
  Future<DwApiResponse<DwModelWrapper>> save(Session session, T model) async {
    final isInsert = model.id == null;
    final initialModel = isInsert
        ? null
        : await session.db.findById<T>(model.id!);

    if (initialModel == null && !isInsert) {
      return DwApiResponse(
        isOk: false,
        value: null,
        error: 'Model with id ${model.id} not found (possibly deleted earlier)',
      );
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

        // beforeSave — prepare the model, and check the rules that need live
        // data. Rejecting throws: that is what rolls the transaction back.
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
      });
    } on _DwSaveRejection catch (rejection) {
      // A rule said no. The transaction is rolled back; this is an answer to
      // the caller, not a failure — no alert.
      return DwApiResponse(isOk: false, value: null, error: rejection.message);
    } on DatabaseException catch (e, stackTrace) {
      dw.alerts.reportError(
        'Database error while saving ${T.toString()}',
        exception: e,
        stackTrace: stackTrace,
      );
      return DwApiResponse(
        isOk: false,
        value: null,
        error: 'Database error during save: $e',
      );
    }

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
}
