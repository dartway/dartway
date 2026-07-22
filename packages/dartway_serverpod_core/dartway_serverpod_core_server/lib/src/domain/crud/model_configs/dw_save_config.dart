// ignore_for_file: invalid_use_of_internal_member

import 'dart:async';

import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:serverpod/serverpod.dart';

/// Конфигурация процесса сохранения модели.
/// Позволяет полностью контролировать логику сохранения.
///
/// Общий жизненный цикл:
/// 1. [allowSave]        — проверка прав
/// 2. [validateSave]     — валидация данных
/// 3. [beforeSaveTransaction]       — подготовка модели (в транзакции)
/// 4. insert/update      — само сохранение
/// 5. [afterSaveTransaction]        — модификации в БД (в транзакции)
/// 6. [afterSaveTransform]   — обогащение модели вне транзакции
/// 7. [afterSaveSideEffects] — внешние задачи, уведомления и т.п.
class DwSaveConfig<T extends TableRow> {
  const DwSaveConfig({
    required this.allowSave,
    this.lockInitialModelForUpdate = false,
    this.validateSave,
    this.beforeSaveTransaction,
    this.afterSaveTransaction,
    this.afterSaveTransform,
    this.afterSaveSideEffects,
  });

  /// Проверка прав (insert & update).
  final Future<bool> Function(Session session, DwSaveContext<T> saveContext)
  allowSave;

  /// Locks and reloads the initial model inside the save transaction before
  /// running [allowSave] and [validateSave] for updates.
  ///
  /// This is opt-in to preserve the existing lifecycle by default. It has no
  /// effect on inserts, which continue to validate before their transaction.
  final bool lockInitialModelForUpdate;

  /// Валидация модели. Возвращает текст ошибки или null.
  final Future<String?> Function(Session session, DwSaveContext<T> saveContext)?
  validateSave;

  /// Подготовка модели перед сохранением.
  /// Выполняется внутри транзакции.
  final Future<void> Function(Session session, DwSaveContext<T> saveContext)?
  beforeSaveTransaction;

  /// Дополнительные модификации в БД.
  /// Выполняется внутри транзакции.
  final Future<void> Function(Session session, DwSaveContext<T> saveContext)?
  afterSaveTransaction;

  /// Обогащение модели после сохранения.
  /// Выполняется **вне транзакции**, может быть долгой или асинхронной.
  final Future<void> Function(Session session, DwSaveContext<T> saveContext)?
  afterSaveTransform;

  /// Побочные эффекты: уведомления, async-таски и пр.
  /// Выполняется **вне транзакции**, неблокирующе.
  final Future<void> Function(Session session, DwSaveContext<T> saveContext)?
  afterSaveSideEffects;

  /// Универсальный метод сохранения модели.
  Future<DwApiResponse<DwModelWrapper>> save(Session session, T model) async {
    final isInsert = model.id == null;

    if (!isInsert && lockInitialModelForUpdate) {
      return _saveLockedUpdate(session, model);
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

    final rejection = await _validate(session, saveContext);
    if (rejection != null) return rejection;

    // --- transaction block ---
    try {
      await session.db.transaction((transaction) async {
        await _persist(session, saveContext, transaction);
      });
    } on DatabaseException catch (e) {
      return _databaseErrorResponse(session, e);
    }

    return _completeSave(session, saveContext);
  }

  Future<DwApiResponse<DwModelWrapper>> _saveLockedUpdate(
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
          currentUserId: await session.currentUserProfileId,
          isInsert: false,
          initialModel: initialModel,
          currentModel: model,
        )..transaction = transaction;

        final rejection = await _validate(session, context);
        if (rejection != null) {
          earlyResponse = rejection;
          return;
        }

        await _persist(session, context, transaction);
        saveContext = context;
      });
    } on DatabaseException catch (e) {
      return _databaseErrorResponse(session, e);
    }

    if (earlyResponse != null) return earlyResponse!;
    return _completeSave(session, saveContext!);
  }

  Future<DwApiResponse<DwModelWrapper>?> _validate(
    Session session,
    DwSaveContext<T> saveContext,
  ) async {
    if (true != await allowSave(session, saveContext)) {
      return DwApiResponse.forbidden();
    }

    final error = await validateSave?.call(session, saveContext);
    if (error != null) {
      return DwApiResponse(isOk: false, value: null, error: error);
    }
    return null;
  }

  Future<void> _persist(
    Session session,
    DwSaveContext<T> saveContext,
    Transaction transaction,
  ) async {
    saveContext.transaction = transaction;

    if (beforeSaveTransaction != null) {
      await beforeSaveTransaction!(session, saveContext);
    }

    saveContext.currentModel = saveContext.isInsert
        ? await session.db.insertRow<T>(
            saveContext.currentModel,
            transaction: transaction,
          )
        : await session.db.updateRow<T>(
            saveContext.currentModel,
            transaction: transaction,
          );

    if (afterSaveTransaction != null) {
      await afterSaveTransaction!(session, saveContext);
    }
  }

  Future<DwApiResponse<DwModelWrapper>> _completeSave(
    Session session,
    DwSaveContext<T> saveContext,
  ) async {
    // --- afterTransform (вне транзакции) ---
    if (afterSaveTransform != null) {
      await afterSaveTransform!(session, saveContext);
    }

    // --- afterSideEffects (вне транзакции, неблокирующе) ---
    if (afterSaveSideEffects != null) {
      unawaited(afterSaveSideEffects!(session, saveContext));
    }

    // Собираем итоговые обновления.
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

  DwApiResponse<DwModelWrapper> _notFoundResponse(int modelId) {
    return DwApiResponse(
      isOk: false,
      value: null,
      error: 'Model with id $modelId not found (possibly deleted earlier)',
    );
  }

  DwApiResponse<DwModelWrapper> _databaseErrorResponse(
    Session session,
    DatabaseException exception,
  ) {
    session.log(
      'DwSaveConfig database error: ${exception.runtimeType}',
      level: LogLevel.error,
    );
    return DwApiResponse(
      isOk: false,
      value: null,
      error: 'Database error during save',
    );
  }
}
