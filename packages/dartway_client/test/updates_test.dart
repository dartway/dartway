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

  group('routing by channel (D-036)', () {
    test('every entry on the channel gets the objects it accepts, from a '
        'response and from the socket; an entry without the channel gets '
        'nothing', () async {
      final h = Harness()..serveRooms();
      await h.start();
      final live = h.client.watch(const ListRooms());
      final offline = h.client.watch(const ListRoomsOffline());
      final byRank = h.client.watch(const ListRoomsByRank());
      await settle();

      await h.client.command(const RenameRoom(roomId: 1, name: 'a2'));
      const renamed = RoomView(id: 1, name: 'a2', rank: 10);
      expect(dataOf(live.state), [renamed, b]);
      expect(dataOf(byRank.state), [renamed, b]);
      expect(dataOf(offline.state), [a, b], reason: 'no channel, no update');

      h.server.publish(roomsChannel, [c]);
      await settle();
      expect(dataOf(live.state), [c, renamed, b]);
      expect(dataOf(offline.state), [a, b]);
    });

    test("a response carrying another account's object of the same type, on "
        'a channel the caller listens to for that account, does not reach the '
        "caller's own request", () async {
      final protocol = DwWireProtocol([
        const DwProtocolEntry<_NotesOfBob>('NotesOfBob', _NotesOfBob.fromJson),
      ], include: roomsProtocol);
      final server = DwFakeServer(protocol: protocol)
        ..registerToken(alice.token, alice.id)
        ..onRequest<ListMyNotes>(
          (request, call) => const DwCallOk([NoteView(id: 1, text: 'mine')]),
        )
        ..onRequest<_NotesOfBob>(
          (request, call) =>
              const DwCallOk([NoteView(id: 1, text: "bob's note 1")]),
        )
        // An admin's edit of Bob's note, which also tells the admin something
        // on her own channel.
        ..onCommand<RenameRoom>((command, call) {
          call
            ..publish(DwLiveChannel.forAccount(AppChannel.notes, bob.id), [
              const NoteView(id: 1, text: "bob's edit of his note 1"),
            ])
            ..publish(DwLiveChannel.forAccount(AppChannel.notes, alice.id), [
              const NoteView(id: 2, text: 'for alice'),
            ]);
          return const DwCallOk(RoomView(id: 1, name: 'a'));
        });
      final client = server.newClient(tokenStore: DwMemoryTokenStore(alice));
      addTearDown(client.stop);
      await client.start();
      final mine = client.watch(const ListMyNotes());
      final bobs = client.watch(const _NotesOfBob());
      await settle();
      expect(mine.isLive && bobs.isLive, isTrue);

      await client.command(const RenameRoom(roomId: 1, name: 'a'));
      final call = server.callsOf<RenameRoom>().single;
      expect(call.liveConnectionId, isNotNull);
      // The named connection listens to both, so the response carries both:
      // only the channel tells whose note 1 is.
      expect((call.response as DwApiOk).updates.channels.keys, [
        'notes:8',
        'notes:7',
      ]);
      expect(dataOf(mine.state), [
        const NoteView(id: 2, text: 'for alice'),
        const NoteView(id: 1, text: 'mine'),
      ]);
      expect(dataOf(bobs.state), [
        const NoteView(id: 1, text: "bob's edit of his note 1"),
      ]);
      expect(server.errors, isEmpty);
    });

    test('the fake server, like a real one, refuses to publish to an '
        'unresolved caller channel', () async {
      final h = Harness()..serveRooms();
      h.server.onCommand<RenameRoom>((command, call) {
        call.publish(myNotesChannel, [const NoteView(id: 1, text: 'whose?')]);
        return const DwCallOk(RoomView(id: 1, name: 'a'));
      });
      await h.start();
      final result = await h.client.command(
        const RenameRoom(roomId: 1, name: 'a'),
      );
      expect(result, isA<DwCallFailed<RoomView>>());
      expect(h.server.errors.single, isA<ArgumentError>());
      h.server.errors.clear();
    });

    test("without a live socket, a command still updates its caller's lists "
        'from the response: the channels it may read, and no other', () async {
      final h = Harness()..serveRooms();
      const renamed = RoomView(id: 1, name: 'a2', rank: 10);
      h.server
        ..acceptsConnections = false
        ..subscriptionRule = ((channel, accountId) =>
            channel == 'room:1' ? DwCallRefusal(DwCoreRefusal.forbidden) : null)
        ..onCommand<RenameRoom>((command, call) {
          call
            ..publish(roomsChannel, [renamed])
            ..publish(const DwLiveChannel(AppChannel.room, 1), [renamed]);
          return const DwCallOk(renamed);
        });
      await h.start();
      final rooms = h.client.watch(const ListRooms());
      await settle();
      expect(rooms.isLive, isFalse);

      await h.client.command(const RenameRoom(roomId: 1, name: 'a2'));
      final call = h.server.callsOf<RenameRoom>().single;
      expect(call.liveConnectionId, isNull);
      expect((call.response as DwApiOk).updates.channels.keys, ['rooms']);
      expect(dataOf(rooms.state), [renamed, b]);
    });

    test('a socket update is applied only to entries on its channel, '
        'whatever the type', () async {
      final h = Harness()..serveRooms();
      await h.start();
      final mine = h.client.watch(const ListMyNotes());
      await settle();
      expect(mine.isLive, isTrue);
      h.server.publish(roomsChannel, [const NoteView(id: 5, text: 'stray')]);
      h.server.publish(DwLiveChannel.forAccount(AppChannel.notes, alice.id), [
        const NoteView(id: 6, text: 'mine'),
      ]);
      await settle();
      expect(dataOf(mine.state), [const NoteView(id: 6, text: 'mine')]);
    });

    test('an entry on two channels applies an object published to both '
        'once', () async {
      final protocol = DwWireProtocol([
        const DwProtocolEntry<_RoomsAndRoom3>(
          'RoomsAndRoom3',
          _RoomsAndRoom3.fromJson,
        ),
      ], include: roomsProtocol);
      const renamed = RoomView(id: 3, name: 'c3');
      final server = DwFakeServer(protocol: protocol)
        ..registerToken(alice.token, alice.id)
        ..onRequest<_RoomsAndRoom3>((r, call) => const DwCallOk([a, b]))
        ..onCommand<RenameRoom>((command, call) {
          call
            ..publish(roomsChannel, [renamed])
            ..publish(const DwLiveChannel(AppChannel.room, 3), [renamed]);
          return const DwCallOk(renamed);
        });
      final client = server.newClient(tokenStore: DwMemoryTokenStore(alice));
      addTearDown(client.stop);
      await client.start();
      final both = client.watch(const _RoomsAndRoom3());
      await settle();
      expect(both.isLive, isTrue);
      final states = DwStreamRecording(both.states);

      await client.command(const RenameRoom(roomId: 3, name: 'c3'));
      final response = server.callsOf<RenameRoom>().single.response as DwApiOk;
      expect(response.updates.channels.keys, ['rooms', 'room:3']);
      expect(dataOf(both.state), [renamed, a, b]);
      expect(states.values, hasLength(2), reason: 'replayed, then one change');
      expect(server.errors, isEmpty);
    });

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

/// Rooms live on `rooms` and on `room:3`.
final class _RoomsAndRoom3 extends DwListRequest<RoomView> {
  const _RoomsAndRoom3();

  static _RoomsAndRoom3 fromJson(Map<String, Object?> json) =>
      const _RoomsAndRoom3();

  @override
  List<DwLiveChannel> get channels => const [
    roomsChannel,
    DwLiveChannel(AppChannel.room, 3),
  ];

  @override
  String get dwTypeName => 'RoomsAndRoom3';

  @override
  Map<String, Object?> toJson() => const {};

  @override
  bool operator ==(Object other) => other is _RoomsAndRoom3;

  @override
  int get hashCode => 1;
}

/// Bob's notes, as a staff screen watches them: on `notes:<bob>`.
final class _NotesOfBob extends DwListRequest<NoteView> {
  const _NotesOfBob();

  static _NotesOfBob fromJson(Map<String, Object?> json) => const _NotesOfBob();

  @override
  List<DwLiveChannel> get channels => [
    DwLiveChannel.forAccount(AppChannel.notes, bob.id),
  ];

  @override
  String get dwTypeName => 'NotesOfBob';

  @override
  Map<String, Object?> toJson() => const {};

  @override
  bool operator ==(Object other) => other is _NotesOfBob;

  @override
  int get hashCode => 2;
}

/// A list whose onUpdate throws for one object.
final class _ThrowingList extends DwListRequest<RoomView> {
  const _ThrowingList();

  @override
  List<DwLiveChannel> get channels => const [roomsChannel];

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
