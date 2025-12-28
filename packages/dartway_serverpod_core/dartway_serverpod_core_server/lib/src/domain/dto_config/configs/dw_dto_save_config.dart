import 'dart:async';

import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:serverpod/serverpod.dart';

import '../dw_dto_config.dart';

class DwDtoSaveConfig<DTO extends SerializableModel> extends DwDtoConfig<DTO> {
  const DwDtoSaveConfig({
    required this.saveProcessing,
    this.afterSaveSideEffects,
  });

  final Future<List<DwModelWrapper>> Function(
      Session session, Transaction transaction, DTO dto) saveProcessing;

  final Future<void> Function(
    Session session,
    DTO dto,
    List<DwModelWrapper> updatedModels,
  )? afterSaveSideEffects;

  /// Универсальный метод сохранения модели.
  Future<DwApiResponse<DwModelWrapper>> save(Session session, DTO dto) async {
    // --- transaction block ---
    List<DwModelWrapper> updatedModels = [];

    try {
      await session.db.transaction((transaction) async {
        updatedModels = await saveProcessing(session, transaction, dto);
      });
    } on DatabaseException catch (e) {
      // TODO: Добавить логирование ошибки и алертинг
      return DwApiResponse(
        isOk: false,
        value: null,
        error: 'Database error during save: $e',
      );
    }

    // --- afterSideEffects (вне транзакции, неблокирующе) ---
    if (afterSaveSideEffects != null) {
      unawaited(afterSaveSideEffects!(session, dto, updatedModels));
    }

    return DwApiResponse(
      isOk: true,
      value: null,
      updatedModels: updatedModels,
    );
  }
}
