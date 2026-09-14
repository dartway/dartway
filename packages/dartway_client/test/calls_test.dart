import 'dart:async';
import 'dart:math';
import 'dart:convert';

import 'package:dartway_client/dartway_client.dart';
import 'package:dartway_client/testing.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  group('the HTTP contract', () {
    test('a request is POST /dw/<name> with its JSON, versions and the '
        'bearer', () async {
      final h = Harness()..serveRooms();
      await h.start();
      final result = await h.client.fetch(const ListRooms(minRank: 15));

      expect(result, isA<DwCallOk<List<RoomView>>>());
      expect(result.valueOrNull, [b]);
      final call = h.server.calls.single;
      expect(call.wireName, 'ListRooms');
      expect(call.call, const ListRooms(minRank: 15));
      expect(call.headers['dw-protocol'], '1');
      expect(call.headers['dw-app-version'], '1.0.0+1');
      expect(call.headers['content-type'], DwHttpContract.jsonContentType);
      expect(call.authorization, 'Bearer token-7');
      expect(call.idempotencyKey, isNull, reason: 'forbidden for requests');
      expect(call.query, isEmpty);
    });

    test('an anonymous call carries no Authorization', () async {
      final h = Harness(signedIn: false)..serveRooms();
      await h.start();
      await h.client.fetch(const ListRooms());
      expect(h.server.calls.single.authorization, isNull);
    });

    test('page parameters travel in the query, validated by kind', () async {
      final h = Harness()..serveRooms();
      h.rooms = [a, b, c];
      await h.start();
      final page = await h.client.fetch(
        const FeedRooms(),
        page: const DwOffsetQuery(offset: 2),
      );
      expect(
        page.valueOrNull,
        DwPageResult<RoomView>(const [c], hasMore: false),
      );
      expect(h.server.calls.single.query, {'offset': '2'});

      expect(
        () => h.client.fetch(
          const FeedRooms(),
          page: const DwWindowQuery.newest(),
        ),
        throwsArgumentError,
      );
      expect(
        () => h.client.fetch(
          const ListRooms(),
          page: const DwOffsetQuery(offset: 1),
        ),
        throwsArgumentError,
      );
    });

    test('the base URL may carry a path prefix', () async {
      final posts = <Uri>[];
      final server = DwFakeServer(protocol: roomsProtocol)
        ..onRequest<ListRoomsOffline>((r, call) => const DwCallOk([a]));
      final client = DwAppClient(
        protocol: roomsProtocol,
        baseUrl: Uri.parse('https://app.example.com/backend/'),
        appVersion: '2.0.0+9',
        random: Random(),
        httpTransport: DwMemoryHttpTransport((post) {
          posts.add(post.url);
          return server.httpTransport.handle(
            DwHttpPost(
              url: server.baseUrl.replace(path: '/dw/ListRoomsOffline'),
              headers: post.headers,
              body: post.body,
            ),
          );
        }),
        liveConnector: server.liveConnector,
      );
      addTearDown(client.stop);
      await client.start();
      await client.fetch(const ListRoomsOffline());
      expect(
        posts.single.toString(),
        'https://app.example.com/backend/dw/ListRoomsOffline',
      );
    });

    test('a malformed app version or base URL is refused at construction', () {
      final server = DwFakeServer(protocol: roomsProtocol);
      expect(() => server.newClient(appVersion: '1.0'), throwsFormatException);
      expect(
        () => DwAppClient(
          protocol: roomsProtocol,
          baseUrl: Uri.parse('ws://example.com'),
          appVersion: '1.0.0+1',
          random: Random(),
        ),
        throwsArgumentError,
      );
    });
  });

  group('results', () {
    test('ok, refused, not authenticated and failed are typed', () async {
      final h = Harness();
      h.server
        ..onCommand<RenameRoom>(
          (command, call) => DwCallRefused<RoomView>(
            DwCallRefusal(
              RoomRefusal.nameTaken,
              params: {'name': command.name},
            ),
          ),
        )
        ..onCommand<DeleteRoom>(
          (command, call) => command.roomId == 1
              ? const DwCallFailed<void>('incident-1')
              : const DwNotAuthenticated<void>(),
        )
        ..onRequest<GetRoom>((request, call) => const DwCallOk(a));
      await h.start();

      expect((await h.client.fetch(const GetRoom(1))).valueOrNull, a);
      final refused = await h.client.command(
        const RenameRoom(roomId: 1, name: 'x'),
      );
      expect(
        refused,
        isA<DwCallRefused<RoomView>>().having(
          (r) => r.refusal,
          'refusal',
          DwCallRefusal(RoomRefusal.nameTaken, params: {'name': 'x'}),
        ),
      );
      expect(h.server.calls[1].status, 422);
      expect(
        await h.client.command(const DeleteRoom(1)),
        isA<DwCallFailed<void>>().having(
          (f) => f.incidentId,
          'id',
          'incident-1',
        ),
      );
      expect(h.server.calls[2].status, 500);
    });

    test('a refusal with its own status reaches the caller typed', () async {
      final h = Harness();
      h.server.onRequest<GetRoom>(
        (request, call) => DwCallRefused<RoomView>(
          DwCallRefusal.tooManyRequests(const Duration(seconds: 3)),
        ),
      );
      await h.start();
      final result = await h.client.fetch(const GetRoom(1));
      expect(h.server.calls.single.status, 429);
      expect(
        (result as DwCallRefused).refusal.retryAfter,
        const Duration(seconds: 3),
      );
    });

    test('valueOrThrow turns outcomes into their exceptions', () {
      expect(const DwCallOk(1).valueOrThrow, 1);
      expect(
        () => DwCallRefused<int>(
          DwCallRefusal(DwCoreRefusal.forbidden),
        ).valueOrThrow,
        throwsA(isA<DwRefusalException>()),
      );
      expect(
        () => const DwNotAuthenticated<int>().valueOrThrow,
        throwsA(isA<DwNotAuthenticatedException>()),
      );
      expect(
        () => const DwCallFailed<int>('x').valueOrThrow,
        throwsA(const DwFailedException('x')),
      );
    });
  });

  group('local validation', () {
    test(
      'an invalid command is refused without reaching the network',
      () async {
        final h = Harness()..serveRooms();
        await h.start();
        h.server.reachable = false;
        final result = await h.client.command(
          const RenameRoom(roomId: 1, name: ''),
        );
        expect(
          result,
          isA<DwCallRefused<RoomView>>().having(
            (r) => r.refusal,
            'refusal',
            DwCallRefusal(DwCoreRefusal.invalid, field: 'name'),
          ),
        );
        expect(h.server.calls, isEmpty);
      },
    );

    test('a table page below 1 is refused locally', () async {
      final h = Harness()..serveRooms();
      await h.start();
      final result = await h.client.fetch(const RoomsTable(page: 0));
      expect(
        (result as DwCallRefused).refusal,
        DwCallRefusal(DwCoreRefusal.invalid, field: 'page', params: {'min': 1}),
      );
      expect(h.server.calls, isEmpty);
    });
  });

  group('idempotency', () {
    test('every command call carries a fresh key', () async {
      final h = Harness()..serveRooms();
      await h.start();
      await h.client.command(const RenameRoom(roomId: 1, name: 'x'));
      await h.client.command(const RenameRoom(roomId: 1, name: 'x'));
      final keys = h.server.callsOf<RenameRoom>().map((c) => c.idempotencyKey);
      expect(keys.toSet(), hasLength(2));
      expect(keys.first, matches(RegExp(r'^[0-9a-f]{32}$')));
    });

    test('a command whose answer was lost is retried with the same key and '
        'runs once', () async {
      final h = Harness()..serveRooms();
      await h.start();
      var lose = true;
      final original = h.server.httpTransport;
      final client = DwAppClient(
        protocol: roomsProtocol,
        baseUrl: h.server.baseUrl,
        appVersion: '1.0.0+1',
        random: Random(),
        tokenStore: DwMemoryTokenStore(alice),
        options: dwFakeClientOptions,
        httpTransport: DwMemoryHttpTransport((post) async {
          final reply = await original.handle(post);
          if (lose && post.url.path.endsWith('/RenameRoom')) {
            lose = false;
            // The server ran it; the answer never arrived.
            throw const DwFakeNetworkException();
          }
          return reply;
        }),
        liveConnector: h.server.liveConnector,
      );
      addTearDown(client.stop);
      await client.start();
      final watch = client.watch(const ListRoomsOffline());
      await settle();

      final result = await client.command(
        const RenameRoom(roomId: 1, name: 'renamed'),
      );
      await settle();
      expect(
        (h.server.callsOf<RenameRoom>().last.response as DwApiOk).replayed,
        isTrue,
      );
      expect(
        dataOf(watch.state).first.name,
        'renamed',
        reason: 'a replay carries no updates, so what is shown is read again',
      );
      expect(h.server.requestsOf<ListRoomsOffline>(), hasLength(2));
      expect(
        result.valueOrNull,
        const RoomView(id: 1, name: 'renamed', rank: 10),
      );
      final calls = h.server.callsOf<RenameRoom>();
      expect(calls, hasLength(2));
      expect(calls[0].idempotencyKey, calls[1].idempotencyKey);
      expect(h.server.executions(calls[0].idempotencyKey!), 1);
    });
  });

  group('retries', () {
    test(
      'a request is retried after network failures until it gets through',
      () async {
        final h = Harness()..serveRooms();
        await h.start();
        h.server.reachable = false;
        final future = h.client.fetch(const ListRoomsOffline());
        await settle();
        expect(h.server.calls, isEmpty);
        h.server.reachable = true;
        expect((await future).valueOrNull, [a, b]);
        expect(h.server.calls, hasLength(1));
      },
    );

    test("a gateway's 503 without a DartWay body is retried", () async {
      final h = Harness()..serveRooms();
      await h.start();
      var gatewayErrors = 2;
      h.server.interceptPost = (post) => gatewayErrors-- > 0
          ? const DwHttpReply(status: 503, body: '<html>Bad gateway</html>')
          : null;
      final result = await h.client.fetch(const ListRoomsOffline());
      expect(result.valueOrNull, [a, b]);
      expect(gatewayErrors, -1);
    });

    test('a DartWay answer is never retried, a failure included', () async {
      final h = Harness();
      var runs = 0;
      h.server.onRequest<GetRoom>((request, call) {
        runs++;
        return const DwCallFailed<RoomView>('boom');
      });
      await h.start();
      expect(await h.client.fetch(const GetRoom(1)), isA<DwCallFailed>());
      await settle();
      expect(runs, 1);
    });

    test('with no answer within callTimeout a call completes with '
        'DwTimeoutException naming the last error', () async {
      final h = Harness(
        options: const DwClientOptions(
          callTimeout: Duration(milliseconds: 60),
          retryDelay: Duration(milliseconds: 5),
          maxRetryDelay: Duration(milliseconds: 10),
        ),
      )..serveRooms();
      await h.start();
      h.server.reachable = false;
      await expectLater(
        h.client.command(const RenameRoom(roomId: 1, name: 'x')),
        throwsA(
          isA<DwTimeoutException>()
              .having((e) => e.call, 'call', 'RenameRoom')
              .having(
                (e) => e.lastError,
                'lastError',
                isA<DwFakeNetworkException>(),
              ),
        ),
      );
    });

    test(
      'an answer that is not a DartWay response is a DwProtocolException',
      () async {
        final h = Harness()..serveRooms();
        await h.start();
        h.server.interceptPost = (post) =>
            const DwHttpReply(status: 200, body: '{"status":"ok","extra":1}');
        await expectLater(
          h.client.fetch(const ListRoomsOffline()),
          throwsA(isA<DwProtocolException>()),
        );
        h.server.interceptPost = (post) => DwHttpReply(
          status: 500,
          body: jsonEncode(const DwApiResponse.ok(null).toJson()),
        );
        await expectLater(
          h.client.fetch(const ListRoomsOffline()),
          throwsA(isA<DwProtocolException>()),
          reason: 'a status that does not match its body is not trusted',
        );
      },
    );

    test('a result that does not decode is a DwProtocolException', () async {
      final h = Harness();
      h.server.interceptPost = (post) => DwHttpReply(
        status: 200,
        body: jsonEncode(const DwApiResponse.ok({'id': 'x'}).toJson()),
      );
      await h.start();
      await expectLater(
        h.client.fetch(const GetRoom(1)),
        throwsA(isA<DwProtocolException>()),
      );
    });
  });

  group('the response transport', () {
    test('is applied to watched state before the call completes', () async {
      final h = Harness()..serveRooms();
      await h.start();
      final watch = h.client.watch(const ListRooms());
      await settle();
      expect(dataOf(watch.state), [a, b]);

      final result = await h.client.command(
        const RenameRoom(roomId: 2, name: 'b2'),
      );
      // No settle: the state changed before the future completed.
      expect(dataOf(watch.state), [a, result.valueOrNull]);
      expect(h.server.requestsOf<ListRooms>(), hasLength(1));
    });

    test('carries deletions', () async {
      final h = Harness()..serveRooms();
      await h.start();
      final watch = h.client.watch(const ListRooms());
      await settle();
      await h.client.command(const DeleteRoom(1));
      expect(dataOf(watch.state), [b]);
    });

    test(
      'is dropped when the session changed while the call travelled',
      () async {
        final h = Harness()..serveRooms();
        final gate = Gate();
        // No socket: nothing but the response could carry the update to
        // Bob's list.
        h.server.acceptsConnections = false;
        await h.start();
        h.server.onCommand<RenameRoom>((command, call) async {
          await gate.passed;
          final renamed = RoomView(id: command.roomId, name: command.name);
          call.publish(roomsChannel, [renamed]);
          return DwCallOk(renamed);
        });
        final pending = h.client.command(
          const RenameRoom(roomId: 1, name: 'x'),
        );
        await settle();
        await h.client.signIn(bob);
        final watch = h.client.watch(const ListRooms());
        await settle();
        gate.open();
        await pending;
        final response =
            h.server.callsOf<RenameRoom>().single.response as DwApiOk;
        expect(response.updates.objectsOn('rooms'), hasLength(1));
        expect(dataOf(watch.state), [
          a,
          b,
        ], reason: "bob's list keeps its own data");
      },
    );
  });

  group('stop', () {
    test('ends unanswered calls and refuses new ones', () async {
      final h = Harness();
      final gate = Gate();
      h.server.onRequest<GetRoom>((request, call) async {
        await gate.passed;
        return const DwCallOk(a);
      });
      await h.start();
      final pending = expectLater(
        h.client.fetch(const GetRoom(1)),
        throwsA(const DwClientStoppedException()),
      );
      await settle();
      await h.client.stop();
      await pending;
      await expectLater(
        h.client.fetch(const GetRoom(1)),
        throwsA(const DwClientStoppedException()),
      );
      expect(() => h.client.watch(const GetRoom(1)), throwsStateError);
      gate.open();
    });

    test('a call made before start waits for the session', () async {
      final h = Harness()..serveRooms();
      final pending = h.client.fetch(const ListRoomsOffline());
      await settle();
      expect(h.server.calls, isEmpty);
      await h.client.start();
      expect((await pending).valueOrNull, [a, b]);
      expect(h.server.calls.single.authorization, 'Bearer token-7');
    });
  });

  test(
    'the client closes a transport it created, not an injected one',
    () async {
      final h = Harness()..serveRooms();
      await h.start();
      await h.client.stop();
      // The fake server's transport still carries calls for another client.
      final other = h.server.newClient(tokenStore: DwMemoryTokenStore(alice));
      addTearDown(other.stop);
      await other.start();
      expect((await other.fetch(const ListRoomsOffline())).isOk, isTrue);
      unawaited(Future<void>.value());
    },
  );
}
