import 'dart:async';

import 'package:dartway_client/dartway_client.dart';
import 'package:dartway_client/testing.dart';
import 'package:test/test.dart';

import 'fixtures/rooms.dart';

export 'fixtures/rooms.dart';

const a = RoomView(id: 1, name: 'a', rank: 10);
const b = RoomView(id: 2, name: 'b', rank: 20);
const c = RoomView(id: 3, name: 'c', rank: 30);

const alice = DwAuthSession(id: 7, token: 'token-7', isNewAccount: false);
const bob = DwAuthSession(id: 8, token: 'token-8', isNewAccount: false);

/// A fake server and a client of it, torn down after the test.
///
/// Signed in as [alice] unless [signedIn] is false: every subscription needs
/// an account (D-020), so most live behaviour is a signed-in one.
final class Harness {
  Harness({
    bool signedIn = true,
    DwClientOptions options = dwFakeClientOptions,
    String appVersion = '1.0.0+1',
    DwTokenStore? tokenStore,
  }) : store = tokenStore ?? DwMemoryTokenStore(signedIn ? alice : null) {
    server
      ..registerToken(alice.token, alice.id)
      ..registerToken(bob.token, bob.id);
    client = server.newClient(
      tokenStore: store,
      options: options,
      appVersion: appVersion,
      onError: (error, stackTrace) => reported.add(error),
    );
    addTearDown(() async {
      await client.stop();
      expect(server.errors, isEmpty, reason: 'the fake server saw errors');
      expect(reported, isEmpty, reason: 'the client reported errors');
    });
  }

  final server = DwFakeServer(protocol: roomsProtocol);
  final DwTokenStore store;
  late final DwAppClient client;

  /// What the client reported to `onError`. Tests that expect a report take
  /// it out; anything left fails the test at teardown.
  final List<Object> reported = [];

  /// Rooms served by the room requests.
  List<RoomView> rooms = [a, b];

  /// Notes served by [ListMyNotes], per account.
  Map<int, List<NoteView>> notes = {};

  /// Chat lines, newest first.
  List<ChatLine> chat = [];

  void serveRooms() {
    server
      ..onRequest<ListRooms>(
        (request, call) =>
            DwCallOk(rooms.where((r) => request.matches(r)).toList()),
      )
      ..onRequest<ListRoomsByRank>(
        (request, call) =>
            DwCallOk(rooms.toList()..sort((x, y) => x.rank.compareTo(y.rank))),
      )
      ..onRequest<ListRoomsOffline>((request, call) => DwCallOk(rooms.toList()))
      ..onRequest<ListPinnedRooms>((request, call) => DwCallOk(rooms.toList()))
      ..onRequest<ListRoomStats>((request, call) => DwCallOk(rooms.toList()))
      ..onRequest<GetRoom>((request, call) {
        for (final room in rooms) {
          if (room.id == request.roomId) return DwCallOk(room);
        }
        return DwCallRefused<RoomView>(DwCallRefusal(DwCoreRefusal.notFound));
      })
      ..onRequest<FindRoom>((request, call) {
        for (final room in rooms) {
          if (room.name == request.name) return DwCallOk<RoomView?>(room);
        }
        return const DwCallOk<RoomView?>(null);
      })
      ..onRequest<FeedRooms>((request, call) {
        final ordered = rooms.toList();
        if (request.sorted) ordered.sort((x, y) => x.rank.compareTo(y.rank));
        return DwCallOk(dwFakeOffsetPage(ordered, request, call.page));
      })
      ..onRequest<RoomsTable>(
        (request, call) => DwCallOk(
          dwFakeTablePage(rooms.where(request.matches).toList(), request),
        ),
      )
      ..onRequest<ListMyNotes>((request, call) {
        final account = call.accountId;
        if (account == null) return const DwNotAuthenticated<List<NoteView>>();
        return DwCallOk(notes[account]?.toList() ?? <NoteView>[]);
      })
      ..onRequest<ReadChat>(
        (request, call) => DwCallOk(dwFakeWindow(chat, request, call.page)),
      )
      ..onCommand<RenameRoom>((command, call) {
        final renamed = RoomView(
          id: command.roomId,
          name: command.name,
          rank: rooms.firstWhere((r) => r.id == command.roomId).rank,
        );
        rooms = [for (final r in rooms) r.id == renamed.id ? renamed : r];
        call.publish(roomsChannel, [renamed]);
        return DwCallOk(renamed);
      })
      ..onCommand<DeleteRoom>((command, call) {
        rooms = rooms.where((r) => r.id != command.roomId).toList();
        call.publish(roomsChannel, [
          DwDeletedObject.of<RoomView>(command.roomId, roomsProtocol),
        ]);
        return const DwCallOk<void>(null);
      });
  }

  Future<void> start() async {
    await client.start();
    await settle();
  }

  /// Takes the reports of type [E] out of [reported] and returns them.
  List<E> takeReported<E>() {
    final taken = reported.whereType<E>().toList();
    reported.removeWhere((error) => error is E);
    return taken;
  }
}

/// Lets in-memory traffic, microtasks and the client's short timers run.
Future<void> settle() async {
  for (var i = 0; i < 6; i++) {
    await pumpEventQueue();
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
  await pumpEventQueue();
}

/// Waits until [condition] holds, or fails after [timeout].
Future<void> until(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 3),
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

List<RoomView> pagedItems(DwRequestState<DwPagedData<RoomView>> state) =>
    dataOf(state).items;

/// The wire names of the calls the server answered, in order.
List<String> callNames(DwFakeServer server) => [
  for (final call in server.calls) call.wireName,
];

/// A gate a handler awaits, so a test controls when an answer leaves.
final class Gate {
  Completer<void> _completer = Completer<void>();

  Future<void> get passed => _completer.future;

  void open() {
    if (!_completer.isCompleted) _completer.complete();
  }

  void close() {
    if (_completer.isCompleted) _completer = Completer<void>();
  }
}
