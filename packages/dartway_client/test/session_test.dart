import 'package:dartway_client/dartway_client.dart';
import 'package:dartway_client/testing.dart';
import 'package:test/test.dart';

import 'support.dart';

const session = DwSession(id: 42, token: 'token-42', isNewAccount: false);

void main() {
  /// Serves [ListRooms] only to signed-in connections, and [FindRoom] with the
  /// caller's account in the name, so a re-run under another account shows.
  void serveAccountData(Harness h) {
    h.server
      ..registerToken(session.token, session.id)
      ..onRequest<ListRooms>(
        (r, call) => call.accountId == null
            ? const DwNotAuthenticated<List<RoomView>>()
            : const DwOk([a, b]),
      )
      ..onRequest<FindRoom>(
        (r, call) =>
            DwOk<RoomView?>(RoomView(id: 9, name: 'for ${call.accountId}')),
      );
  }

  test(
    'a fresh client is anonymous and sends no authentication at all',
    () async {
      final h = Harness();
      serveAccountData(h);
      final sessions = DwRecording(h.client.session);
      await h.start();
      expect(h.client.accountId, isNull);
      expect(sessions.values, [null]);
      expect(h.server.receivedOf<DwAuthenticateMessage>(), isEmpty);
    },
  );

  test(
    'a stored session authenticates first, before any queued call',
    () async {
      final store = DwMemoryTokenStore(session);
      final h = Harness(tokenStore: store);
      serveAccountData(h);
      final result = h.client.fetch(const ListRooms());
      await h.client.start();
      expect(
        h.client.accountId,
        42,
        reason: 'known from the store before the server answers',
      );
      expect((await result).valueOrNull, [a, b]);
      expect(h.server.received.first, isA<DwAuthenticateMessage>());
    },
  );

  test(
    'signIn stores the session, authenticates and re-runs watches',
    () async {
      final store = DwMemoryTokenStore();
      final h = Harness(tokenStore: store);
      serveAccountData(h);
      await h.start();
      final watch = h.client.watch(const FindRoom('x'));
      await settle();
      expect(dataOf(watch.state)!.name, 'for null');

      final sessions = DwRecording(h.client.session);
      await h.client.signIn(session);
      await settle();

      expect(store.session, session);
      expect(h.client.accountId, 42);
      expect(sessions.values, [null, 42]);
      expect(h.server.openConnections.single.accountId, 42);
      expect(dataOf(watch.state)!.name, 'for 42');
    },
  );

  test('signIn while offline authenticates on the next connection', () async {
    final h = Harness();
    serveAccountData(h);
    h.server.acceptsConnections = false;
    await h.client.start();
    await h.client.signIn(session);
    expect(h.client.accountId, 42);
    h.server.acceptsConnections = true;
    expect((await h.client.fetch(const ListRooms())).valueOrNull, [a, b]);
    expect(
      h.server.receivedOf<DwAuthenticateMessage>().single.token,
      session.token,
    );
  });

  test('signOut revokes, clears, continues anonymously and re-runs', () async {
    final store = DwMemoryTokenStore(session);
    final h = Harness(tokenStore: store);
    serveAccountData(h);
    await h.start();
    final watch = h.client.watch(const FindRoom('x'));
    final list = h.client.watch(const ListRooms());
    await settle();
    expect(dataOf(watch.state)!.name, 'for 42');
    expect(h.server.subscriberCount(rooms), 1);

    await h.client.signOut();
    await settle();

    expect(h.server.commandsOf<DwSignOut>(), hasLength(1));
    expect(h.server.isTokenValid(session.token), isFalse);
    expect(store.session, isNull);
    expect(h.client.accountId, isNull);
    // A successful sign-out leaves the connection anonymous: no second
    // authentication is sent.
    expect(h.server.receivedOf<DwAuthenticateMessage>(), hasLength(1));
    expect(h.server.openConnections.single.accountId, isNull);
    expect(dataOf(watch.state)!.name, 'for null');
    expect(list.state, const DwRequestUnauthenticated<List<RoomView>>());
    // The server dropped the subscription with the key; the client made it
    // again, anonymously.
    expect(h.server.subscribeCount(rooms), 2);
    expect(h.server.subscriberCount(rooms), 1);
  });

  test('signOut while offline ends the local session only', () async {
    final store = DwMemoryTokenStore(session);
    final h = Harness(tokenStore: store);
    serveAccountData(h);
    h.server.acceptsConnections = false;
    await h.client.start();
    await h.client.signOut();
    expect(h.client.accountId, isNull);
    expect(store.session, isNull);
    h.server.acceptsConnections = true;
    await h.client.fetch(const FindRoom('x'));
    expect(h.server.commandsOf<DwSignOut>(), isEmpty);
    expect(h.server.receivedOf<DwAuthenticateMessage>(), isEmpty);
  });

  test(
    'a rejected token clears the session and the app continues anonymously',
    () async {
      final store = DwMemoryTokenStore(
        const DwSession(id: 7, token: 'stale', isNewAccount: false),
      );
      final h = Harness(tokenStore: store);
      serveAccountData(h);
      final sessions = DwRecording(h.client.session);
      await h.start();
      final watch = h.client.watch(const FindRoom('x'));
      await settle();
      expect(h.client.accountId, isNull);
      expect(sessions.values, [null, 7, null]);
      expect(store.session, isNull);
      expect(dataOf(watch.state)!.name, 'for null');
      expect(
        h.server.requestsOf<FindRoom>(),
        hasLength(1),
        reason: 'sent after the answer, once',
      );
    },
  );

  test(
    'a not-authenticated answer clears the session it was sent under',
    () async {
      final store = DwMemoryTokenStore(session);
      final h = Harness(tokenStore: store);
      serveAccountData(h);
      var expired = false;
      h.server.onRequest<ListRooms>(
        (r, call) => expired || call.accountId == null
            ? const DwNotAuthenticated<List<RoomView>>()
            : const DwOk([a, b]),
      );
      await h.start();
      final watch = h.client.watch(const ListRooms());
      await settle();
      expect(watch.state, const DwRequestData([a, b], live: true));

      expired = true;
      final result = await h.client.fetch(const ListRooms());
      expect(result, isA<DwNotAuthenticated<List<RoomView>>>());
      await settle();

      expect(h.client.accountId, isNull);
      expect(store.session, isNull);
      expect(watch.state, const DwRequestUnauthenticated<List<RoomView>>());
      expect(
        h.server.requestsOf<ListRooms>(),
        hasLength(3),
        reason: 'watch, fetch, one re-run',
      );
    },
  );

  test(
    'a session revoked elsewhere ends here too, with one re-run per watch',
    () async {
      final h = Harness(tokenStore: DwMemoryTokenStore(session));
      serveAccountData(h);
      final other = h.server.newClient(tokenStore: DwMemoryTokenStore(session));
      addTearDown(other.stop);
      await h.start();
      await other.start();
      final watch = h.client.watch(const FindRoom('x'));
      await settle();
      expect(dataOf(watch.state)!.name, 'for 42');
      expect(watch.isLive, isTrue);

      await other.signOut();
      await settle();

      expect(h.client.accountId, isNull);
      expect(dataOf(watch.state)!.name, 'for null');
      expect(h.server.requestsOf<FindRoom>(), hasLength(2));
      expect(watch.isLive, isTrue, reason: 'subscribed again, anonymously');
      expect(h.reported, isEmpty);
    },
  );

  test('the server corrects the account a token belongs to', () async {
    final store = DwMemoryTokenStore(
      const DwSession(id: 1, token: 'token-42', isNewAccount: false),
    );
    final h = Harness(tokenStore: store);
    serveAccountData(h);
    await h.start();
    expect(h.client.accountId, 42);
    expect(store.session?.id, 42);
  });
}
