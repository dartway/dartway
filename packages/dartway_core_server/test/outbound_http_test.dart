import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_core_server/src/outbound/dw_outbound_http.dart'
    show DwNetworkTransport;
import 'package:test/test.dart';

import 'support/test_app.dart';

/// `ctx.http`: requests to other services, bounded, logged, and answered by
/// a fake in tests. The network half runs against a loopback server of its
/// own; the last group runs a real server on a database.
void main() {
  group('over the network', () {
    late HttpServer remote;
    late DwNetworkTransport transport;
    late RecordingLogger log;
    late DwOutboundHttp http;
    final received =
        <({String method, String path, String body, HttpHeaders headers})>[];

    setUp(() async {
      received.clear();
      remote = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      remote.listen((request) async {
        final body = await utf8.decodeStream(request);
        received.add((
          method: request.method,
          path: request.uri.toString(),
          body: body,
          headers: request.headers,
        ));
        final response = request.response;
        switch (request.uri.path) {
          case '/slow':
            await Future<void>.delayed(const Duration(seconds: 2));
            response.write('late');
          case '/missing':
            response.statusCode = 404;
            response.write('no such thing');
          case '/moved':
            response.statusCode = 302;
            response.headers.set('location', '/json');
          case '/json':
            response.headers.contentType = ContentType.json;
            response.write(jsonEncode({'ok': true}));
          default:
            response.write('echo $body');
        }
        await response.close();
      });
      transport = DwNetworkTransport(
        connectionTimeout: const Duration(seconds: 5),
      );
      log = RecordingLogger('call');
      http = DwOutboundHttp(
        transport,
        log: log,
        timeout: const Duration(seconds: 5),
      );
      RecordingLogger.lines.clear();
    });

    tearDown(() async {
      transport.close();
      await remote.close(force: true);
    });

    Uri at(String path) => Uri.parse('http://127.0.0.1:${remote.port}$path');

    test('sends JSON and reads JSON back', () async {
      final response = await http.post(at('/json'), json: {'phone': '7999'});
      expect(response.isSuccess, isTrue);
      expect(response.json, {'ok': true});
      expect(received.single.method, 'POST');
      expect(jsonDecode(received.single.body), {'phone': '7999'});
      expect(received.single.headers.contentType?.mimeType, 'application/json');
    });

    test('sends a form, text and bytes', () async {
      await http.post(at('/'), body: {'login': 'shop', 'mes': 'a b&c'});
      await http.put(at('/'), body: 'plain');
      await http.patch(
        at('/'),
        body: utf8.encode('raw'),
        headers: {'Content-Type': 'application/octet-stream'},
      );
      expect(received[0].body, 'login=shop&mes=a+b%26c');
      expect(
        received[0].headers.contentType?.mimeType,
        'application/x-www-form-urlencoded',
      );
      expect(received[1].body, 'plain');
      expect(received[1].headers.contentType?.mimeType, 'text/plain');
      expect(received[2].body, 'raw');
      expect(
        received[2].headers.contentType?.mimeType,
        'application/octet-stream',
      );
    });

    test('refuses a body and json together', () {
      expect(
        () => http.post(at('/'), body: 'a', json: {'b': 1}),
        throwsArgumentError,
      );
    });

    test('answers any status rather than throwing', () async {
      final response = await http.get(at('/missing'));
      expect(response.statusCode, 404);
      expect(response.isSuccess, isFalse);
      expect(response.body, 'no such thing');
    });

    test('follows a redirect unless told not to', () async {
      expect((await http.get(at('/moved'))).statusCode, 200);
      final kept = await http.get(at('/moved'), followRedirects: false);
      expect(kept.statusCode, 302);
      expect(kept.headers['location'], '/json');
    });

    test('bounds the whole exchange by its timeout', () async {
      final watch = Stopwatch()..start();
      await expectLater(
        http.get(at('/slow'), timeout: const Duration(milliseconds: 200)),
        throwsA(
          isA<DwOutboundException>()
              .having((e) => e.timedOut, 'timedOut', isTrue)
              .having(
                (e) => e.timedOutAfter,
                'timedOutAfter',
                const Duration(milliseconds: 200),
              ),
        ),
      );
      expect(watch.elapsed, lessThan(const Duration(seconds: 2)));
    });

    test('throws DwOutboundException when nothing answers', () async {
      final port = remote.port;
      await remote.close(force: true);
      await expectLater(
        http.get(Uri.parse('http://127.0.0.1:$port/')),
        throwsA(
          isA<DwOutboundException>().having(
            (e) => e.timedOut,
            'timedOut',
            isFalse,
          ),
        ),
      );
    });

    test('logs the method, the origin, the status and the time — never the '
        'path, the query or a header', () async {
      await http.get(
        at('/bot123:SECRET/sendMessage?psw=hunter2'),
        headers: {'authorization': 'Bearer t0ken'},
      );
      await expectLater(
        http.get(
          at('/slow?psw=hunter2'),
          timeout: const Duration(milliseconds: 100),
        ),
        throwsA(isA<DwOutboundException>()),
      );
      final lines = RecordingLogger.lines.join('\n');
      expect(
        RecordingLogger.lines.first,
        matches(
          RegExp(
            r'^info call outbound GET http://127\.0\.0\.1:\d+ → 200 in \d+ ms$',
          ),
        ),
      );
      expect(
        RecordingLogger.lines.last,
        matches(
          RegExp(
            r'^warning call outbound GET .* failed after \d+ ms: timed out',
          ),
        ),
      );
      expect(lines, isNot(contains('SECRET')));
      expect(lines, isNot(contains('hunter2')));
      expect(lines, isNot(contains('t0ken')));
    });
  });

  group('DwFakeOutboundHttp', () {
    late DwFakeOutboundHttp fake;
    late DwOutboundHttp http;

    setUp(() {
      fake = DwFakeOutboundHttp();
      http = DwOutboundHttp(
        fake,
        log: RecordingLogger(),
        timeout: const Duration(milliseconds: 200),
      );
    });

    test('records every request and answers from its rules', () async {
      fake.when(
        (request) => request.url.host == 'sms.example.com',
        (request) => DwOutboundResponse(200, json: {'id': 7}),
      );
      final response = await http.post(
        Uri.parse('https://sms.example.com/send'),
        headers: {'X-Login': 'shop'},
        body: {'phones': '79990000001'},
      );
      expect(response.json, {'id': 7});
      expect(response.headers['content-type'], startsWith('application/json'));
      final request = fake.requests.single;
      expect(request.method, 'POST');
      expect(request.headers['x-login'], 'shop');
      expect(request.form, {'phones': '79990000001'});
    });

    test('asks the rule added last first', () async {
      fake
        ..when((_) => true, (_) => DwOutboundResponse(200, body: 'harness'))
        ..when(
          (request) => request.url.path == '/down',
          (_) => DwOutboundResponse(503),
        );
      expect(
        (await http.get(Uri.parse('https://api.example.com/down'))).statusCode,
        503,
      );
      expect(
        (await http.get(Uri.parse('https://api.example.com/up'))).body,
        'harness',
      );
    });

    test('refuses a request no rule answers, and records it', () async {
      await expectLater(
        http.get(Uri.parse('https://api.example.com/x')),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('GET https://api.example.com/x'),
          ),
        ),
      );
      expect(fake.requests, hasLength(1));
    });

    test('lets a rule fail the exchange, or run into the timeout', () async {
      fake
        ..when(
          (request) => request.url.path == '/unreachable',
          (request) => throw DwOutboundException(request, cause: 'refused'),
        )
        ..when(
          (request) => request.url.path == '/hang',
          (_) => Completer<DwOutboundResponse>().future,
        );
      await expectLater(
        http.get(Uri.parse('https://api.example.com/unreachable')),
        throwsA(isA<DwOutboundException>()),
      );
      await expectLater(
        http.get(Uri.parse('https://api.example.com/hang')),
        throwsA(
          isA<DwOutboundException>().having(
            (e) => e.timedOut,
            'timedOut',
            isTrue,
          ),
        ),
      );
    });

    test('forgets everything on reset', () async {
      fake.when((_) => true, (_) => DwOutboundResponse(200));
      await http.get(Uri.parse('https://api.example.com/'));
      fake.reset();
      expect(fake.requests, isEmpty);
      await expectLater(
        http.get(Uri.parse('https://api.example.com/')),
        throwsStateError,
      );
    });
  });

  group('in a server', () {
    final harness = useHarness(
      build: (app, config) => app.server(
        config,
        routes: [
          DwHttpRoute.post('/notify', (ctx, request) async {
            final response = await ctx.http.post(
              Uri.parse('https://hooks.example.com/notify'),
              json: {'text': await request.text()},
            );
            return DwHttpResponse.text('${response.statusCode}');
          }),
        ],
      ),
    );

    test("ctx.http is answered by the test server's fake", () async {
      final server = harness().server;
      server.http.when(
        (request) => request.url.host == 'hooks.example.com',
        (request) => DwOutboundResponse(202),
      );
      final answer = await harness().caller().raw(
        'POST',
        '/notify',
        body: utf8.encode('hello'),
      );
      expect(answer.status, 200);
      expect(answer.text, '202');
      expect(server.http.requests.single.json, {'text': 'hello'});
    });

    test('an unscripted request fails the call, not the network', () async {
      final server = harness().server..http.reset();
      final answer = await harness().caller().raw(
        'POST',
        '/notify',
        body: utf8.encode('hello'),
      );
      expect(answer.status, 500);
      expect(server.http.requests, hasLength(1));
    });
  });
}
