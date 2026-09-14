import 'dart:async';
import 'dart:math';

import 'package:dartway_client/dartway_client.dart';
import 'package:dartway_client/testing.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  group('the socket is opened on demand', () {
    test('a request without channels opens no socket', () async {
      final h = Harness()..serveRooms();
      await h.start();
      final watch = h.client.watch(const ListRoomsOffline());
      await settle();
      expect(dataOf(watch.state), [a, b]);
      expect(watch.isLive, isFalse);
      expect(h.server.connections, isEmpty);
      expect(h.client.connectionStatus, DwConnectionStatus.idle);
    });

    test(
      'a live request authenticates, subscribes, and only then fetches',
      () async {
        final h = Harness()..serveRooms();
        final subscribedWhenFetched = <bool>[];
        h.server.onRequest<ListRooms>((request, call) {
          subscribedWhenFetched.add(
            h.server.subscriberCount(roomsChannel) == 1,
          );
          return DwCallOk(h.rooms.toList());
        });
        await h.start();
        final watch = h.client.watch(const ListRooms());
        await settle();

        expect(watch.state, const DwRequestData([a, b], live: true));
        expect(subscribedWhenFetched, [true]);
        final connection = h.server.connections.single;
        expect(connection.url.path, '/dw/live');
        expect(connection.url.queryParameters, {
          'protocol': '1',
          'app': '1.0.0+1',
        });
        expect(h.server.received.map((m) => m.runtimeType).toList(), [
          DwAuthenticateMessage,
          DwSubscribeMessage,
        ]);
        expect(h.client.connectionStatus, DwConnectionStatus.connected);
      },
    );

    test(
      'closing the last watch unsubscribes and closes the idle socket',
      () async {
        final h = Harness()..serveRooms();
        await h.start();
        final first = h.client.watch(const ListRooms());
        final second = h.client.watch(const ListRoomsByRank());
        await settle();
        expect(h.server.subscribeCount(roomsChannel), 1, reason: 'shared');

        first.close();
        await settle();
        expect(h.server.unsubscribeCount(roomsChannel), 0);
        second.close();
        await settle();
        expect(h.server.unsubscribeCount(roomsChannel), 1);
        expect(h.server.openConnections, isEmpty);
        expect(h.client.connectionStatus, DwConnectionStatus.idle);
      },
    );
  });

  group('updates', () {
    test("another client's command reaches a watch over the socket", () async {
      final h = Harness()..serveRooms();
      await h.start();
      final watch = h.client.watch(const ListRooms());
      await settle();

      final other = h.server.newClient(tokenStore: DwMemoryTokenStore(bob));
      addTearDown(other.stop);
      await other.start();
      await other.command(const RenameRoom(roomId: 1, name: 'a2'));
      await settle();

      expect(dataOf(watch.state), [
        const RoomView(id: 1, name: 'a2', rank: 10),
        b,
      ]);
      expect(h.server.requestsOf<ListRooms>(), hasLength(1));
    });

    test(
      "the author's own update comes in the response, not over the socket",
      () async {
        final h = Harness()..serveRooms();
        await h.start();
        final watch = h.client.watch(const ListRooms());
        await settle();
        final connection = h.server.connections.single;
        final updatesBefore = h.server.sent.whereType<DwUpdateMessage>().length;

        final result = await h.client.command(
          const RenameRoom(roomId: 2, name: 'b2'),
        );
        await settle();

        final call = h.server.callsOf<RenameRoom>().single;
        expect(call.liveConnectionId, connection.id);
        expect((call.response as DwApiOk).updates.objects, [
          result.valueOrNull,
        ]);
        expect(
          h.server.sent.whereType<DwUpdateMessage>().length,
          updatesBefore,
          reason: 'the named connection is excluded from the broadcast',
        );
        expect(dataOf(watch.state), [a, result.valueOrNull]);
      },
    );

    test(
      'what a refused command published reaches the author over the socket',
      () async {
        final h = Harness()..serveRooms();
        h.server.onCommand<RenameRoom>((command, call) {
          call.publish(roomsChannel, [c]);
          return DwCallRefused<RoomView>(DwCallRefusal(RoomRefusal.nameTaken));
        });
        await h.start();
        final watch = h.client.watch(const ListRooms());
        await settle();
        final result = await h.client.command(
          const RenameRoom(roomId: 1, name: 'x'),
        );
        expect(result, isA<DwCallRefused>());
        final call = h.server.callsOf<RenameRoom>().single;
        expect(call.liveConnectionId, isNotNull);
        await settle();
        expect(dataOf(watch.state), [c, a, b]);
      },
    );

    test(
      'an update for a channel this client is not subscribed to is ignored',
      () async {
        final h = Harness()..serveRooms();
        await h.start();
        final watch = h.client.watch(const ListRooms());
        await settle();
        h.server.connections.single.send(
          DwUpdateMessage(channel: 'notes', updates: DwUpdateTransport([c])),
        );
        await settle();
        expect(dataOf(watch.state), [a, b]);
      },
    );

    test(
      'an unreadable update is reported and its channel refetched',
      () async {
        final h = Harness()..serveRooms();
        await h.start();
        final watch = h.client.watch(const ListRooms());
        await settle();
        h.rooms = [c, a, b];
        h.server.connections.single.sendFrame(
          '{"k":"upd","ch":"rooms","updates":{"Unknown":[{"id":1}]}}',
        );
        await settle();
        expect(h.takeReported<DwProtocolException>(), hasLength(1));
        expect(dataOf(watch.state), [c, a, b]);
        expect(h.server.requestsOf<ListRooms>(), hasLength(2));
      },
    );
  });

  group('reconnect', () {
    test(
      're-authenticates, re-subscribes and re-runs each live entry once',
      () async {
        final h = Harness()..serveRooms();
        await h.start();
        final live = h.client.watch(const ListRooms());
        final offline = h.client.watch(const ListRoomsOffline());
        await settle();
        expect(h.server.requestsOf<ListRooms>(), hasLength(1));

        h.rooms = [c, a, b];
        await h.server.dropConnections();
        await until(() => h.server.openConnections.length == 1);
        await settle();

        expect(h.server.receivedOf<DwAuthenticateMessage>(), hasLength(2));
        expect(h.server.subscribeCount(roomsChannel), 2);
        expect(live.state, const DwRequestData([c, a, b], live: true));
        expect(h.server.requestsOf<ListRooms>(), hasLength(2));
        expect(
          h.server.requestsOf<ListRoomsOffline>(),
          hasLength(1),
          reason: 'a request without channels does not depend on the socket',
        );
        expect(dataOf(offline.state), [a, b]);
      },
    );

    test(
      'while the socket is down calls still work and data is not live',
      () async {
        final h = Harness()..serveRooms();
        h.server.acceptsConnections = false;
        await h.start();
        final watch = h.client.watch(const ListRooms());
        await settle();

        // Fetched without waiting out the settle timeout: the socket failed.
        expect(watch.state, const DwRequestData([a, b]));
        expect(h.client.connectionStatus, DwConnectionStatus.disconnected);
        expect((await h.client.fetch(const GetRoom(1))).valueOrNull, a);

        h.rooms = [c, a, b];
        h.server.acceptsConnections = true;
        await until(() => watch.isLive);
        await settle();
        expect(
          dataOf(watch.state),
          [c, a, b],
          reason: 'fetched before the subscription, so fetched again after it',
        );
        expect(h.server.requestsOf<ListRooms>(), hasLength(2));
      },
    );

    test('a socket slow to come up does not hold the first fetch beyond the '
        'settle timeout', () async {
      final h = Harness()..serveRooms();
      final release = Completer<void>();
      final client = DwAppClient(
        protocol: roomsProtocol,
        baseUrl: h.server.baseUrl,
        appVersion: '1.0.0+1',
        random: Random(),
        tokenStore: DwMemoryTokenStore(alice),
        httpTransport: h.server.httpTransport,
        liveConnector: DwMemoryLiveConnector((end, url) async {
          await release.future;
          await h.server.liveConnector.accept(end, url);
        }),
        options: const DwClientOptions(
          liveSettleTimeout: Duration(milliseconds: 300),
          releaseDelay: Duration.zero,
          liveIdleDelay: Duration.zero,
        ),
      );
      addTearDown(client.stop);
      await client.start();
      final watch = client.watch(const ListRooms());
      await pumpEventQueue();
      expect(watch.state, isA<DwRequestLoading>());
      await until(() => watch.state is DwRequestData);
      expect(watch.isLive, isFalse);

      release.complete();
      await until(() => watch.isLive);
      await settle();
      expect(h.server.requestsOf<ListRooms>(), hasLength(2));
    });

    test('a socket that never says hello is dropped and retried', () async {
      final h = Harness()..serveRooms();
      var attempts = 0;
      final client = DwAppClient(
        protocol: roomsProtocol,
        baseUrl: h.server.baseUrl,
        appVersion: '1.0.0+1',
        random: Random(),
        tokenStore: DwMemoryTokenStore(alice),
        httpTransport: h.server.httpTransport,
        liveConnector: DwMemoryLiveConnector((end, url) {
          attempts++;
          // Accepted, and silent.
          end.messages.listen((_) {});
        }),
        options: const DwClientOptions(
          callTimeout: Duration(milliseconds: 40),
          retryDelay: Duration(milliseconds: 1),
          maxRetryDelay: Duration(milliseconds: 2),
          liveSettleTimeout: Duration(milliseconds: 10),
        ),
      );
      addTearDown(client.stop);
      await client.start();
      client.watch(const ListRooms());
      await until(() => attempts >= 2);
    });

    test(
      'a close for what the client sent is reported and backed off',
      () async {
        final h = Harness()..serveRooms();
        await h.start();
        h.client.watch(const ListRooms());
        await settle();
        await h.server.connections.single.close(
          code: DwCloseCode.protocolError,
          reason: 'bad frame',
        );
        await until(() => h.server.openConnections.isNotEmpty);
        await settle();
        expect(
          h.takeReported<DwConnectionRejectedException>().single.closeCode,
          DwCloseCode.protocolError,
        );
      },
    );
  });

  group('subscriptions', () {
    test('a closed channel stops being live and is asked again', () async {
      final h = Harness()..serveRooms();
      await h.start();
      final watch = h.client.watch(const ListRooms());
      await settle();
      h.rooms = [a];
      h.server.closeChannel(roomsChannel);
      await settle();
      expect(watch.state, const DwRequestData([a]));
      expect(h.server.requestsOf<ListRooms>(), hasLength(2));
      expect(
        h.server.subscribeCount(roomsChannel),
        1,
        reason: 'not resubscribed',
      );
    });

    test('an unknown channel and a failed check are reported; a refusal for '
        'access is not', () async {
      final h = Harness()..serveRooms();
      h.server
        ..failingChannels.add('room:1')
        ..subscriptionRule = (channel, connection) => switch (channel) {
          'rooms' => DwCallRefusal(DwCoreRefusal.unknownChannel),
          'chat' => DwCallRefusal(DwCoreRefusal.forbidden),
          _ => null,
        };
      h.chat = const [ChatLine(id: 1, at: 1, text: 'hi')];
      await h.start();
      final rooms = h.client.watch(const ListRooms());
      final room = h.client.watch(const GetRoom(1));
      final chat = h.client.watchWindow(const ReadChat());
      await settle();

      expect(rooms.state, const DwRequestData([a, b]));
      expect(dataOf(room.state), a);
      expect(dataOf(chat.state).items, hasLength(1));
      expect(
        h.takeReported<DwChannelRefusedException>().single.channel,
        'rooms',
      );
      expect(
        h.takeReported<DwChannelFailedException>().single.incidentId,
        DwFakeServer.subscriptionIncident,
      );
    });

    test(
      'an anonymous client is refused subscriptions and fetches at once',
      () async {
        final h = Harness(signedIn: false)..serveRooms();
        await h.start();
        final watch = h.client.watch(const ListRooms());
        await settle();
        expect(watch.state, const DwRequestData([a, b]));
        expect(
          h.server.sent
              .whereType<DwSubscriptionRefusedMessage>()
              .single
              .isUnauthenticated,
          isTrue,
        );
        expect(
          h.server.receivedOf<DwAuthenticateMessage>(),
          isEmpty,
          reason: 'no session, no authentication',
        );
      },
    );
  });

  group('incompatibility on the socket', () {
    test('an incompatible close is terminal', () async {
      final h = Harness()..serveRooms();
      h.server.minAppBuild = 5;
      await h.start();
      final statuses = DwStreamRecording(h.client.connectionStatusStream);
      final watch = h.client.watch(const ListRooms());
      await settle();

      expect(
        h.client.incompatibility,
        DwCallRefusal(DwCoreRefusal.updateRequired),
      );
      expect(statuses.last, DwConnectionStatus.incompatible);
      expect(
        watch.state,
        DwRequestRefused<List<RoomView>>(
          DwCallRefusal(DwCoreRefusal.updateRequired),
        ),
      );
      final connections = h.server.connections.length;
      final calls = h.server.calls.length;
      expect(
        await h.client.fetch(const GetRoom(1)),
        isA<DwCallRefused>().having(
          (r) => r.refusal.isCode(DwCoreRefusal.updateRequired),
          'updateRequired',
          isTrue,
        ),
      );
      await settle();
      expect(
        h.server.connections,
        hasLength(connections),
        reason: 'no reconnect',
      );
      expect(h.server.calls, hasLength(calls), reason: 'calls fail fast');
    });
  });
}
