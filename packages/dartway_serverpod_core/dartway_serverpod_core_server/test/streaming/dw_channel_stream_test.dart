import 'package:dartway_serverpod_core_server/src/private/dw_channel_stream.dart';
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

import '../support/method_stream_teardown.dart';
import '../support/streaming_session_double.dart';

/// A closed streaming session must leave nothing of itself behind in the
/// message central: every leftover reference keeps the session alive, and with
/// it the request, the buffered session log and the socket it came in on. On an
/// unstable network those add up to a connection graph every few seconds.
void main() {
  const channelName = 'teardownProbe';

  late MessageCentral messageCentral;
  late FakeStreamingSession session;

  setUp(() {
    messageCentral = MessageCentral();
    session = FakeStreamingSession('subscriber', messageCentral);
  });

  /// The stream `subscribeOnUpdates` hands to Serverpod, guard and all — the
  /// `async*` wrapper is part of the teardown path, so it is part of what these
  /// tests exercise. Who may listen is decided in dw_channel_config_test.dart;
  /// here the answer is always yes.
  Stream<SerializableModel> subscribeThroughEndpoint(Session session) =>
      guardedChannelStream<SerializableModel>(
        session,
        channelName,
        canListen: (_, __) async => true,
      );

  group('openChannelStream delivery', () {
    test('delivers the messages posted to the channel', () async {
      final receivedMessages = <SerializableModel>[];
      final subscription = openChannelStream<SerializableModel>(
        session,
        channelName,
      ).listen(receivedMessages.add);

      await messageCentral.postMessage(channelName, ChannelPing());
      await settleStreamEvents();

      expect(receivedMessages, hasLength(1));
      await subscription.cancel();
    });

    test('reports a message of an unexpected type as a stream error', () async {
      final streamErrors = <Object>[];
      final subscription = openChannelStream<ChannelPing>(
        session,
        channelName,
      ).listen((_) {}, onError: streamErrors.add);

      await messageCentral.postMessage(channelName, ChannelPong());
      await settleStreamEvents();

      expect(streamErrors, hasLength(1));
      await subscription.cancel();
    });

    test('keeps other subscribers alive when one of them leaves', () async {
      final otherSession = FakeStreamingSession('other', messageCentral);
      final receivedByOther = <SerializableModel>[];

      final leavingSubscription = openChannelStream<SerializableModel>(
        session,
        channelName,
      ).listen((_) {});
      final stayingSubscription = openChannelStream<SerializableModel>(
        otherSession,
        channelName,
      ).listen(receivedByOther.add);

      await leavingSubscription.cancel();
      await messageCentral.postMessage(channelName, ChannelPing());
      await settleStreamEvents();

      expect(receivedByOther, hasLength(1));
      await stayingSubscription.cancel();
    });
  });

  group('openChannelStream teardown', () {
    test(
      'releases the session when the socket takes the stream down',
      () async {
        final teardown = MethodStreamTeardown(
          session,
          subscribeThroughEndpoint,
        );

        await teardown.closeWithSocket();

        expect(session.channelMessages.activeListenerCount, 0);
        expect(session.pendingWillCloseListenerCount, 0);
      },
    );

    test('releases the session when a single stream is closed', () async {
      final teardown = MethodStreamTeardown(session, subscribeThroughEndpoint);

      await teardown.closeSingleStream();

      expect(session.channelMessages.activeListenerCount, 0);
      expect(session.pendingWillCloseListenerCount, 0);
    });

    test('releases the session across repeated socket teardowns', () async {
      final closedSessions = <FakeStreamingSession>[];

      for (var reconnect = 0; reconnect < 50; reconnect++) {
        final reconnectedSession = FakeStreamingSession(
          'reconnect$reconnect',
          messageCentral,
        );
        closedSessions.add(reconnectedSession);
        await MethodStreamTeardown(
          reconnectedSession,
          subscribeThroughEndpoint,
        ).closeWithSocket();
      }

      expect(
        closedSessions.map(
          (session) => session.channelMessages.activeListenerCount,
        ),
        everyElement(0),
      );
    });

    test('completes the stream when the session closes under it', () async {
      var streamCompleted = false;
      final subscription = subscribeThroughEndpoint(
        session,
      ).listen((_) {}, onDone: () => streamCompleted = true);

      await session.close();
      await settleStreamEvents();

      expect(streamCompleted, isTrue);
      expect(session.channelMessages.activeListenerCount, 0);
      await subscription.cancel();
    });

    test('closes a session whose stream nobody listened to', () async {
      subscribeThroughEndpoint(session);

      // Closing a controller without a subscriber never completes, so a
      // teardown that waits for it would hang the whole session close.
      await session.close().timeout(const Duration(seconds: 2));

      expect(session.channelMessages.activeListenerCount, 0);
    });
  });

  group('guardedChannelStream refusal', () {
    Stream<SerializableModel> refusedSubscription(Session session) =>
        guardedChannelStream<SerializableModel>(
          session,
          channelName,
          canListen: (_, __) async => false,
        );

    test('errors instead of delivering anything', () async {
      expect(refusedSubscription(session), emitsError(isException));
    });

    test('leaves no listener behind on the channel', () async {
      await expectLater(
        refusedSubscription(session).toList(),
        throwsA(isException),
      );

      expect(session.channelMessages.activeListenerCount, 0);
      expect(session.pendingWillCloseListenerCount, 0);
    });

    test('never yields what the channel carried during the check', () async {
      final delivered = <SerializableModel>[];

      final subscription = refusedSubscription(
        session,
      ).listen(delivered.add, onError: (_) {});
      await session.messages.postMessage(channelName, ChannelPing());
      await settleStreamEvents();

      expect(delivered, isEmpty);
      await subscription.cancel();
    });
  });
}
