import 'dart:convert';
import 'dart:io';

import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:test/test.dart';

import 'support/test_app.dart';

/// Project routes: external doors on the same port, over the framework's own
/// HTTP types.
void main() {
  final harness = useHarness(
    build: (app, config) => app.server(
      config,
      routes: [
        DwHttpRoute.get(
          '/hello',
          (ctx, request) => DwHttpResponse.json({
            'hello': request.query['name'] ?? 'world',
            'agent': request.headers['x-agent'],
          }),
        ),
        DwHttpRoute.post('/echo', (ctx, request) async {
          final body = await request.json() as Map<String, Object?>;
          await ctx.jobs.enqueue(TestApp.tagged('record'), body['tag']);
          return DwHttpResponse.json(body, status: 201);
        }),
        DwHttpRoute.post('/limited', (ctx, request) async {
          final bytes = await request.bytes(maxBytes: 8);
          return DwHttpResponse.text('${bytes.length}');
        }),
        DwHttpRoute.any(
          '/any',
          (ctx, request) => DwHttpResponse.text(request.method),
        ),
        DwHttpRoute.post(
          '/any',
          (ctx, request) => DwHttpResponse.text('specific'),
        ),
        DwHttpRoute.get('/unread', (ctx, request) => DwHttpResponse.empty()),
        DwHttpRoute.get('/unusual', (ctx, request) => DwHttpResponse(299)),
        DwHttpRoute.post('/publish', (ctx, request) async {
          final note = await TestApp.insertNote(ctx.db, 'from a route');
          ctx.publish(const DwLiveChannel(TestChannel.public), note);
          return DwHttpResponse.empty(status: 202);
        }),
        DwHttpRoute.get(
          '/refuse',
          (ctx, request) => ctx.refuse(DwCoreRefusal.forbidden),
        ),
        DwHttpRoute.get(
          '/slow-down',
          (ctx, request) => throw DwRefusalException(
            DwCallRefusal.tooManyRequests(const Duration(seconds: 7)),
          ),
        ),
        DwHttpRoute.get(
          '/account',
          (ctx, request) => DwHttpResponse.text('${ctx.requireAccountId}'),
        ),
        DwHttpRoute.get(
          '/explode',
          (ctx, request) => throw StateError('route secret s3cr3t'),
        ),
      ],
    ),
  );

  late DwTestCaller caller;
  setUpAll(() => caller = harness().caller());

  test('a GET route reads the query and headers and answers JSON', () async {
    final answer = await caller.raw(
      'GET',
      '/hello',
      query: {'name': 'dw'},
      headers: {'X-Agent': 'test'},
    );
    expect(answer.status, 200);
    expect(answer.headers.contentType?.mimeType, 'application/json');
    expect(answer.json, {'hello': 'dw', 'agent': 'test'});
  });

  test(
    'a POST route reads a JSON body and enqueues through its context',
    () async {
      final answer = await caller.raw(
        'POST',
        '/echo',
        body: utf8.encode('{"tag":"route"}'),
      );
      expect(answer.status, 201);
      expect(answer.json, {'tag': 'route'});
      harness().server.wakeJobs();
      await eventually(() => harness().app.jobRuns.contains('record:route'));
    },
  );

  test('a body over the limit the route reads with is 413; a body that is '
      'not JSON is 400', () async {
    final small = await caller.raw('POST', '/limited', body: [1, 2, 3]);
    expect((small.status, small.text), (200, '3'));
    final large = await caller.raw('POST', '/limited', body: List.filled(9, 1));
    expect(large.status, 413);
    expect(large.reasonPhrase, 'Content Too Large');
    final notJson = await caller.raw('POST', '/echo', body: utf8.encode('{'));
    expect(notJson.status, 400);
  });

  test('a status line carries the standard reason phrase; a status without '
      'one keeps the default of dart:io', () async {
    final unusual = await caller.raw('GET', '/unusual');
    expect((unusual.status, unusual.reasonPhrase), (299, 'Status 299'));
    final slow = await caller.raw('GET', '/slow-down');
    expect((slow.status, slow.reasonPhrase), (429, 'Too Many Requests'));
  });

  test('a body the route never reads does not break the connection', () async {
    for (var i = 0; i < 3; i++) {
      final answer = await caller.raw(
        'GET',
        '/unread',
        body: List.filled(64 << 10, 7),
      );
      expect(answer.status, 204);
    }
  });

  test(
    'an any-method route serves every method; a specific one wins',
    () async {
      expect((await caller.raw('PUT', '/any')).text, 'PUT');
      expect((await caller.raw('GET', '/any')).text, 'GET');
      expect((await caller.raw('POST', '/any')).text, 'specific');
    },
  );

  test('another method on a known path is 405 with Allow; an unknown path '
      'is 404', () async {
    final wrong = await caller.raw('DELETE', '/echo');
    expect(wrong.status, 405);
    expect(wrong.headers.value('allow'), 'POST');
    expect((await caller.raw('GET', '/nope')).status, 404);
    expect((await caller.raw('GET', '/dw')).status, 404);
  });

  test('what a route publishes is delivered when it answers', () async {
    final (_, session) = await harness().signedIn('route-l@example.com');
    final live = await harness().live(token: session.token);
    expect(await live.subscribe('public'), isA<DwSubscribedMessage>());
    expect((await caller.raw('POST', '/publish')).status, 202);
    final update = await live.expect<DwUpdateMessage>();
    expect((update.updates.objects.single as NoteView).text, 'from a route');
  });

  test('a refusal answers its call status with the refusal, a failure 500 '
      'with the incident only', () async {
    final refused = await caller.raw('GET', '/refuse');
    expect(refused.status, 403);
    expect(refused.json, {
      'refusal': {'code': 'dw.forbidden'},
    });
    final slow = await caller.raw('GET', '/slow-down');
    expect(slow.status, 429);
    expect(slow.headers.value('retry-after'), '7');
    expect((await caller.raw('GET', '/account')).status, 401);
    final failed = await caller.raw('GET', '/explode');
    expect(failed.status, 500);
    expect(failed.text, isNot(contains('s3cr3t')));
    final incident = (failed.json! as Map)['incident'];
    await eventually(
      () => harness().app.alerts.incidents.any(
        (i) => i.id == incident && i.where == 'route GET /explode',
      ),
    );
  });

  test(
    'routes are plain HTTP: no call headers are needed or checked',
    () async {
      final client = HttpClient();
      addTearDown(client.close);
      final request = await client.getUrl(
        harness().server.httpBase.resolve('/hello'),
      );
      final response = await request.close();
      expect(response.statusCode, 200);
      await response.drain<void>();
    },
  );
}
