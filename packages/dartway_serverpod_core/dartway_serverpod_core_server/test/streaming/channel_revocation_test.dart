import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:dartway_serverpod_core_server/src/private/dw_channel_stream.dart';
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

import '../support/streaming_session_double.dart';

/// Revoking a user's authentication has to reach the connections they already
/// hold. Ordinary requests need nothing: `dwAuthenticationHandler` reads the key
/// from the database every time, so deleting the row ends them. A websocket
/// resolved its authentication once, when it opened — without this, a banned
/// user keeps receiving their own updates until they close the app themselves.
///
/// Serverpod broadcasts the revocation but acts on it only for endpoints that
/// declare `requireLogin` or scopes, and `DwCrudEndpoint` declares neither: one
/// endpoint serves the public catalogue and the private order list alike. So
/// this is the framework's own listener, and these are the tests that say it
/// works.
void main() {
  const channelName = 'userUpdates42';

  late MessageCentral messageCentral;
  late FakeStreamingSession session;

  /// The auth key row id, as `DwAuth` puts it on the session.
  const authId = '7';

  FakeStreamingSession signedInSession(
    String label, {
    String userIdentifier = '42',
    String keyId = authId,
  }) => FakeStreamingSession(
    label,
    messageCentral,
    authenticated: AuthenticationInfo(
      userIdentifier,
      const <Scope>{},
      authId: keyId,
    ),
  );

  /// What `DwAuth.revokeAuthKeys` broadcasts, delivered the way message central
  /// delivers it locally.
  Future<void> revokeEverySessionOf(String userIdentifier) =>
      messageCentral.postMessage(
        MessageCentralServerpodChannels.revokedAuthentication(userIdentifier),
        RevokedAuthenticationUser(),
      );

  setUp(() {
    messageCentral = MessageCentral();
    session = signedInSession('subscriber');
  });

  test('ends the subscription with a serializable refusal', () async {
    final errors = <Object>[];
    var completed = false;

    final subscription = openChannelStream<SerializableModel>(
      session,
      channelName,
    ).listen((_) {}, onError: errors.add, onDone: () => completed = true);

    await revokeEverySessionOf('42');
    await settleStreamEvents();

    // Serializable, because a bare error reaches the client as an ordinary
    // closed connection — which it would then reconnect its way out of.
    expect(errors, hasLength(1));
    expect(errors.single, isA<DwChannelClosed>());
    expect(
      (errors.single as DwChannelClosed).reason,
      DwChannelClosedReason.authenticationRevoked,
    );
    expect(completed, isTrue);

    await subscription.cancel();
  });

  test('delivers nothing more once the authentication is gone', () async {
    final delivered = <SerializableModel>[];

    final subscription = openChannelStream<SerializableModel>(
      session,
      channelName,
    ).listen(delivered.add, onError: (_) {});

    await revokeEverySessionOf('42');
    await session.messages.postMessage(channelName, ChannelPing());
    await settleStreamEvents();

    expect(delivered, isEmpty);
    await subscription.cancel();
  });

  test('leaves no listener behind on either channel', () async {
    final subscription = openChannelStream<SerializableModel>(
      session,
      channelName,
    ).listen((_) {}, onError: (_) {});

    await revokeEverySessionOf('42');
    await settleStreamEvents();

    // Both the channel listener and the revocation listener: a teardown that
    // takes back one of the two leaks the session just as surely as one that
    // takes back neither.
    expect(session.channelMessages.activeListenerCount, 0);
    expect(session.pendingWillCloseListenerCount, 0);

    await subscription.cancel();
  });

  test('leaves the other users listening', () async {
    final otherSession = signedInSession('other', userIdentifier: '43');
    final receivedByOther = <SerializableModel>[];

    final revokedSubscription = openChannelStream<SerializableModel>(
      session,
      channelName,
    ).listen((_) {}, onError: (_) {});
    final otherSubscription = openChannelStream<SerializableModel>(
      otherSession,
      'userUpdates43',
    ).listen(receivedByOther.add);

    await revokeEverySessionOf('42');
    await otherSession.messages.postMessage('userUpdates43', ChannelPing());
    await settleStreamEvents();

    expect(receivedByOther, hasLength(1));

    await revokedSubscription.cancel();
    await otherSubscription.cancel();
  });

  test('ends every channel the revoked user was listening to', () async {
    final endedChannels = <String>[];

    final subscriptions = [
      for (final channel in [channelName, 'orders42', 'dwPublicUpdates'])
        openChannelStream<SerializableModel>(session, channel).listen(
          (_) {},
          onError: (error) =>
              endedChannels.add((error as DwChannelClosed).channel),
        ),
    ];

    await revokeEverySessionOf('42');
    await settleStreamEvents();

    // The public channel too: what ends is the session, not one audience.
    expect(endedChannels, [channelName, 'orders42', 'dwPublicUpdates']);
    expect(session.channelMessages.activeListenerCount, 0);

    for (final subscription in subscriptions) {
      await subscription.cancel();
    }
  });

  group('revocation that is not this session', () {
    test('another user being revoked changes nothing', () async {
      final errors = <Object>[];

      final subscription = openChannelStream<SerializableModel>(
        session,
        channelName,
      ).listen((_) {}, onError: errors.add);

      await revokeEverySessionOf('43');
      await session.messages.postMessage(channelName, ChannelPing());
      await settleStreamEvents();

      expect(errors, isEmpty);
      await subscription.cancel();
    });

    test('a different key of the same user changes nothing', () async {
      // "Sign out on this device" revokes one key. The phone that stayed signed
      // in keeps its subscriptions.
      final errors = <Object>[];

      final subscription = openChannelStream<SerializableModel>(
        session,
        channelName,
      ).listen((_) {}, onError: errors.add);

      await messageCentral.postMessage(
        MessageCentralServerpodChannels.revokedAuthentication('42'),
        RevokedAuthenticationAuthId(authId: '99'),
      );
      await settleStreamEvents();

      expect(errors, isEmpty);
      await subscription.cancel();
    });

    test('this session\'s own key being revoked ends it', () async {
      final errors = <Object>[];

      final subscription = openChannelStream<SerializableModel>(
        session,
        channelName,
      ).listen((_) {}, onError: errors.add);

      await messageCentral.postMessage(
        MessageCentralServerpodChannels.revokedAuthentication('42'),
        RevokedAuthenticationAuthId(authId: authId),
      );
      await settleStreamEvents();

      expect(errors, hasLength(1));
      await subscription.cancel();
    });
  });

  test('an anonymous subscription listens for no revocation', () async {
    final anonymousSession = FakeStreamingSession('anonymous', messageCentral);

    final subscription = openChannelStream<SerializableModel>(
      anonymousSession,
      'dwPublicUpdates',
    ).listen((_) {});

    // One listener, on the channel itself — there is no user whose revocation
    // this session could be waiting for.
    expect(anonymousSession.channelMessages.activeListenerCount, 1);

    await subscription.cancel();
    expect(anonymousSession.channelMessages.activeListenerCount, 0);
  });
}
