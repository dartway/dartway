import 'dart:async';

import 'package:dartway_client/dartway_client.dart';
import 'package:dartway_client/testing.dart';
import 'package:test/test.dart';

import 'fixtures/rooms.dart';

export 'fixtures/rooms.dart';

const a = RoomView(id: 1, name: 'a', rank: 10);
const b = RoomView(id: 2, name: 'b', rank: 20);
const c = RoomView(id: 3, name: 'c', rank: 30);

/// A fake server and a client of it, torn down after the test.
final class Harness {
  Harness({DwTokenStore? tokenStore, DwClientOptions? options}) {
    client = options == null
        ? server.newClient(tokenStore: tokenStore, onError: _onError)
        : server.newClient(
            tokenStore: tokenStore,
            options: options,
            onError: _onError,
          );
    addTearDown(() async {
      await client.stop();
      expect(server.errors, isEmpty, reason: 'the fake server saw errors');
    });
  }

  final server = DwFakeServer(protocol: roomsProtocol);
  late final DwClient client;

  /// What the client reported to `onError`. Tests that expect a report take
  /// it out; anything left fails the test at teardown.
  final List<Object> reported = [];

  void _onError(Object error, StackTrace stackTrace) => reported.add(error);

  /// Rooms served by [ListRooms], [ListRoomsByRank], [GetRoom], [FindRoom].
  List<RoomView> rooms = [a, b];

  void serveRooms() {
    server
      ..onRequest<ListRooms>(
        (request, call) => DwOk(
          rooms
              .where(
                (r) => request.minRank == null || r.rank >= request.minRank!,
              )
              .toList(),
        ),
      )
      ..onRequest<ListRoomsByRank>(
        (request, call) =>
            DwOk(rooms.toList()..sort((x, y) => x.rank.compareTo(y.rank))),
      )
      ..onRequest<GetRoom>((request, call) {
        for (final room in rooms) {
          if (room.id == request.roomId) return DwOk(room);
        }
        return DwRefused<RoomView>(DwRefusal(DwCoreRefusal.notFound));
      })
      ..onRequest<FindRoom>((request, call) {
        for (final room in rooms) {
          if (room.name == request.name) return DwOk<RoomView?>(room);
        }
        return const DwOk<RoomView?>(null);
      });
  }

  Future<void> start() async {
    await client.start();
    await settle();
  }
}

/// Lets in-memory frames, microtasks and the client's short timers run.
Future<void> settle() async {
  for (var i = 0; i < 4; i++) {
    await pumpEventQueue();
    await Future<void>.delayed(const Duration(milliseconds: 3));
  }
  await pumpEventQueue();
}

/// Waits until [condition] holds, or fails after [timeout].
Future<void> until(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 2),
  String? reason,
}) async {
  final stopwatch = Stopwatch()..start();
  while (!condition()) {
    if (stopwatch.elapsed > timeout) {
      fail('Timed out waiting${reason == null ? '' : ' for $reason'}');
    }
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
}

T dataOf<T>(DwRequestState<T> state) => switch (state) {
  DwRequestData(:final value) => value,
  _ => throw TestFailure('Expected data, got $state'),
};

List<RoomView> itemsOf(DwRequestState<DwPagedData<RoomView>> state) =>
    dataOf(state).items;
