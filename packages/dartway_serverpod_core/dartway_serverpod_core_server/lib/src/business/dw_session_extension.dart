import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:serverpod/serverpod.dart';

extension DwSessionExtension on Session {
  /// The profile id the caller presented a token for, or `null` for a caller
  /// with no session.
  ///
  /// Synchronous, and it costs nothing: Serverpod resolves authentication in
  /// the factory of every session type that can carry a key, before any
  /// endpoint code runs, and caches it on the session. `authenticated` is a
  /// plain getter over that cache.
  ///
  /// **It says the token is valid, not that the profile still exists.** Until
  /// 0.3.0 this read the whole profile row from the database, so a deleted
  /// profile whose token was still around came back as `null` — an aliveness
  /// check nobody wrote down, paid for with a query on every single request.
  /// The check now lives where it belongs: [DwAuth.revokeAuthKeys] ends a
  /// user's sessions when the account does, and orphaned keys are swept up by
  /// [DwOrphanedAuthKeyCleanup]. Use [DwCore.currentUserProfile] when you
  /// actually need the row.
  int? get signedInUserProfileId =>
      int.tryParse(authenticated?.userIdentifier ?? '');

  /// Whether [userProfileId] is the signed-in caller.
  ///
  /// Takes a non-nullable id on purpose. Written as a comparison against
  /// [signedInUserProfileId], an ownership check over a nullable column reads
  /// `null == null` for an anonymous caller and grants access — so the caller
  /// is made to resolve the absent case instead.
  bool isUser(int userProfileId) => userProfileId == signedInUserProfileId;

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
    channels: [DwCoreConst.userUpdatesChannel(userProfileId)],
    updatedModels: updatedModels,
    deletedModels: deletedModels,
  );
}
