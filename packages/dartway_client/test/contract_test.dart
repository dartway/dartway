import 'dart:async';
import 'dart:math';

import 'package:dartway_client/dartway_client.dart';
import 'package:dartway_client/testing.dart';
import 'package:test/test.dart';

import 'support.dart';

/// The client's side of the `dartway_core` contract: local validation, the
/// wire version, close codes, subscription failures and the echo of a
/// command's own updates (D-018).
void main() {
  group('local validation', () {
    test('an invalid command is refused without sending anything', () async {
      final h = Harness();
      h.server.onCommand<RenameRoom>(
        (c, call) => DwOk(RoomView(id: c.roomId, name: c.name)),
      );
      await h.start();
      final refused = await h.client.command(
        const RenameRoom(roomId: 1, name: ''),
      );
      expect(
        refused,
        isA<DwRefused<RoomView>>().having(
          (r) => r.refusal,
          'refusal',
          DwRefusal(DwCoreRefusal.invalid, field: 'name'),
        ),
      );
      expect(h.server.receivedOf<DwCommandMessage>(), isEmpty);

      final ok = await h.client.command(const RenameRoom(roomId: 1, name: 'x'));
      expect(ok.valueOrNull, const RoomView(id: 1, name: 'x'));
      expect(h.server.receivedOf<DwCommandMessage>(), hasLength(1));
    });

    test('an invalid fetch is refused without sending, even offline', () async {
      final h = Harness()..serveRooms();
      h.server.acceptsConnections = false;
      await h.client.start();
      final refused = await h.client.fetch(const ListRooms(minRank: -1));
      expect((refused as DwRefused<List<RoomView>>).refusal.field, 'minRank');
      expect(h.server.received, isEmpty);
    });

    test('an invalid watch shows the refusal, never fetches or subscribes, '
        'and stays quiet across reconnects', () async {
      final h = Harness()..serveRooms();
      await h.start();
      final watch = h.client.watch(const ListRooms(minRank: -1));
      final states = DwRecording(watch.states);
      final refusal = DwRefusal(
        DwCoreRefusal.invalid,
        field: 'minRank',
        params: {'min': 0},
      );
      expect(watch.state, DwRequestRefused<List<RoomView>>(refusal));
      await settle();

      await h.server.dropConnections();
      await until(
        () => h.client.connectionStatus == DwConnectionStatus.connected,
      );
      await watch.refetch();
      await settle();

      expect(h.server.requestsOf<ListRooms>(), isEmpty);
      expect(h.server.subscribeCount(rooms), 0);
      expect(states.values, [DwRequestRefused<List<RoomView>>(refusal)]);
    });
  });

  group('refusal codes', () {
    test('tooManyRequests and codeExpired reach the caller typed', () async {
      final h = Harness();
      h.server
        ..onCommand<DwRequestCode>(
          (c, call) => DwRefused<DwCodeTicket>(
            DwRefusal.tooManyRequests(const Duration(seconds: 42)),
          ),
        )
        ..onCommand<DwVerifyCode>(
          (c, call) => DwRefused<DwSession>(
            DwRefusal(DwCoreRefusal.codeExpired, field: 'code'),
          ),
        );
      await h.start();
      final limited = await h.client.command(
        const DwRequestCode(kind: DwIdentifierKind.email, identifier: 'a@b.c'),
      );
      final refusal = (limited as DwRefused<DwCodeTicket>).refusal;
      expect(refusal.isCode(DwCoreRefusal.tooManyRequests), isTrue);
      expect(refusal.retryAfter, const Duration(seconds: 42));

      final expired = await h.client.command(
        const DwVerifyCode(ticketId: 't', code: '123456'),
      );
      expect(
        (expired as DwRefused<DwSession>).refusal.isCode(
          DwCoreRefusal.codeExpired,
        ),
        isTrue,
      );
    });

    test('a failed subscription check is reported as a failure with its '
        'incident, and the data is not live', () async {
      final h = Harness()..serveRooms();
      h.server.failingChannels.add(rooms.wireName);
      await h.start();
      final watch = h.client.watch(const ListRooms());
      await settle();
      expect(watch.state, const DwRequestData([a, b]));
      expect(h.reported, [
        const DwFailedException(
          DwFakeServer.subscriptionIncident,
          call: 'subscribe rooms',
        ),
      ]);
      h.reported.clear();
    });
  });

  group('wire version', () {
    Future<Uri> connectedWith(Uri endpoint) async {
      final server = DwFakeServer(protocol: roomsProtocol);
      final client = DwClient(
        protocol: roomsProtocol,
        endpoint: endpoint,
        connector: server.connector,
        random: Random(1),
      );
      addTearDown(client.stop);
      await client.start();
      await settle();
      return server.connections.single.endpoint;
    }

    test('is appended to the endpoint, the rest of the query kept', () async {
      expect(
        (await connectedWith(Uri.parse('memory://x/dw'))).toString(),
        'memory://x/dw?v=$dwWireVersion',
      );
      expect(
        (await connectedWith(Uri.parse('memory://x/dw?tenant=a%20b&x'))).query,
        'tenant=a%20b&x&v=$dwWireVersion',
      );
      expect(
        (await connectedWith(
          Uri.parse('memory://x/dw?v=$dwWireVersion&tenant=a'),
        )).query,
        'v=$dwWireVersion&tenant=a',
      );
    });

    test('another version on the server is terminal: no reconnects, a typed '
        'status and error, every call ended', () async {
      final h = Harness()..serveRooms();
      h.server.wireVersion = dwWireVersion + 1;
      final statuses = DwRecording(h.client.connectionStatuses);
      final pending = h.client.fetch(const ListRooms());
      final watch = h.client.watch(const ListRooms());
      const expected = DwWireVersionException(
        clientVersion: dwWireVersion,
        serverVersion: dwWireVersion + 1,
      );
      final ended = expectLater(pending, throwsA(expected));
      await h.client.start();
      await ended;
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(h.server.connections, hasLength(1), reason: 'no reconnect');
      expect(h.client.connectionStatus, DwConnectionStatus.incompatible);
      expect(statuses.last, DwConnectionStatus.incompatible);
      expect(h.reported, [expected]);
      expect(watch.state, const DwRequestFailed<List<RoomView>>('client'));
      await expectLater(h.client.fetch(const ListRooms()), throwsA(expected));
      final later = h.client.watch(const ListRooms(minRank: 1));
      expect(later.state, const DwRequestFailed<List<RoomView>>('client'));
      expect(h.reported, [expected], reason: 'reported once');
      h.reported.clear();
    });
  });

  group('close codes', () {
    /// The time from each server-side close with [code] to the next
    /// connection, over [closes] consecutive closes.
    Future<List<Duration>> reconnectGaps(int? code, {int closes = 4}) async {
      final h = Harness(
        options: const DwClientOptions(
          reconnectDelay: Duration(milliseconds: 40),
          maxReconnectDelay: Duration(seconds: 5),
          releaseDelay: Duration.zero,
        ),
      )..serveRooms();
      await h.start();
      final gaps = <Duration>[];
      for (var i = 0; i < closes; i++) {
        final stopwatch = Stopwatch()..start();
        await h.server.openConnections.single.close(code: code);
        await until(
          () =>
              h.server.connections.length == i + 2 &&
              h.client.connectionStatus == DwConnectionStatus.connected,
          timeout: const Duration(seconds: 5),
        );
        gaps.add(stopwatch.elapsed);
      }
      return gaps;
    }

    test('an ordinary close after a good connection reconnects at the first '
        'delay every time', () async {
      final gaps = await reconnectGaps(DwCloseCode.serverStopping);
      expect(gaps.last, lessThan(const Duration(milliseconds: 140)));
    });

    for (final code in [DwCloseCode.slowConsumer, DwCloseCode.tooManyCalls]) {
      test(
        'a server shedding the client ($code) meets a growing backoff',
        () async {
          final gaps = await reconnectGaps(code);
          // 40 ms doubled three times, drawn between half and whole: >= 160.
          expect(
            gaps.last,
            greaterThanOrEqualTo(const Duration(milliseconds: 150)),
          );
        },
      );
    }

    test(
      'a close for what the client sent is reported and backed off',
      () async {
        final h = Harness()..serveRooms();
        await h.start();
        await h.server.openConnections.single.close(
          code: DwCloseCode.protocolError,
          reason: 'dw.protocol',
        );
        await until(
          () =>
              h.server.connections.length == 2 &&
              h.client.connectionStatus == DwConnectionStatus.connected,
        );
        expect(h.reported.single, isA<DwConnectionRejectedException>());
        h.reported.clear();
      },
    );
  });

  group('echo (D-018)', () {
    test('an update repeating the command result inserts once, also when it '
        'arrives again while an answer is in flight', () async {
      final h = Harness()..serveRooms();
      const created = RoomView(id: 3, name: 'new', rank: 5);
      h.server.onCommand<RenameRoom>((command, call) {
        h.rooms = [...h.rooms, created];
        // A real server delivers the batch before the result, to the author
        // too.
        h.server.publish(rooms, [created]);
        return const DwOk(created);
      });
      await h.start();
      final watch = h.client.watch(const ListRooms());
      final states = DwRecording(watch.states);
      await settle();

      final result = await h.client.command(
        const RenameRoom(roomId: 3, name: 'new'),
      );
      expect(result.valueOrNull, created);
      await settle();
      expect(dataOf(watch.state), [created, a, b]);

      final answer = Completer<void>();
      h.server.onRequest<ListRooms>((request, call) async {
        await answer.future;
        return DwOk(h.rooms.toList());
      });
      final refetched = watch.refetch();
      await settle();
      h.server.publish(rooms, [created]);
      await settle();
      answer.complete();
      await refetched;
      await settle();

      final shown = dataOf(watch.state);
      expect(shown.where((room) => room.id == created.id), hasLength(1));
      for (final state in states.values) {
        if (state case DwRequestData(:final value)) {
          expect(
            value.where((room) => room.id == created.id).length,
            lessThanOrEqualTo(1),
          );
        }
      }
    });
  });
}
