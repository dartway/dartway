import 'package:dartway_client/dartway_client.dart';
import 'package:test/test.dart';

import 'support.dart';

/// The `auto` defaults of SPEC §4, per request kind, observed through watches.
void main() {
  late Harness h;

  Future<DwWatch<R>> watched<R>(DwRequest<R> request) async {
    final watch = h.client.watch(request);
    await settle();
    return watch;
  }

  Future<void> publish(List<DwDto> items, [DwChannel channel = rooms]) async {
    h.server.publish(channel, items);
    await settle();
  }

  DwDeleted deleted(Object id) => DwDeleted.of<RoomView>(id, roomsProtocol);

  setUp(() async {
    h = Harness()..serveRooms();
    await h.start();
  });

  group('list', () {
    test(
      'an object already in the list is replaced in place, never moved',
      () async {
        h.rooms = [a, b, c];
        final watch = await watched(const ListRooms());
        const lastRenamed = RoomView(id: 3, name: 'c2', rank: 30);
        await publish([lastRenamed]);
        expect(dataOf(watch.state), [a, b, lastRenamed]);
      },
    );

    test('a new object is inserted at the head without a sort', () async {
      final watch = await watched(const ListRooms());
      await publish([c]);
      expect(dataOf(watch.state), [c, a, b]);
    });

    test(
      'a new object is inserted by sort when the request declares one',
      () async {
        h.rooms = [a, c];
        final watch = await watched(const ListRoomsByRank());
        await publish([b]);
        expect(dataOf(watch.state), [a, b, c]);
        const last = RoomView(id: 4, name: 'd', rank: 99);
        const first = RoomView(id: 5, name: 'e', rank: 1);
        await publish([last, first]);
        expect(dataOf(watch.state), [first, a, b, c, last]);
      },
    );

    test('a re-ranked object keeps its place even with a sort', () async {
      h.rooms = [a, b, c];
      final watch = await watched(const ListRoomsByRank());
      const promoted = RoomView(id: 3, name: 'c', rank: 1);
      await publish([promoted]);
      expect(dataOf(watch.state), [a, b, promoted]);
    });

    test('a new object that does not match is ignored', () async {
      h.rooms = [b, c];
      final watch = await watched(const ListRooms(minRank: 20));
      await publish([a]);
      expect(dataOf(watch.state), [b, c]);
    });

    test('a deletion removes', () async {
      final watch = await watched(const ListRooms());
      await publish([deleted(1)]);
      expect(dataOf(watch.state), [b]);
    });

    test(
      'a deletion of another type with the same id changes nothing',
      () async {
        final watch = await watched(const ListRooms());
        await publish([DwDeleted.of<NoteView>(1, roomsProtocol)]);
        expect(dataOf(watch.state), [a, b]);
      },
    );

    test('objects of another type are not the list\'s business', () async {
      final watch = await watched(const ListRooms());
      await publish([const NoteView(id: 7, text: 'x')]);
      expect(dataOf(watch.state), [a, b]);
    });

    test('an equal object changes nothing and emits nothing', () async {
      final watch = await watched(const ListRooms());
      final before = watch.state;
      await publish([a]);
      expect(identical(watch.state, before), isTrue);
    });

    test('a batch applies in order', () async {
      final watch = await watched(const ListRooms());
      const renamed = RoomView(id: 3, name: 'c2', rank: 30);
      await publish([c, renamed, deleted(1)]);
      expect(dataOf(watch.state), [renamed, b]);
    });

    test('the list keeps its reified item type through changes', () async {
      final watch = await watched(const ListRooms());
      await publish([c, deleted(2)]);
      expect(dataOf(watch.state), isA<List<RoomView>>());
    });
  });

  group('single', () {
    test('the same id is replaced', () async {
      final watch = await watched(const GetRoom(1));
      const renamed = RoomView(id: 1, name: 'a2', rank: 10);
      await publish([renamed], const DwChannel(AppChannel.room, 1));
      expect(dataOf(watch.state), renamed);
    });

    test('another id is ignored', () async {
      final watch = await watched(const GetRoom(1));
      await publish([b], const DwChannel(AppChannel.room, 1));
      expect(dataOf(watch.state), a);
      expect(h.server.requestsOf<GetRoom>(), hasLength(1));
    });

    test('a deletion refetches, and the answer is not-found', () async {
      final watch = await watched(const GetRoom(1));
      h.rooms = [b];
      await publish([deleted(1)], const DwChannel(AppChannel.room, 1));
      expect(h.server.requestsOf<GetRoom>(), hasLength(2));
      expect(
        watch.state,
        DwRequestRefused<RoomView>(DwRefusal(DwCoreRefusal.notFound)),
      );
    });
  });

  group('maybe', () {
    test(
      'an absent object is filled when a matching one arrives (#242)',
      () async {
        h.rooms = [];
        final watch = await watched(const FindRoom('c'));
        expect(watch.state, const DwRequestData<RoomView?>(null, live: true));
        await publish([a]);
        expect(dataOf(watch.state), isNull, reason: 'does not match');
        await publish([c]);
        expect(dataOf(watch.state), c);
      },
    );

    test('the held object is replaced by id, others ignored', () async {
      final watch = await watched(const FindRoom('a'));
      const renamed = RoomView(id: 1, name: 'a', rank: 11);
      await publish([b, renamed]);
      expect(dataOf(watch.state), renamed);
    });

    test('a deletion of the held object empties it', () async {
      final watch = await watched(const FindRoom('a'));
      await publish([deleted(2)]);
      expect(dataOf(watch.state), a);
      await publish([deleted(1)]);
      expect(dataOf(watch.state), isNull);
      expect(
        h.server.requestsOf<FindRoom>(),
        hasLength(1),
        reason: 'no refetch',
      );
    });
  });

  group('explicit actions', () {
    test('upsert inserts ignoring matches; remove removes by id', () async {
      h.server.onRequest<ListRoomsByRank>((r, call) => const DwOk([a]));
      final watch = await watched(const _Explicit());
      await publish([b]);
      expect(dataOf(watch.state), [b, a]);
      await publish([const RoomView(id: 1, name: 'gone', rank: -1)]);
      expect(dataOf(watch.state), [b]);
    });
  });
}

/// Upserts rooms; a room with a negative rank removes the room with its id.
final class _Explicit extends DwListRequest<RoomView> {
  const _Explicit();

  @override
  List<DwChannel> get channels => const [rooms];

  @override
  bool matches(RoomView object) => false;

  @override
  DwUpdate onUpdate(DwDto update) => switch (update) {
    RoomView(:final rank) when rank < 0 => DwUpdate.remove,
    RoomView() => DwUpdate.upsert,
    _ => DwUpdate.ignore,
  };

  @override
  String get dwTypeName => 'ListRoomsByRank';

  @override
  Map<String, Object?> toJson() => const {};

  @override
  bool operator ==(Object other) => other is _Explicit;

  @override
  int get hashCode => 4;
}
