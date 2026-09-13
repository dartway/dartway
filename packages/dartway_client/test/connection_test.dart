import 'dart:async';
import 'dart:convert';

import 'package:dartway_client/dartway_client.dart';
import 'package:dartway_client/testing.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  group('calls', () {
    test('fetch decodes the result with the request class', () async {
      final h = Harness()..serveRooms();
      await h.start();
      final result = await h.client.fetch(const ListRooms());
      expect(result, isA<DwOk<List<RoomView>>>());
      expect(result.valueOrNull, [a, b]);
    });

    test('fetch passes page parameters', () async {
      final h = Harness();
      h.server.onRequest<FeedRooms>(
        (r, call) => DwOk(dwFakePage([a, b, c], call.page, pageSize: 2)),
      );
      await h.start();
      final result = await h.client.fetch(
        const FeedRooms(),
        page: const DwOffsetParams(2),
      );
      expect(result.valueOrNull!.items, [c]);
      expect(result.valueOrNull!.hasMore, isFalse);
    });

    test('command results, refusals and failures are typed', () async {
      final h = Harness();
      h.server.onCommand<RenameRoom>((command, call) {
        if (command.name == 'taken') {
          throw DwRefusalException(
            DwRefusal(RoomRefusal.nameTaken, params: {'name': command.name}),
          );
        }
        if (command.name == 'boom') {
          return const DwFailed<RoomView>('incident-1');
        }
        return DwOk(RoomView(id: command.roomId, name: command.name));
      });
      await h.start();

      final ok = await h.client.command(const RenameRoom(roomId: 1, name: 'x'));
      expect(ok.valueOrNull, const RoomView(id: 1, name: 'x'));

      final refused = await h.client.command(
        const RenameRoom(roomId: 1, name: 'taken'),
      );
      expect(
        refused,
        isA<DwRefused<RoomView>>().having(
          (r) => r.refusal,
          'refusal',
          DwRefusal(RoomRefusal.nameTaken, params: {'name': 'taken'}),
        ),
      );
      expect(() => refused.valueOrThrow, throwsA(isA<DwRefusalException>()));

      final failed = await h.client.command(
        const RenameRoom(roomId: 1, name: 'boom'),
      );
      expect(failed, isA<DwFailed<RoomView>>());
      expect(
        () => failed.valueOrThrow,
        throwsA(const DwFailedException('incident-1')),
      );
    });

    test('every command call carries a fresh idempotency key', () async {
      final h = Harness();
      h.server.onCommand<RenameRoom>(
        (c, call) => DwOk(RoomView(id: c.roomId, name: c.name)),
      );
      await h.start();
      await h.client.command(const RenameRoom(roomId: 1, name: 'x'));
      await h.client.command(const RenameRoom(roomId: 1, name: 'x'));
      final keys = h.server
          .commandsOf<RenameRoom>()
          .map((m) => m.idempotencyKey)
          .toSet();
      expect(keys, hasLength(2));
      expect(keys.every((k) => k.length == 32), isTrue);
    });

    test(
      'calls made before start are queued and sent once connected',
      () async {
        final h = Harness()..serveRooms();
        final pending = h.client.fetch(const ListRooms());
        await settle();
        expect(h.server.connections, isEmpty);
        await h.client.start();
        expect((await pending).valueOrNull, [a, b]);
      },
    );

    test('a one-shot call times out with a typed exception', () async {
      final h = Harness(
        options: const DwClientOptions(
          callTimeout: Duration(milliseconds: 30),
          releaseDelay: Duration.zero,
        ),
      );
      h.server.acceptsConnections = false;
      await h.client.start();
      await expectLater(
        h.client.fetch(const ListRooms()),
        throwsA(
          isA<DwTimeoutException>().having((e) => e.call, 'call', 'ListRooms'),
        ),
      );
    });

    test(
      'an undecodable result fails the call with a protocol exception',
      () async {
        final h = Harness();
        h.server.onRequest<ListRooms>(
          (r, call) => Completer<DwResult<Object?>>().future,
        );
        await h.start();
        final connection = h.server.openConnections.single;
        // The handler never answers; the test answers with garbage.
        final result = h.client.fetch(const ListRooms());
        await pumpEventQueue();
        final id = h.server.receivedOf<DwRequestMessage>().last.id;
        connection.sendFrame(
          jsonEncode({'k': 'res', 'id': id, 's': 'ok', 'v': 'not a list'}),
        );
        await expectLater(result, throwsA(isA<DwProtocolException>()));
      },
    );

    test('stop completes unanswered calls and refuses new ones', () async {
      final h = Harness();
      h.server.onRequest<ListRooms>(
        (r, call) => Completer<DwResult<Object?>>().future,
      );
      await h.start();
      final pending = h.client.fetch(const ListRooms());
      final watch = h.client.watch(const ListRooms());
      final states = DwRecording(watch.states);
      await settle();
      final stopped = expectLater(
        pending,
        throwsA(isA<DwClientStoppedException>()),
      );
      await h.client.stop();
      await stopped;
      await expectLater(
        h.client.fetch(const ListRooms()),
        throwsA(isA<DwClientStoppedException>()),
      );
      expect(() => h.client.watch(const ListRooms()), throwsStateError);
      await settle();
      expect(states.isDone, isTrue);
    });
  });

  group('reconnect', () {
    test(
      'reports its status and reconnects after the server drops it',
      () async {
        final h = Harness()..serveRooms();
        final statuses = DwRecording(h.client.connectionStatuses);
        await h.start();
        expect(h.client.connectionStatus, DwConnectionStatus.connected);

        await h.server.dropConnections();
        await until(
          () =>
              h.server.openConnections.length == 1 &&
              h.client.connectionStatus == DwConnectionStatus.connected,
        );
        expect(h.server.connections, hasLength(2));
        expect(
          statuses.values,
          containsAllInOrder([
            DwConnectionStatus.disconnected,
            DwConnectionStatus.connecting,
            DwConnectionStatus.connected,
            DwConnectionStatus.disconnected,
            DwConnectionStatus.connecting,
            DwConnectionStatus.connected,
          ]),
        );
      },
    );

    test(
      'keeps trying while the server is unreachable, then connects',
      () async {
        final h = Harness()..serveRooms();
        h.server.acceptsConnections = false;
        await h.client.start();
        final pending = h.client.fetch(const ListRooms());
        await Future<void>.delayed(const Duration(milliseconds: 40));
        expect(h.client.connectionStatus, isNot(DwConnectionStatus.connected));
        h.server.acceptsConnections = true;
        expect((await pending).valueOrNull, [a, b]);
      },
    );

    test(
      'a command lost with the connection is re-sent with the same key',
      () async {
        final h = Harness();
        var runs = 0;
        h.server.onCommand<RenameRoom>((command, call) {
          runs++;
          // The first delivery never answers: the connection dies meanwhile.
          if (runs == 1) return Completer<DwResult<Object?>>().future;
          return DwOk(RoomView(id: command.roomId, name: command.name));
        });
        await h.start();

        final result = h.client.command(const RenameRoom(roomId: 1, name: 'x'));
        await settle();
        await h.server.dropConnections();

        expect((await result).valueOrNull, const RoomView(id: 1, name: 'x'));
        final messages = h.server.commandsOf<RenameRoom>();
        expect(messages, hasLength(2));
        expect(messages[0].idempotencyKey, messages[1].idempotencyKey);
        expect(
          messages[0].id,
          messages[1].id,
          reason: 'the same call, re-sent',
        );
      },
    );

    test(
      'a command whose outcome was stored is answered, not run again',
      () async {
        final h = Harness();
        var dropped = false;
        h.server.onCommand<RenameRoom>((c, call) async {
          if (!dropped) {
            // The outcome is stored, but its answer dies with the connection.
            dropped = true;
            await call.connection.close();
          }
          return DwOk(RoomView(id: c.roomId, name: c.name));
        });
        await h.start();
        final result = await h.client.command(
          const RenameRoom(roomId: 1, name: 'x'),
        );
        expect(result.valueOrNull, const RoomView(id: 1, name: 'x'));
        final messages = h.server.commandsOf<RenameRoom>();
        expect(messages, hasLength(2));
        expect(h.server.executions(messages.first.idempotencyKey), 1);
      },
    );

    test(
      're-subscribes active channels and re-runs watches, showing old data as refreshing',
      () async {
        final h = Harness()..serveRooms();
        await h.start();
        final watch = h.client.watch(const ListRooms());
        final room = h.client.watch(const GetRoom(1));
        final states = DwRecording(watch.states);
        await settle();
        expect(h.server.subscribeCount(rooms), 1);

        h.server.acceptsConnections = false;
        await h.server.dropConnections();
        await settle();
        expect(
          watch.state,
          const DwRequestData([a, b]),
          reason: 'kept, not live',
        );

        h.rooms = [a, b, c]; // changed while offline: missed updates
        h.server.acceptsConnections = true;
        await until(() => watch.isLive && dataOf(watch.state).length == 3);

        expect(h.server.subscribeCount(rooms), 2);
        expect(h.server.subscribeCount(const DwChannel(AppChannel.room, 1)), 2);
        expect(h.server.requestsOf<ListRooms>(), hasLength(2));
        expect(h.server.requestsOf<GetRoom>(), hasLength(2));
        expect(room.isLive, isTrue);
        expect(
          states.values,
          contains(
            isA<DwRequestData<List<RoomView>>>().having(
              (d) => d.refreshing,
              'refreshing',
              true,
            ),
          ),
        );
        expect(
          states.values.whereType<DwRequestLoading<List<RoomView>>>(),
          hasLength(1),
          reason: 'only before the first answer',
        );
      },
    );

    test('an unanswered watch request is sent again, not duplicated', () async {
      final h = Harness();
      var calls = 0;
      h.server.onRequest<ListRooms>((r, call) {
        calls++;
        return calls == 1
            ? Completer<DwResult<Object?>>().future
            : const DwOk([a]);
      });
      await h.start();
      final watch = h.client.watch(const ListRooms());
      await settle();
      await h.server.dropConnections();
      await until(() => watch.state is DwRequestData);
      await settle();
      expect(calls, 2);
      expect(dataOf(watch.state), [a]);
    });

    test('queued commands go out before re-runs', () async {
      final h = Harness()..serveRooms();
      h.server.onCommand<RenameRoom>(
        (c, call) => DwOk(RoomView(id: c.roomId, name: c.name)),
      );
      await h.start();
      h.client.watch(const ListRooms());
      await settle();
      h.server.acceptsConnections = false;
      await h.server.dropConnections();
      await settle();
      final command = h.client.command(const RenameRoom(roomId: 1, name: 'x'));
      h.server.received.clear();
      h.server.acceptsConnections = true;
      await command;
      await settle();
      final order = h.server.received
          .where((m) => m is DwCommandMessage || m is DwRequestMessage)
          .map((m) => m.runtimeType)
          .toList();
      expect(order, [DwCommandMessage, DwRequestMessage]);
    });

    test(
      'a connection that answers nothing for a whole window is dropped',
      () async {
        final h = Harness(
          options: const DwClientOptions(
            callTimeout: Duration(milliseconds: 40),
            reconnectDelay: Duration(milliseconds: 1),
            releaseDelay: Duration.zero,
          ),
        );
        var calls = 0;
        h.server.onRequest<ListRooms>((r, call) {
          calls++;
          return calls == 1
              ? Completer<DwResult<Object?>>().future
              : const DwOk([a]);
        });
        await h.start();
        final watch = h.client.watch(const ListRooms());
        await until(
          () => watch.state is DwRequestData,
          reason: 'the dead connection is replaced',
        );
        expect(h.server.connections, hasLength(2));
      },
    );
  });
}
