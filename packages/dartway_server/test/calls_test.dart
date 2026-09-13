import 'dart:convert';
import 'dart:io';

import 'package:dartway_server/dartway_server.dart';
import 'package:dartway_server/testing.dart';
import 'package:test/test.dart';

import 'package:dartway_server/src/context/dw_context.dart';

import 'support/test_app.dart';

void main() {
  final harness = useHarness(
    build: (app, config) => app.server(
      config,
      routes: [
        DwRoute.get('/hello', (ctx, request) => DwRoute.json({'hello': 'w'})),
        DwRoute.post('/echo', (ctx, request) async {
          final body = await DwRoute.readJson(request);
          await ctx.jobs.enqueue('record', {'tag': body['tag']});
          return DwRoute.json(body, status: 201);
        }),
        DwRoute.get(
          '/refuse',
          (ctx, request) => ctx.refuse(DwCoreRefusal.forbidden),
        ),
        DwRoute.get(
          '/explode',
          (ctx, request) => throw StateError('route secret s3cr3t'),
        ),
      ],
    ),
  );

  late DwTestConnection anonymous;
  late DwTestConnection signed;
  late DwSession session;

  setUpAll(() async {
    anonymous = await harness().connect();
    (signed, session) = await harness().signedIn('calls@example.com');
  });

  Future<List<NoteView>> seed(String prefix, int count) async {
    final notes = <NoteView>[];
    for (var i = 0; i < count; i++) {
      final row = (await harness().db.query(
        'INSERT INTO note (text) VALUES (@text) RETURNING id',
        params: {'text': '$prefix-$i'},
      )).single;
      notes.add(NoteView(id: row.get<int>('id'), text: '$prefix-$i'));
    }
    return notes;
  }

  group('access', () {
    test('anonymous access needs no session', () async {
      final result = await anonymous.request(const ListNotes(ownerId: -1));
      expect(result.status, DwResultStatus.ok);
      expect(result.value, isEmpty);
    });

    test('signedIn answers unauthenticated without a session', () async {
      final result = await anonymous.request(const MyNotes());
      expect(result.status, DwResultStatus.unauthenticated);
      expect(result.refusal, isNull);
      expect(result.incidentId, isNull);
      expect(harness().app.alerts.incidents, isEmpty);
    });

    test('signedIn answers with a session', () async {
      final result = await signed.request(const MyNotes());
      expect(result.status, DwResultStatus.ok);
    });

    test('check: forbidden until the check passes, unauthenticated without '
        'a session', () async {
      expect(
        (await anonymous.request(const SecretNotes())).status,
        DwResultStatus.unauthenticated,
      );
      final refused = await signed.request(const SecretNotes());
      expect(refused.status, DwResultStatus.refused);
      expect(refused.refusal!.isCode(DwCoreRefusal.forbidden), isTrue);
      harness().app.secretReaders.add(session.id);
      expect(
        (await signed.request(const SecretNotes())).status,
        DwResultStatus.ok,
      );
    });

    test('requireAccountId in a handler answers unauthenticated', () async {
      final result = await anonymous.command(const NeedsAccount());
      expect(result.status, DwResultStatus.unauthenticated);
      final ok = await signed.command(const NeedsAccount());
      expect(ok.value, session.id);
    });
  });

  group('validation', () {
    test(
      'the first refusal of validate() is answered, before the handler',
      () async {
        final before = await harness().db.query(
          'SELECT count(*) AS n FROM note',
        );
        final result = await signed.command(const CreateNote(''));
        expect(result.status, DwResultStatus.refused);
        expect(result.refusal, DwRefusal(DwCoreRefusal.invalid, field: 'text'));
        final long = await signed.command(CreateNote('x' * 51));
        expect(long.refusal!.params, {'max': '50'});
        final after = await harness().db.query(
          'SELECT count(*) AS n FROM note',
        );
        expect(after.single['n'], before.single['n']);
      },
    );

    test('an unauthenticated call is not validated first', () async {
      final result = await anonymous.command(const CreateNote(''));
      expect(result.status, DwResultStatus.unauthenticated);
    });
  });

  group('request kinds', () {
    test('single: an absent object refuses notFound', () async {
      final result = await anonymous.request(const GetNote(-5));
      expect(result.refusal!.isCode(DwCoreRefusal.notFound), isTrue);
      final [note] = await seed('single', 1);
      final ok = await anonymous.request(GetNote(note.id));
      expect(ok.okValue(GetNote(note.id), testProtocol), note);
    });

    test('maybe: an absent object is a value', () async {
      final result = await anonymous.request(const FindNote(-5));
      expect(result.status, DwResultStatus.ok);
      expect(result.value, isNull);
      expect(jsonDecode(anonymous.frames.last), isNot(contains('v')));
    });

    test('offset pages read one row past the page and trim it', () async {
      final notes = await seed('feed', 7);
      const request = FeedNotes('feed-');
      final first = (await anonymous.request(
        request,
      )).okValue(request, testProtocol);
      expect(first.items, notes.sublist(0, 3));
      expect(first.hasMore, isTrue);
      final second = (await anonymous.request(
        request,
        page: const DwOffsetParams(3),
      )).okValue(request, testProtocol);
      expect(second.items, notes.sublist(3, 6));
      expect(second.hasMore, isTrue);
      final third = (await anonymous.request(
        request,
        page: const DwOffsetParams(6),
      )).okValue(request, testProtocol);
      expect(third.items, notes.sublist(6));
      expect(third.hasMore, isFalse);
    });

    test('an exactly full last page has no more', () async {
      final notes = await seed('exact', 3);
      const request = FeedNotes('exact-');
      final page = (await anonymous.request(
        request,
      )).okValue(request, testProtocol);
      expect(page.items, notes);
      expect(page.hasMore, isFalse);
    });

    test('cursor pages go back from the newest by id', () async {
      final notes = await seed('hist', 5);
      const request = NoteHistory('hist-');
      final newest = (await anonymous.request(
        request,
      )).okValue(request, testProtocol);
      expect(newest.items, [notes[4], notes[3]]);
      expect(newest.hasMore, isTrue);
      final older = (await anonymous.request(
        request,
        page: DwCursorParams(newest.items.last.id),
      )).okValue(request, testProtocol);
      expect(older.items, [notes[2], notes[1]]);
      final oldest = (await anonymous.request(
        request,
        page: DwCursorParams(older.items.last.id),
      )).okValue(request, testProtocol);
      expect(oldest.items, [notes[0]]);
      expect(oldest.hasMore, isFalse);
    });

    test('page parameters that do not fit the request fail', () async {
      final incidents = harness().app.alerts.incidents.length;
      final onList = await anonymous.request(
        const ListNotes(),
        page: const DwOffsetParams(0),
      );
      expect(onList.status, DwResultStatus.failed);
      final wrongKind = await anonymous.request(
        const FeedNotes('x'),
        page: const DwCursorParams(3),
      );
      expect(wrongKind.status, DwResultStatus.failed);
      final negative = await anonymous.request(
        const FeedNotes('x'),
        page: const DwOffsetParams(-1),
      );
      expect(negative.status, DwResultStatus.failed);
      await eventually(
        () => harness().app.alerts.incidents.length == incidents + 3,
      );
    });
  });

  group('failures', () {
    test('an exception answers an incident id and nothing else', () async {
      final result = await anonymous.request(const ExplodingRequest('hunter2'));
      expect(result.status, DwResultStatus.failed);
      expect(result.incidentId, isNotEmpty);
      final frame = anonymous.frames.last;
      expect(frame, isNot(contains('hunter2')));
      expect(jsonDecode(frame), {
        'k': 'res',
        'id': isA<int>(),
        's': 'failed',
        'x': result.incidentId,
      });
      await eventually(
        () => harness().app.alerts.incidents.any(
          (i) => i.id == result.incidentId,
        ),
      );
      final incident = harness().app.alerts.incidents.firstWhere(
        (i) => i.id == result.incidentId,
      );
      expect('${incident.error}', contains('hunter2'));
      expect(incident.where, 'request ExplodingRequest');
    });

    test('an unknown DTO type fails the call, not the connection', () async {
      final connection = await harness().connect();
      connection.sendRaw(
        jsonEncode({
          'k': 'req',
          'id': 77,
          'dto': {'@t': 'NoSuchRequest'},
        }),
      );
      final result = await connection.expect<DwResultMessage>();
      expect(result.id, 77);
      expect(result.status, DwResultStatus.failed);
      final next = await connection.request(const ListNotes(ownerId: -1));
      expect(next.status, DwResultStatus.ok);
      await connection.close();
    });

    test('a refusal does not alert', () async {
      final before = harness().app.alerts.incidents.length;
      await anonymous.request(const GetNote(-1));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(harness().app.alerts.incidents.length, before);
    });
  });

  group('connection protocol', () {
    test('malformed frames close with 4000', () async {
      for (final frame in ['not json', '[1]', '{"k":"what"}', '{"k":"req"}']) {
        final connection = await harness().connect();
        connection.sendRaw(frame);
        expect(
          await connection.closeCode,
          DwCloseCode.protocolError,
          reason: frame,
        );
      }
    });

    test('a binary frame closes with 1003', () async {
      final socket = await WebSocket.connect(
        harness().server.endpoint.toString(),
      );
      socket.add([1, 2, 3]);
      await socket.drain<void>();
      expect(socket.closeCode, DwCloseCode.unsupportedData);
    });

    test(
      'another or no wire version closes with 4001 and names ours',
      () async {
        for (final version in [2, null]) {
          final connection = await harness().server.connect(version: version);
          expect(await connection.closeCode, DwCloseCode.unsupportedVersion);
          expect(connection.closeReason, 'dw.wireVersion:$dwWireVersion');
        }
      },
    );

    test('a browser upgrade from a foreign origin is refused', () async {
      await expectLater(
        harness().server.connect(headers: {'Origin': 'https://evil.example'}),
        throwsA(isA<WebSocketException>()),
      );
      final same = await harness().server.connect(
        headers: {'Origin': 'http://127.0.0.1:1234'},
      );
      expect(
        (await same.request(const ListNotes(ownerId: -1))).status,
        DwResultStatus.ok,
      );
      await same.close();
    });

    test('authentication applies to the calls sent right after it', () async {
      final connection = await harness().connect();
      connection.send(DwAuthenticateMessage(session.token));
      connection.send(DwRequestMessage(id: 900, request: const MyNotes()));
      final result = await connection.expect<DwResultMessage>();
      expect(result.status, DwResultStatus.ok);
      await connection.close();
    });

    test('calls on one connection run concurrently', () async {
      final connection = await harness().connect();
      final watch = Stopwatch()..start();
      await Future.wait([
        for (var i = 0; i < 5; i++) connection.request(const SlowRequest(300)),
      ]);
      expect(watch.elapsedMilliseconds, lessThan(1200));
      await connection.close();
    });
  });

  group('context', () {
    DwCallContext context() => DwCallContext(
      db: harness().db,
      protocol: testProtocol,
      log: RecordingLogger(),
      jobs: (_) => _NoJobs(),
      accounts: (ctx) => throw UnimplementedError(),
      isPublishable: (item) => testProtocol.knows(item.runtimeType),
    );

    test('memo creates once per key per call', () {
      final ctx = context();
      var created = 0;
      expect(ctx.memo(#a, () => ++created), 1);
      expect(ctx.memo(#a, () => ++created), 1);
      expect(ctx.memo(#b, () => ++created), 2);
      expect(context().memo(#a, () => 'fresh'), 'fresh');
    });

    test('publish takes only registered data objects and deletions', () {
      final ctx = context();
      expect(
        () => ctx.publish(const DwChannel(TestChannel.notes), const Ping()),
        throwsArgumentError,
      );
      ctx.publish(
        const DwChannel(TestChannel.notes),
        const DwDeleted(typeName: 'NoteView', id: 1),
      );
      expect(ctx.rootEffects.publications, hasLength(1));
    });

    test('effects of a rolled-back transaction are dropped, of a committed '
        'savepoint kept', () async {
      final ctx = context();
      const channel = DwChannel(TestChannel.notes);
      await expectLater(
        ctx.transaction((tx) async {
          ctx.publish(channel, const NoteView(id: 1, text: 'gone'));
          throw StateError('rollback');
        }),
        throwsStateError,
      );
      expect(ctx.rootEffects.isEmpty, isTrue);
      await ctx.transaction((tx) async {
        expect(ctx.db, same(tx));
        await ctx.transaction((inner) async {
          expect(ctx.db, same(inner));
          ctx.publish(channel, const NoteView(id: 2, text: 'kept'));
        });
        await expectLater(
          ctx.transaction((inner) async {
            ctx.publish(channel, const NoteView(id: 3, text: 'savepoint gone'));
            throw StateError('savepoint rollback');
          }),
          throwsStateError,
        );
        expect(ctx.rootEffects.isEmpty, isTrue, reason: 'not committed yet');
      });
      expect(ctx.rootEffects.publications.map((p) => (p.$2 as NoteView).id), [
        2,
      ]);
      expect(ctx.db, same(harness().db));
    });
  });

  group('routes', () {
    final client = HttpClient();
    tearDownAll(client.close);

    Future<(int, String)> call(
      String method,
      String path, [
      String? body,
    ]) async {
      final request = await client.openUrl(
        method,
        harness().server.httpBase.resolve(path),
      );
      if (body != null) request.write(body);
      final response = await request.close();
      return (response.statusCode, await utf8.decodeStream(response));
    }

    test('health', () async {
      expect(await call('GET', '/health'), (200, 'ok'));
    });

    test('get and post with JSON, jobs through the route context', () async {
      expect(await call('GET', '/hello'), (200, '{"hello":"w"}'));
      final (status, body) = await call('POST', '/echo', '{"tag":"route"}');
      expect(status, 201);
      expect(jsonDecode(body), {'tag': 'route'});
      harness().server.wakeJobs();
      await eventually(() => harness().app.jobRuns.contains('record:route'));
    });

    test('a refusal answers 400 with the refusal, a failure 500 with the '
        'incident only', () async {
      final (refusedStatus, refusedBody) = await call('GET', '/refuse');
      expect(refusedStatus, 400);
      expect(jsonDecode(refusedBody), {
        'refusal': {'code': 'dw.forbidden'},
      });
      final (failedStatus, failedBody) = await call('GET', '/explode');
      expect(failedStatus, 500);
      expect(failedBody, isNot(contains('s3cr3t')));
      expect((jsonDecode(failedBody) as Map).keys, ['incident']);
    });

    test('unknown paths are 404', () async {
      expect((await call('GET', '/nope')).$1, 404);
    });
  });
}

final class _NoJobs implements DwJobs {
  @override
  Future<bool> enqueue(
    String name,
    Map<String, Object?> payload, {
    DateTime? runAt,
    String? key,
  }) => throw UnimplementedError();
}
