import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:serverpod/serverpod.dart';

import '../endpoints/dw_real_time_endpoint.dart';
import '../private/dw_singleton.dart';

extension DwSessionExtension on Session {
  Future<int?> get currentUserProfileId async =>
      await dw.currentUserProfile(this).then((value) => value?.id);

  Future<bool> isUser(int userProfileId) async =>
      userProfileId == await currentUserProfileId;

  /// Sends the models to every client listening on [channels].
  ///
  /// Each arriving model is routed by type into any `dw.repo.modelList<T>()`
  /// the subscribers hold, so a list already on screen redraws itself with no
  /// refresh code on either side.
  ///
  /// **A channel is an audience, and the framework cannot check who is in it.**
  /// What travels here reaches every subscriber, whether or not `accessFilter`
  /// would have shown them that row through the API. Scope the channel to the
  /// audience that may see the data — per chat, per team, per user — rather than
  /// sending private rows to a wide one.
  sendUpdates({
    required List<String> channels,
    List<TableRow?>? updatedModels,
    List<TableRow?>? deletedModels,
  }) {
    if (channels.isEmpty) return;

    final transport = DwUpdatesTransport(
      wrappedModelUpdates: [
        if (updatedModels != null) ...DwModelWrapper.wrapMany(updatedModels),
        if (deletedModels != null)
          ...deletedModels
              .where((e) => e != null)
              .map((e) => DwModelWrapper.deleted(object: e!)),
      ],
    );

    for (final channel in channels) {
      messages.postMessage(channel, transport);
    }
  }

  /// Sends the models to one user's private channel — the common case of
  /// [sendUpdates], and the safe one: the audience is a single known user.
  sendUpdatesToUser(
    int userProfileId, {
    List<TableRow?>? updatedModels,
    List<TableRow?>? deletedModels,
  }) => sendUpdates(
    channels: [DwRealTimeEndpoint.userUpdatesChannel(userProfileId)],
    updatedModels: updatedModels,
    deletedModels: deletedModels,
  );
}
