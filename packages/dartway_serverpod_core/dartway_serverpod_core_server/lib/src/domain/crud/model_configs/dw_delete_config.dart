// ignore_for_file: invalid_use_of_internal_member

import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:serverpod/serverpod.dart';

class DwDeleteConfig<T extends TableRow> {
  const DwDeleteConfig({
    this.allowAnonymous = false,this.allowDelete, this.afterDelete, this.broadcastTo});


  /// Whether a caller who is not signed in may reach this operation.
  ///
  /// Defaults to `false`: a CRUD endpoint is reachable without a session, so
  /// without this gate the operation is open to the internet. Not configured
  /// means not allowed. Set it to `true` deliberately, and only for data that
  /// genuinely precedes the login screen.
  final bool allowAnonymous;

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
    // Answer "not configured" before touching the database: without a rule for
    // who may delete, there is nothing to decide and nothing to reveal.
    if (allowDelete == null) {
      return DwApiResponse.notConfigured(source: 'delete $T');
    }

    final T? model = await session.db.findById<T>(modelId);

    if (model == null) {
      // Known gap, narrowed but not closed: a caller who may not delete still
      // tells a missing id ("ok") from a present one ("forbidden"). Anonymous
      // probing is gone — the endpoint now rejects unauthenticated callers
      // before this runs — so what remains is a signed-in user learning
      // whether a row exists.
      //
      // Closing it fully means answering `forbidden` here too, which would
      // report an error for the ordinary case of deleting a row someone else
      // already removed. That trade is a product decision, not a default the
      // framework should pick silently.
      return DwApiResponse(
        isOk: true,
        value: true,
        warning: 'Model not found, possibly deleted earlier',
      );
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
