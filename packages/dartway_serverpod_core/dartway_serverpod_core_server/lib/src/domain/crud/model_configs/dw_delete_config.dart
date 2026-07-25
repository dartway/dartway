// ignore_for_file: invalid_use_of_internal_member

import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:serverpod/serverpod.dart';

class DwDeleteConfig<T extends TableRow> {
  const DwDeleteConfig({this.allowDelete, this.afterDelete, this.broadcastTo});

  final Future<bool> Function(Session session, T model)? allowDelete;
  final Future<List<TableRow>> Function(Session session, T model)? afterDelete;

  /// The channels this deletion is broadcast to, so that a row vanishing for one
  /// user vanishes on the other screens too. The counterpart of
  /// `DwSaveConfig.broadcastTo`, and it carries the deleted model so the
  /// audience can depend on it (`['chat:${model.chatId}']`).
  ///
  /// Without it a delete reaches only the caller and everyone else keeps a row
  /// that is no longer there — usually noticed at the worst possible moment.
  /// Whatever channels a model's saves go to, its deletes almost always belong
  /// on the same ones.
  ///
  /// The same warning as on the save side: a channel is an audience the
  /// framework cannot check.
  final List<String> Function(Session session, T model)? broadcastTo;

  Future<DwApiResponse<bool>> delete(Session session, int modelId) async {
    final T? model = await session.db.findById<T>(modelId);

    if (model == null) {
      return DwApiResponse(
        isOk: true,
        value: true,
        warning: 'Model not found, possibly deleted earlier',
      );
    }

    if (allowDelete == null) {
      return DwApiResponse.notConfigured(source: 'delete $T');
    }

    if (true != await allowDelete?.call(session, model)) {
      return DwApiResponse.forbidden();
    }

    try {
      await session.db.deleteRow(model);
    } on DatabaseException {
      return DwApiResponse(
        isOk: false,
        value: false,
        error: 'Cannot delete model because other entities reference it',
      );
    }

    final updatedModels = [
      DwModelWrapper.deleted(object: model),
      if (afterDelete != null)
        ...(await afterDelete!(
          session,
          model,
        )).map((e) => DwModelWrapper(object: e)),
    ];

    if (broadcastTo != null) {
      final transport = DwUpdatesTransport(wrappedModelUpdates: updatedModels);
      for (final channel in broadcastTo!(session, model)) {
        session.messages.postMessage(channel, transport);
      }
    }

    return DwApiResponse(isOk: true, value: true, updatedModels: updatedModels);
  }
}
