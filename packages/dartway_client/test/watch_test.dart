import 'dart:async';

import 'package:dartway_client/dartway_client.dart';
import 'package:dartway_client/testing.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  group('a watch', () {
    test('loads, then shows data that is live once subscribed', () async {
      final h = Harness()..serveRooms();
      await h.start();
      final watch = h.client.watch(const ListRooms());
      final states = DwRecording(watch.states);
      await settle();

      expect(states.values.first, const DwRequestLoading<List<RoomView>>());
      expect(watch.state, const DwRequestData([a, b], live: true));
      expect(watch.isLive, isTrue);
      // Subscribed before fetching: nothing published in between is missed.
      final kinds = h.server.received
          .map((m) => m.runtimeType)
          .where((t) => t == DwSubscribeMessage || t == DwRequestMessage)
          .toList();
      expect(kinds, [DwSubscribeMessage, DwRequestMessage]);
    });

    test('replays the current state to a late listener', () async {
      final h = Harness()..serveRooms();
      await h.start();
      final watch = h.client.watch(const ListRooms());
      await settle();
      final late = DwRecording(watch.states);
      await settle();
      expect(late.values, [
        const DwRequestData([a, b], live: true),
      ]);
    });

    test('a request without channels is data and never live', () async {
      final h = Harness();
      h.server.onRequest<ListRoomsByRank>((r, call) => const DwOk([a]));
      await h.start();
      final watch = h.client.watch(const _NoChannels());
      await settle();
      expect(watch.state, const DwRequestData([a]));
      expect(h.server.receivedOf<DwSubscribeMessage>(), isEmpty);
    });

    test('refused, failed and unauthenticated answers are states', () async {
      final h = Harness();
      h.server
        ..onRequest<GetRoom>(
          (r, call) => DwRefused<RoomView>(DwRefusal(DwCoreRefusal.forbidden)),
        )
        ..onRequest<ListRooms>(
          (r, call) => const DwFailed<List<RoomView>>('incident-7'),
        )
        ..onRequest<FindRoom>(
          (r, call) => const DwNotAuthenticated<RoomView?>(),
        );
      await h.start();
      final refused = h.client.watch(const GetRoom(1));
      final failed = h.client.watch(const ListRooms());
      final unauthenticated = h.client.watch(const FindRoom('x'));
      await settle();
      expect(
        refused.state,
        DwRequestRefused<RoomView>(DwRefusal(DwCoreRefusal.forbidden)),
      );
      expect(failed.state, const DwRequestFailed<List<RoomView>>('incident-7'));
      expect(
        unauthenticated.state,
        const DwRequestUnauthenticated<RoomView?>(),
      );
    });

    test('a paginated request is refused by watch', () {
      final h = Harness();
      expect(() => h.client.watch(const FeedRooms()), throwsArgumentError);
    });
  });

  group('sharing and reference counting', () {
    test(
      'two watchers of equal requests share one fetch and one subscription',
      () async {
        final h = Harness()..serveRooms();
        await h.start();
        final first = h.client.watch(const ListRooms());
        final second = h.client.watch(const ListRooms());
        await settle();

        expect(h.server.requestsOf<ListRooms>(), hasLength(1));
        expect(h.server.subscribeCount(rooms), 1);
        expect(first.state, second.state);

        first.close();
        await settle();
        expect(
          h.server.unsubscribeCount(rooms),
          0,
          reason: 'one watcher remains',
        );

        second.close();
        await settle();
        expect(h.server.unsubscribeCount(rooms), 1);
        expect(h.server.subscriberCount(rooms), 0);
      },
    );

    test(
      'one subscription is shared across different requests on a channel',
      () async {
        final h = Harness()..serveRooms();
        await h.start();
        final list = h.client.watch(const ListRooms());
        final byRank = h.client.watch(const ListRoomsByRank());
        final find = h.client.watch(const FindRoom('a'));
        await settle();
        expect(h.server.subscribeCount(rooms), 1);
        expect(h.server.requestsOf<DwRequest<Object?>>(), hasLength(3));

        list.close();
        byRank.close();
        await settle();
        expect(h.server.unsubscribeCount(rooms), 0);

        find.close();
        await settle();
        expect(h.server.unsubscribeCount(rooms), 1);
      },
    );

    test(
      'updates reach only the entries whose request declares the channel',
      () async {
        final h = Harness()..serveRooms();
        h.server.onRequest<ListNotes>(
          (r, call) => const DwOk([NoteView(id: 1, text: 'n')]),
        );
        await h.start();
        final roomsWatch = h.client.watch(const ListRooms());
        final room = h.client.watch(const GetRoom(1));
        await settle();

        // Published on `room:1` only: the list on `rooms` must not hear it.
        const renamed = RoomView(id: 2, name: 'b2', rank: 20);
        h.server.publish(const DwChannel(AppChannel.room, 1), [renamed]);
        await settle();
        expect(dataOf(roomsWatch.state), [a, b]);
        expect(dataOf(room.state), a);
      },
    );

    test('an entry outlives its last watcher for the release delay', () async {
      final h = Harness(
        options: const DwClientOptions(
          releaseDelay: Duration(milliseconds: 400),
        ),
      )..serveRooms();
      await h.start();
      h.client.watch(const ListRooms()).close();
      await settle();
      final again = h.client.watch(const ListRooms());
      await settle();
      expect(
        h.server.requestsOf<ListRooms>(),
        hasLength(1),
        reason: 'revived, not refetched',
      );
      expect(h.server.unsubscribeCount(rooms), 0);
      expect(again.state, const DwRequestData([a, b], live: true));

      again.close();
      await Future<void>.delayed(const Duration(milliseconds: 500));
      await settle();
      expect(h.server.unsubscribeCount(rooms), 1);
    });

    test('a watch closes its streams; closing twice is harmless', () async {
      final h = Harness()..serveRooms();
      await h.start();
      final watch = h.client.watch(const ListRooms());
      final states = DwRecording(watch.states);
      await settle();
      watch
        ..close()
        ..close();
      await settle();
      expect(states.isDone, isTrue);
      expect(watch.isClosed, isTrue);
      expect(() => watch.refetch(), throwsStateError);
    });

    test(
      'an erased watcher of the same request gets the same state re-typed',
      () async {
        final h = Harness()..serveRooms();
        await h.start();
        final erased = h.client.watch<Object?>(
          const ListRooms() as DwRequest<Object?>,
        );
        final typed = h.client.watch(const ListRooms());
        await settle();
        expect(typed.state, isA<DwRequestData<List<RoomView>>>());
        expect(dataOf(typed.state), [a, b]);
        expect(dataOf(erased.state), [a, b]);
      },
    );
  });

  group('refetch', () {
    test('is coalesced: one in flight, one after it', () async {
      final h = Harness();
      final answers = <Completer<DwResult<Object?>>>[];
      h.server.onRequest<ListRooms>((r, call) {
        final answer = Completer<DwResult<Object?>>();
        answers.add(answer);
        return answer.future;
      });
      await h.start();
      final watch = h.client.watch(const ListRooms());
      await settle();
      expect(answers, hasLength(1));

      final refetches = [watch.refetch(), watch.refetch(), watch.refetch()];
      await settle();
      expect(
        answers,
        hasLength(1),
        reason: 'nothing more while one is in flight',
      );

      answers[0].complete(const DwOk([a]));
      await settle();
      expect(answers, hasLength(2), reason: 'exactly one pending run follows');

      answers[1].complete(const DwOk([a, b]));
      await Future.wait(refetches);
      await settle();
      expect(answers, hasLength(2));
      expect(dataOf(watch.state), [a, b]);
    });

    test('shows the old data as refreshing meanwhile', () async {
      final h = Harness();
      final answers = <Completer<DwResult<Object?>>>[];
      h.server.onRequest<ListRooms>((r, call) {
        final answer = Completer<DwResult<Object?>>();
        answers.add(answer);
        return answer.future;
      });
      await h.start();
      final watch = h.client.watch(const ListRooms());
      await settle();
      answers[0].complete(const DwOk([a]));
      await settle();

      unawaited(watch.refetch());
      await settle();
      expect(
        watch.state,
        const DwRequestData([a], refreshing: true, live: true),
      );
      answers[1].complete(const DwOk([a]));
      await settle();
      expect(watch.state, const DwRequestData([a], live: true));
    });

    test('an equal answer keeps the value instance', () async {
      final h = Harness()..serveRooms();
      await h.start();
      final watch = h.client.watch(const ListRooms());
      await settle();
      final before = dataOf(watch.state);
      await watch.refetch();
      await settle();
      expect(identical(dataOf(watch.state), before), isTrue);
    });

    test(
      'an update arriving while the answer is in flight survives the answer',
      () async {
        final h = Harness();
        final answers = <Completer<DwResult<Object?>>>[];
        h.server.onRequest<ListRooms>((r, call) {
          final answer = Completer<DwResult<Object?>>();
          answers.add(answer);
          return answer.future;
        });
        await h.start();
        h.client.watch(const ListRooms());
        await settle();
        // Published after the server computed the answer, delivered before it.
        h.server.publish(rooms, [c]);
        await settle();
        answers[0].complete(const DwOk([a, b]));
        await settle();
        expect(dataOf(h.client.watch(const ListRooms()).state), [c, a, b]);
      },
    );
  });

  group('channel closed', () {
    test(
      'keeps the data, stops being live, and refetches the access state',
      () async {
        final h = Harness()..serveRooms();
        var allowed = true;
        h.server.onRequest<GetRoom>(
          (r, call) => allowed
              ? const DwOk(a)
              : DwRefused<RoomView>(DwRefusal(DwCoreRefusal.forbidden)),
        );
        await h.start();
        final watch = h.client.watch(const GetRoom(1));
        final states = DwRecording(watch.states);
        await settle();
        expect(watch.isLive, isTrue);

        allowed = false;
        h.server.closeChannel(const DwChannel(AppChannel.room, 1));
        await settle();

        expect(states.values, contains(const DwRequestData(a)));
        expect(
          watch.state,
          DwRequestRefused<RoomView>(DwRefusal(DwCoreRefusal.forbidden)),
        );
        expect(h.server.requestsOf<GetRoom>(), hasLength(2));
        // Terminal for this account: no resubscription on its own.
        expect(h.server.subscribeCount(const DwChannel(AppChannel.room, 1)), 1);
      },
    );

    test('updates on a closed channel are ignored', () async {
      final h = Harness()..serveRooms();
      await h.start();
      final watch = h.client.watch(const ListRooms());
      await settle();
      h.server.closeChannel(rooms);
      await settle();
      // A stray update after the close (sent directly, bypassing the fake's
      // subscription table) changes nothing.
      h.server.openConnections.single.send(
        const DwUpdateMessage(channel: 'rooms', items: [c]),
      );
      await settle();
      expect(dataOf(watch.state), [a, b]);
      expect(watch.isLive, isFalse);
    });
  });

  group('subscription refused', () {
    test(
      'an unknown channel is reported and the request works, not live',
      () async {
        final h = Harness()..serveRooms();
        h.server.subscriptionRule = (channel, connection) =>
            DwRefusal(DwCoreRefusal.unknownChannel);
        await h.start();
        final watch = h.client.watch(const ListRooms());
        await settle();
        expect(watch.state, const DwRequestData([a, b]));
        expect(h.reported.single, isA<DwChannelRefusedException>());
        h.reported.clear();
      },
    );

    test('an access refusal is not reported', () async {
      final h = Harness()..serveRooms();
      h.server.subscriptionRule = (channel, connection) =>
          DwRefusal(DwCoreRefusal.forbidden);
      await h.start();
      final watch = h.client.watch(const ListRooms());
      await settle();
      expect(watch.isLive, isFalse);
    });
  });

  group('onUpdate', () {
    test('refetch re-runs derived data', () async {
      final h = Harness();
      var calls = 0;
      h.server.onRequest<ListNotes>((r, call) {
        calls++;
        return DwOk([NoteView(id: 1, text: 'v$calls')]);
      });
      await h.start();
      final watch = h.client.watch(const ListNotes());
      await settle();
      h.server.publish(rooms, [a, b]);
      await settle();
      expect(calls, 2, reason: 'two updates in one message: one refetch');
      expect(dataOf(watch.state), [const NoteView(id: 1, text: 'v2')]);
    });

    test(
      'a throwing onUpdate is reported and the rest of the message applies',
      () async {
        final h = Harness();
        h.server.onRequest<ListRooms>((r, call) => const DwOk([a]));
        await h.start();
        final watch = h.client.watch(const _Throwing());
        await settle();
        h.server.publish(rooms, [const NoteView(id: 9, text: 'boom'), c]);
        await settle();
        expect(dataOf(watch.state), [c, a]);
        expect(h.reported.single, isA<StateError>());
        h.reported.clear();
      },
    );

    test(
      'upsert of an object that is not the item type is reported, not applied',
      () async {
        final h = Harness();
        h.server.onRequest<ListRoomsByRank>((r, call) => const DwOk([a]));
        await h.start();
        final watch = h.client.watch(const _UpsertAll());
        await settle();
        h.server.publish(rooms, [const NoteView(id: 9, text: 'x')]);
        await settle();
        expect(dataOf(watch.state), [a]);
        expect(h.reported.single, isA<StateError>());
        h.reported.clear();
      },
    );
  });

  test('an unreadable update is reported and its channel refetched', () async {
    final h = Harness()..serveRooms();
    await h.start();
    final watch = h.client.watch(const ListRooms());
    await settle();
    h.rooms = [a, b, c];
    // A DTO this client does not register.
    h.server.openConnections.single.sendFrame(
      '{"k":"upd","ch":"rooms","items":[{"@t":"Unregistered","id":1}]}',
    );
    await settle();
    expect(h.reported.single, isA<DwProtocolException>());
    h.reported.clear();
    expect(dataOf(watch.state), [a, b, c]);
  });
}

