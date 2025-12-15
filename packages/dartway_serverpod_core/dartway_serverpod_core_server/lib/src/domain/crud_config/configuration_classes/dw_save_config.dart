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
    this.validateSave,
    this.beforeSaveTransaction,
    this.afterSaveTransaction,
    this.afterSaveTransform,
    this.afterSaveSideEffects,
  });

  /// Проверка прав (insert & update).
  final Future<bool> Function(Session session, DwSaveContext<T> saveContext)
  allowSave;

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
    final initialModel =
        isInsert ? null : await session.db.findById<T>(model.id!);

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

        // beforeSave — подготовка модели
        if (beforeSaveTransaction != null) {
          await beforeSaveTransaction!(session, saveContext);
        }

        // основной insert / update
        saveContext.currentModel =
            saveContext.isInsert
                ? await session.db.insertRow<T>(
                  saveContext.currentModel,
                  transaction: transaction,
                )
                : await session.db.updateRow<T>(
                  saveContext.currentModel,
                  transaction: transaction,
                );

        // afterSave — дополнительные действия в БД
        if (afterSaveTransaction != null) {
          await afterSaveTransaction!(session, saveContext);
        }
      });
    } on DatabaseException catch (e) {
      // TODO: Добавить логирование ошибки и алертинг
      return DwApiResponse(
        isOk: false,
        value: null,
        error: 'Database error during save: $e',
      );
    }

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
}
