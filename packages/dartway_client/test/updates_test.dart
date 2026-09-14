import 'package:dartway_client/dartway_client.dart';
import 'package:dartway_client/testing.dart';
import 'package:test/test.dart';

import 'support.dart';

DwDeletedObject deleted(int id) =>
    DwDeletedObject.of<RoomView>(id, roomsProtocol);

/// A started harness with [request] watched and loaded.
Future<(Harness, DwRequestWatch<R>)> watched<R>(
  DwDataRequest<R> request, {
  List<RoomView>? rooms,
}) async {
  final h = Harness()..serveRooms();
  if (rooms != null) h.rooms = rooms;
  await h.start();
  final watch = h.client.watch(request);
  await settle();
  return (h, watch);
}

void main() {
  group('list', () {
    test('an upsert of a new object goes to the head without a sort', () async {
      final (h, watch) = await watched(const ListRooms());
      h.server.publish(roomsChannel, [c]);
      await settle();
      expect(dataOf(watch.state), [c, a, b]);
    });

    test('an upsert of a new object is placed by the sort', () async {
      final (h, watch) = await watched(const ListRoomsByRank());
      const middle = RoomView(id: 4, name: 'm', rank: 15);
      h.server.publish(roomsChannel, [middle, c]);
      await settle();
      expect(dataOf(watch.state), [a, middle, b, c]);
    });

    test('a present object is replaced in place, never moved', () async {
      final (h, watch) = await watched(const ListRoomsByRank());
      const reranked = RoomView(id: 1, name: 'a', rank: 99);
      h.server.publish(roomsChannel, [reranked]);
      await settle();
      expect(dataOf(watch.state), [reranked, b]);
    });

    test('an object that stops matching is removed; one that does not match '
        'is not inserted', () async {
      final (h, watch) = await watched(
        const ListRooms(minRank: 15),
        rooms: [a, b, c],
      );
      expect(dataOf(watch.state), [b, c]);
      h.server.publish(roomsChannel, [
        const RoomView(id: 2, name: 'b', rank: 1),
        const RoomView(id: 5, name: 'low', rank: 2),
      ]);
      await settle();
      expect(dataOf(watch.state), [c]);
    });

    test('a deletion removes', () async {
      final (h, watch) = await watched(const ListRooms());
      h.server.publish(roomsChannel, [deleted(1)]);
      await settle();
      expect(dataOf(watch.state), [b]);
    });

    test('updateOnly replaces but never inserts', () async {
      final (h, watch) = await watched(const ListPinnedRooms());
      const renamed = RoomView(id: 2, name: 'b2', rank: 20);
      h.server.publish(roomsChannel, [c, renamed]);
      await settle();
      expect(dataOf(watch.state), [a, renamed]);
    });

    test('refetchOnUpdate re-runs, coalesced over a burst', () async {
      final (h, watch) = await watched(const ListRoomStats());
      h.rooms = [c];
      for (var i = 0; i < 5; i++) {
        h.server.publish(roomsChannel, [RoomView(id: 10 + i, name: 'x')]);
      }
      await settle();
      expect(dataOf(watch.state), [c]);
      expect(
        h.server.requestsOf<ListRoomStats>().length,
        lessThanOrEqualTo(3),
        reason: 'one in flight and one after it, however many updates',
      );
    });

    test('objects of another type are not offered', () async {
      final (h, watch) = await watched(const ListRooms());
      final states = DwStreamRecording(watch.states);
      h.server.publish(roomsChannel, [
        const NoteView(id: 1, text: 'n'),
        DwDeletedObject.of<NoteView>(1, roomsProtocol),
      ]);
      await settle();
      expect(states.values, hasLength(1), reason: 'only the replayed state');
      expect(dataOf(watch.state), [a, b]);
    });

    test('an equal object changes nothing and emits nothing', () async {
      final (h, watch) = await watched(const ListRooms());
      final before = dataOf(watch.state);
      final states = DwStreamRecording(watch.states);
      h.server.publish(roomsChannel, [a]);
      await settle();
      expect(states.values, hasLength(1));
      expect(identical(dataOf(watch.state), before), isTrue);
    });

    test('the list keeps its reified item type through changes', () async {
      final (h, watch) = await watched(const ListRooms());
      h.server.publish(roomsChannel, [c, deleted(1)]);
      await settle();
      expect(dataOf(watch.state), isA<List<RoomView>>());
    });

    test(
      'an onUpdate that throws is reported and the rest still applies',
      () async {
        final protocol = DwWireProtocol([
          const DwProtocolEntry<_ThrowingList>(
            'ThrowingList',
            _ThrowingList.fromJson,
          ),
        ], include: roomsProtocol);
        final server = DwFakeServer(protocol: protocol)
          ..registerToken(alice.token, alice.id)
          ..onRequest<_ThrowingList>((r, call) => const DwCallOk([a]))
          ..onCommand<RenameRoom>((command, call) {
            call.publish(roomsChannel, [
              const RoomView(id: 666, name: 'bad'),
              c,
            ]);
            return const DwCallOk(c);
          });
        final reported = <Object>[];
        final client = server.newClient(
          tokenStore: DwMemoryTokenStore(alice),
          onError: (error, stackTrace) => reported.add(error),
        );
        addTearDown(client.stop);
        await client.start();
        final watch = client.watch(const _ThrowingList());
        await settle();

        await client.command(const RenameRoom(roomId: 3, name: 'c'));
        expect(dataOf(watch.state), [c, a]);
        expect(reported, [isA<StateError>()]);
        expect(server.errors, isEmpty);
      },
    );
  });

  group('single', () {
    test('the same id is replaced, another id ignored', () async {
      final (h, watch) = await watched(const GetRoom(1));
      h.server.publish(DwLiveChannel(AppChannel.room, 1), [
        const RoomView(id: 1, name: 'a2'),
        const RoomView(id: 2, name: 'other'),
      ]);
      await settle();
      expect(dataOf(watch.state), const RoomView(id: 1, name: 'a2'));
    });

    test('a deletion asks again, and the answer is not found', () async {
      final (h, watch) = await watched(const GetRoom(1));
      h.rooms = [b];
      h.server.publish(DwLiveChannel(AppChannel.room, 1), [deleted(1)]);
      await settle();
      expect(
        watch.state,
        DwRequestRefused<RoomView>(DwCallRefusal(DwCoreRefusal.notFound)),
      );
      expect(h.server.requestsOf<GetRoom>(), hasLength(2));
    });
  });

  group('maybe', () {
    test('an empty state is filled by the object it asks for', () async {
      final (h, watch) = await watched(const FindRoom('c'));
      expect(dataOf(watch.state), isNull);
      h.server.publish(roomsChannel, [a, c]);
      await settle();
      expect(dataOf(watch.state), c);
    });

    test(
      'the held object is replaced; one that stops matching empties it',
      () async {
        final (h, watch) = await watched(const FindRoom('a'));
        h.server.publish(roomsChannel, [
          const RoomView(id: 1, name: 'a', rank: 5),
        ]);
        await settle();
        expect(dataOf(watch.state), const RoomView(id: 1, name: 'a', rank: 5));
        h.server.publish(roomsChannel, [
          const RoomView(id: 1, name: 'renamed'),
        ]);
        await settle();
        expect(dataOf(watch.state), isNull);
      },
    );

    test(
      'a deletion of the held object empties it; of another, nothing',
      () async {
        final (h, watch) = await watched(const FindRoom('a'));
        h.server.publish(roomsChannel, [deleted(2)]);
        await settle();
        expect(dataOf(watch.state), a);
        h.server.publish(roomsChannel, [deleted(1)]);
        await settle();
        expect(dataOf(watch.state), isNull);
      },
    );
  });

  group('routing', () {
    test(
      'every accepting entry gets every object, whatever carried it',
      () async {
        final h = Harness()..serveRooms();
        await h.start();
        final live = h.client.watch(const ListRooms());
        final offline = h.client.watch(const ListRoomsOffline());
        final byRank = h.client.watch(const ListRoomsByRank());
        await settle();

        await h.client.command(const RenameRoom(roomId: 1, name: 'a2'));
        const renamed = RoomView(id: 1, name: 'a2', rank: 10);
        expect(dataOf(live.state), [renamed, b]);
        expect(dataOf(offline.state), [renamed, b]);
        expect(dataOf(byRank.state), [renamed, b]);

        h.server.publish(roomsChannel, [c]);
        await settle();
        expect(
          dataOf(offline.state),
          [c, renamed, b],
          reason: 'a socket update reaches an entry without channels too',
        );
      },
    );

    test('an update that arrives while a fetch is in flight survives the '
        'answer', () async {
      final h = Harness()..serveRooms();
      final gate = Gate()..open();
      h.server.onRequest<ListRooms>((request, call) async {
        final answer = h.rooms.toList();
        await gate.passed;
        return DwCallOk(answer);
      });
      await h.start();
      final watch = h.client.watch(const ListRooms());
      await settle();

      gate.close();
      final refetched = watch.refetch();
      await settle();
      // The server read [a, b]; then c was created and published.
      h.rooms = [c, a, b];
      h.server.publish(roomsChannel, [c]);
      await settle();
      gate.open();
      await refetched;
      await settle();
      expect(dataOf(watch.state), [c, a, b]);
    });
  });
}

/// A list whose onUpdate throws for one object.
final class _ThrowingList extends DwListRequest<RoomView> {
  const _ThrowingList();

  static _ThrowingList fromJson(Map<String, Object?> json) =>
      const _ThrowingList();

  @override
  String get dwTypeName => 'ThrowingList';

  @override
  Map<String, Object?> toJson() => const {};

  @override
  DwUpdateAction onUpdate(Object item) {
    if (item is RoomView && item.id == 666) throw StateError('bad update');
    return super.onUpdate(item);
  }

  @override
  bool operator ==(Object other) => other is _ThrowingList;

  @override
  int get hashCode => 0;
}