/// A request that extends ListRoomsByRank's handler but declares no channels.
final class _NoChannels extends DwListRequest<RoomView> {
  const _NoChannels();

  @override
  String get dwTypeName => 'ListRoomsByRank';

  @override
  Map<String, Object?> toJson() => const {};

  @override
  bool operator ==(Object other) => other is _NoChannels;

  @override
  int get hashCode => 1;
}

final class _Throwing extends DwListRequest<RoomView> {
  const _Throwing();

  @override
  List<DwChannel> get channels => const [rooms];

  @override
  DwUpdate onUpdate(DwDto update) =>
      update is NoteView ? throw StateError('boom') : DwUpdate.auto;

  @override
  String get dwTypeName => 'ListRooms';

  @override
  Map<String, Object?> toJson() => const {};

  @override
  bool operator ==(Object other) => other is _Throwing;

  @override
  int get hashCode => 2;
}

final class _UpsertAll extends DwListRequest<RoomView> {
  const _UpsertAll();

  @override
  List<DwChannel> get channels => const [rooms];

  @override
  DwUpdate onUpdate(DwDto update) => DwUpdate.upsert;

  @override
  String get dwTypeName => 'ListRoomsByRank';

  @override
  Map<String, Object?> toJson() => const {};

  @override
  bool operator ==(Object other) => other is _UpsertAll;

  @override
  int get hashCode => 3;
}
