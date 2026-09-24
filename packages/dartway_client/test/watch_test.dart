import 'dart:convert';

import 'package:dartway_client/dartway_client.dart';
import 'package:dartway_client/testing.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  group('a watch', () {
    test(
      'loads, then shows data; a late listener gets the current state',
      () async {
        final h = Harness()..serveRooms();
        await h.start();
        final watch = h.client.watch(const ListRoomsOffline());
        final states = DwStreamRecording(watch.states);
        await settle();
        expect(states.values, [
          const DwRequestLoading<List<RoomView>>(),
          const DwRequestData([a, b]),
        ]);
        final late = DwStreamRecording(watch.states);
        await settle();
        expect(late.values, [
          const DwRequestData([a, b]),
        ]);
      },
    );

    test('refused, failed and unauthenticated answers are states', () async {
      final h = Harness();
      h.server
        ..onRequest<GetRoom>(
          (r, call) =>
              DwCallRefused<RoomView>(DwCallRefusal(DwCoreRefusal.forbidden)),
        )
        ..onRequest<ListRoomsOffline>(
          (r, call) => const DwCallFailed<List<RoomView>>('incident-7'),
        )
        ..onRequest<FindRoom>(
          (r, call) => const DwNotAuthenticated<RoomView?>(),
        );
      await h.start();
      final refused = h.client.watch(const GetRoom(1));
      final failed = h.client.watch(const ListRoomsOffline());
      final unauthenticated = h.client.watch(const FindRoom('x'));
      await settle();
      expect(
        refused.state,
        DwRequestRefused<RoomView>(DwCallRefusal(DwCoreRefusal.forbidden)),
      );
      expect(failed.state, const DwRequestFailed<List<RoomView>>('incident-7'));
      expect(
        unauthenticated.state,
        const DwRequestUnauthenticated<RoomView?>(),
      );
      expect(h.client.accountId, isNull, reason: 'the session ended');
    });

    test('an invalid request shows its refusal and never fetches or '
        'subscribes', () async {
      final h = Harness()..serveRooms();
      await h.start();
      final watch = h.client.watch(const ListRooms(minRank: -1));
      await settle();
      expect(
        watch.state,
        DwRequestRefused<List<RoomView>>(
          DwCallRefusal(
            DwCoreRefusal.invalid,
            field: 'minRank',
            params: {'min': 0},
          ),
        ),
      );
      expect(h.server.calls, isEmpty);
      expect(h.server.connections, isEmpty);
      await watch.refetch();
      expect(h.server.calls, isEmpty);
    });

    test('an answer that does not decode is a failure, reported', () async {
      final h = Harness();
      h.server.interceptPost = (post) => DwHttpReply(
        status: 200,
        body: jsonEncode(const DwApiResponse.ok([1, 2]).toJson()),
      );
      await h.start();
      final watch = h.client.watch(const ListRoomsOffline());
      await settle();
      expect(
        watch.state,
        const DwRequestFailed<List<RoomView>>(dwClientIncidentId),
      );
      expect(h.takeReported<DwProtocolException>(), hasLength(1));
    });

    test('with no answer for callTimeout and no data it is unreachable, and '
        'recovers by itself', () async {
      final h = Harness(
        options: const DwClientOptions(
          callTimeout: Duration(milliseconds: 30),
          retryDelay: Duration(milliseconds: 5),
          maxRetryDelay: Duration(milliseconds: 10),
          releaseDelay: Duration.zero,
        ),
      )..serveRooms();
      await h.start();
      h.server.reachable = false;
      final watch = h.client.watch(const ListRoomsOffline());
      await until(() => watch.state is DwRequestUnreachable);
      h.server.reachable = true;
      await until(() => watch.state is DwRequestData);
      expect(dataOf(watch.state), [a, b]);
    });

    test('a paginated request is refused by watch', () {
      final h = Harness();
      expect(() => h.client.watch(const FeedRooms()), throwsArgumentError);
    });
  });

  group('sharing and reference counting', () {
    test(
      'equal requests share one entry: one fetch, one subscription',
      () async {
        final h = Harness()..serveRooms();
        await h.start();
        final first = h.client.watch(const ListRooms());
        final second = h.client.watch(const ListRooms());
        await settle();
        expect(h.server.requestsOf<ListRooms>(), hasLength(1));
        expect(h.server.subscribeCount(roomsChannel), 1);
        expect(first.state, second.state);
        first.close();
        await settle();
        expect(h.server.unsubscribeCount(roomsChannel), 0);
        second.close();
        await settle();
        expect(h.server.unsubscribeCount(roomsChannel), 1);
      },
    );

    test('an entry outlives its last watcher for the release delay', () async {
      final h = Harness(
        options: const DwClientOptions(
          releaseDelay: Duration(milliseconds: 600),
          liveIdleDelay: Duration.zero,
          retryDelay: Duration(milliseconds: 1),
        ),
      )..serveRooms();
      await h.start();
      h.client.watch(const ListRooms()).close();
      await settle();
      final again = h.client.watch(const ListRooms());
      expect(
        again.state,
        const DwRequestData([a, b], live: true),
        reason: 'current and live at once, without a fetch',
      );
      again.close();
      await Future<void>.delayed(const Duration(milliseconds: 700));
      await settle();
      expect(h.server.requestsOf<ListRooms>(), hasLength(1));
      expect(h.server.unsubscribeCount(roomsChannel), 1);
    });

    test(
      'a closed watch closes its streams; closing twice is harmless',
      () async {
        final h = Harness()..serveRooms();
        await h.start();
        final watch = h.client.watch(const ListRoomsOffline());
        final states = DwStreamRecording(watch.states);
        await settle();
        watch
          ..close()
          ..close();
        await settle();
        expect(states.isDone, isTrue);
        expect(watch.isClosed, isTrue);
        expect(watch.state, const DwRequestData([a, b]));
        expect(() => watch.refetch(), throwsStateError);
      },
    );

    test(
      'a watch typed loosely shares the entry and sees the same values',
      () async {
        final h = Harness()..serveRooms();
        await h.start();
        final typed = h.client.watch(const ListRoomsOffline());
        final DwDataRequest<Object?> loose = const ListRoomsOffline();
        final erased = h.client.watch(loose);
        await settle();
        expect(dataOf(erased.state), dataOf(typed.state));
        expect(h.server.requestsOf<ListRoomsOffline>(), hasLength(1));
      },
    );
  });

  group('refetch', () {
    test('is coalesced: one in flight, one after it', () async {
      final h = Harness()..serveRooms();
      final gate = Gate()..open();
      h.server.onRequest<ListRoomsOffline>((request, call) async {
        await gate.passed;
        return DwCallOk(h.rooms.toList());
      });
      await h.start();
      final watch = h.client.watch(const ListRoomsOffline());
      await settle();
      gate.close();
      final refetches = [for (var i = 0; i < 5; i++) watch.refetch()];
      await settle();
      gate.open();
      await Future.wait(refetches);
      await settle();
      expect(h.server.requestsOf<ListRoomsOffline>(), hasLength(3));
    });

    test('shows the old data as refreshing; an equal answer keeps the value '
        'instance', () async {
      final h = Harness()..serveRooms();
      await h.start();
      final watch = h.client.watch(const ListRoomsOffline());
      await settle();
      final before = dataOf(watch.state);
      final states = DwStreamRecording(watch.states);
      await watch.refetch();
      expect(states.values, [
        const DwRequestData([a, b]),
        const DwRequestData([a, b], refreshing: true),
        const DwRequestData([a, b]),
      ]);
      expect(identical(dataOf(watch.state), before), isTrue);
    });
  });

  group('incompatibility', () {
    test('an update-required answer is terminal: surfaced once, calls fail '
        'fast, watches show it', () async {
      final h = Harness(signedIn: false, appVersion: '1.0.0+3')..serveRooms();
      h.server.contractVersion = '1.0.0';
      await h.start();
      final incompatibility = DwStreamRecording(h.client.incompatibilityStream);
      final watch = h.client.watch(const ListRoomsOffline());
      await settle();

      final refusal = DwCallRefusal(DwCoreRefusal.updateRequired);
      expect(h.server.calls.single.status, 426);
      expect(incompatibility.values, [null, refusal]);
      expect(h.client.connectionStatus, DwConnectionStatus.incompatible);
      expect(watch.state, DwRequestRefused<List<RoomView>>(refusal));

      expect(
        (await h.client.command(const RenameRoom(roomId: 1, name: 'x')))
            as DwCallRefused,
        isA<DwCallRefused>().having((r) => r.refusal, 'refusal', refusal),
      );
      final later = h.client.watch(const GetRoom(1));
      await settle();
      expect(later.state, DwRequestRefused<RoomView>(refusal));
      expect(h.server.calls, hasLength(1), reason: 'nothing more reached it');
    });

    test('a protocol the server does not speak is incompatible too', () async {
      final h = Harness(signedIn: false)..serveRooms();
      h.server.protocolVersion = dwProtocolVersion + 1;
      await h.start();
      final result = await h.client.fetch(const ListRoomsOffline());
      expect(
        (result as DwCallRefused).refusal,
        DwCallRefusal(DwCoreRefusal.protocolUnsupported),
      );
      expect(
        h.client.incompatibility,
        DwCallRefusal(DwCoreRefusal.protocolUnsupported),
      );
    });
  });
}
