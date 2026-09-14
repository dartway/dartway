import 'package:dartway_client/dartway_client.dart';
import 'package:dartway_client/testing.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  group('start', () {
    test('reads the stored session before anything is asked', () async {
      final h = Harness()..serveRooms();
      final watch = h.client.watch(const ListRoomsOffline());
      await settle();
      expect(watch.state, isA<DwRequestLoading>());
      expect(h.server.calls, isEmpty);
      await h.start();
      expect(h.client.accountId, alice.id);
      expect(dataOf(watch.state), [a, b]);
      expect(h.server.calls.single.authorization, 'Bearer token-7');
    });

    test('a store that cannot be read starts signed out, reported', () async {
      final h = Harness(tokenStore: _BrokenStore())..serveRooms();
      await h.start();
      expect(h.client.accountId, isNull);
      expect(h.takeReported<StateError>(), hasLength(1));
    });
  });

  group('account scope', () {
    test("signing in as another account never shows the previous account's "
        'data', () async {
      final h = Harness()..serveRooms();
      h.notes = {
        7: [const NoteView(id: 1, text: 'alice')],
        8: [const NoteView(id: 2, text: 'bob')],
      };
      await h.start();
      final watch = h.client.watch(const ListMyNotes());
      await settle();
      final states = DwStreamRecording(watch.states);
      expect(dataOf(watch.state), [const NoteView(id: 1, text: 'alice')]);

      await h.client.signIn(bob);
      expect(h.client.accountId, bob.id);
      expect(watch.state, isA<DwRequestLoading>(), reason: 'released at once');
      await settle();

      expect(dataOf(watch.state), [const NoteView(id: 2, text: 'bob')]);
      expect(states.values, [
        isA<DwRequestData>(),
        isA<DwRequestLoading>(),
        isA<DwRequestData>(),
      ]);
      expect(await h.store.read(), bob);
      final calls = h.server.callsOf<ListMyNotes>();
      expect(calls.map((c) => c.authorization), [
        'Bearer token-7',
        'Bearer token-8',
      ]);
      expect(
        calls.last.call,
        const ListMyNotes(),
        reason: 'no account id in it',
      );
    });

    test('the previous account\'s subscriptions are released before the socket '
        'authenticates as the next one', () async {
      final h = Harness()..serveRooms();
      await h.start();
      h.client.watch(const ListMyNotes());
      await settle();
      final before = h.server.received.length;

      await h.client.signIn(bob);
      await settle();
      // A caller channel is the account's own: another account, another
      // channel (D-037).
      expect(h.server.received.skip(before).map((m) => m.toJson()).toList(), [
        {'k': 'unsub', 'ch': 'notes:7'},
        {'k': 'auth', 'token': 'token-8'},
        {'k': 'sub', 'ch': 'notes:8'},
      ]);
      expect(h.server.connections.single.accountId, bob.id);
    });

    test(
      'an entry in its release delay is released with the account',
      () async {
        final h = Harness(
          options: const DwClientOptions(
            releaseDelay: Duration(minutes: 1),
            liveIdleDelay: Duration.zero,
            retryDelay: Duration(milliseconds: 1),
          ),
        )..serveRooms();
        h.notes = {
          7: [const NoteView(id: 1, text: 'alice')],
        };
        await h.start();
        h.client.watch(const ListMyNotes()).close();
        await settle();
        await h.client.signIn(bob);
        final watch = h.client.watch(const ListMyNotes());
        expect(watch.state, isA<DwRequestLoading>());
        await settle();
        expect(dataOf(watch.state), isEmpty);
      },
    );

    test('signing in again as the same account keeps the data', () async {
      final h = Harness()..serveRooms();
      await h.start();
      final watch = h.client.watch(const ListRoomsOffline());
      await settle();
      h.server.registerToken('token-7b', alice.id);
      await h.client.signIn(
        const DwAuthSession(id: 7, token: 'token-7b', isNewAccount: false),
      );
      await settle();
      expect(dataOf(watch.state), [a, b]);
      expect(h.server.requestsOf<ListRoomsOffline>(), hasLength(1));
    });
  });

  group('sign-out', () {
    test(
      'ends the session at once and revokes the key with its token',
      () async {
        final h = Harness()..serveRooms();
        await h.start();
        final notes = h.client.watch(const ListMyNotes());
        await settle();

        final signingOut = h.client.signOut();
        expect(h.client.accountId, isNull, reason: 'ended before the answer');
        await signingOut;
        await settle();

        final call = h.server.callsOf<DwSignOut>().single;
        expect(call.authorization, 'Bearer token-7');
        expect(h.server.isTokenValid(alice.token), isFalse);
        expect(await h.store.read(), isNull);
        expect(notes.state, const DwRequestUnauthenticated<List<NoteView>>());
      },
    );

    test('a sign-out the server did not carry out is reported; the local '
        'session is over anyway', () async {
      final h = Harness()..serveRooms();
      h.server.onCommand<DwSignOut>(
        (command, call) => const DwCallFailed<void>('revoke-failed'),
      );
      await h.start();
      await h.client.signOut();
      expect(h.client.accountId, isNull);
      expect(
        h.takeReported<DwSignOutException>().single.outcome,
        isA<DwCallFailed>(),
      );
    });

    test('while unreachable the sign-out times out, reported', () async {
      final h = Harness(
        options: const DwClientOptions(
          callTimeout: Duration(milliseconds: 40),
          retryDelay: Duration(milliseconds: 5),
        ),
      )..serveRooms();
      await h.start();
      h.server.reachable = false;
      await h.client.signOut();
      expect(h.client.accountId, isNull);
      expect(
        h.takeReported<DwSignOutException>().single.outcome,
        isA<DwTimeoutException>(),
      );
    });
  });

  group('the server ends a session', () {
    test('a not-authenticated answer to the current token ends it', () async {
      final h = Harness()..serveRooms();
      await h.start();
      h.server.revokeToken(alice.token);
      final result = await h.client.fetch(const ListRoomsOffline());
      expect(result, isA<DwNotAuthenticated>());
      expect(h.client.accountId, isNull);
      expect(await h.store.read(), isNull);
    });

    test('a not-authenticated answer to an older token does not end the new '
        'session', () async {
      final h = Harness()..serveRooms();
      final gate = Gate();
      await h.start();
      h.server.onRequest<GetRoom>((request, call) async {
        await gate.passed;
        return const DwNotAuthenticated<RoomView>();
      });
      final pending = h.client.fetch(const GetRoom(1));
      await settle();
      await h.client.signIn(bob);
      gate.open();
      expect(await pending, isA<DwNotAuthenticated>());
      expect(h.client.accountId, bob.id);
    });

    test('a revocation elsewhere arrives on the socket and ends it', () async {
      final h = Harness()..serveRooms();
      await h.start();
      final rooms = h.client.watch(const ListRooms());
      await settle();
      final accounts = DwStreamRecording(h.client.accountIdStream);
      h.server.revokeToken(alice.token);
      await settle();
      expect(accounts.values, [alice.id, null]);
      expect(await h.store.read(), isNull);
      expect(
        h.server.receivedOf<DwAuthenticateMessage>(),
        hasLength(1),
        reason: 'the server already unbound the socket',
      );
      expect(
        rooms.state,
        const DwRequestData([a, b]),
        reason: 'fetched again anonymously; not live without an account',
      );
    });

    test('a token the socket rejects ends the session', () async {
      final store = DwMemoryTokenStore(
        const DwAuthSession(id: 9, token: 'stale', isNewAccount: false),
      );
      final h = Harness(tokenStore: store)..serveRooms();
      h.server.onRequest<ListRooms>(
        (request, call) => DwCallOk(h.rooms.toList()),
      );
      await h.start();
      h.client.watch(const ListRooms());
      await settle();
      expect(h.client.accountId, isNull);
      expect(store.session, isNull);
    });

    test('the server corrects the account a token belongs to', () async {
      final store = DwMemoryTokenStore(
        const DwAuthSession(id: 99, token: 'token-7', isNewAccount: true),
      );
      final h = Harness(tokenStore: store)..serveRooms();
      await h.start();
      h.client.watch(const ListRooms());
      await settle();
      expect(h.client.accountId, alice.id);
      expect(store.session?.id, alice.id);
      expect(
        h.server.receivedOf<DwAuthenticateMessage>(),
        hasLength(1),
        reason: 'the same token needs no second authentication',
      );
    });
  });
}

final class _BrokenStore implements DwTokenStore {
  @override
  Future<DwAuthSession?> read() async => throw StateError('broken');

  @override
  Future<void> write(DwAuthSession session) async {}

  @override
  Future<void> clear() async {}
}
