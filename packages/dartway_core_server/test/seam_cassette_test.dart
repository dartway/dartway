import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_core_server/src/process/dw_process_runner.dart'
    show DwSystemProcess;
import 'package:dartway_core_server/testing.dart';
import 'package:test/test.dart';

void main() {
  late Directory directory;
  setUp(() => directory = Directory('test').createTempSync('seams_'));
  tearDown(() => directory.deleteSync(recursive: true));
  DwSeamCassette cassette(
    String mode, {
    List<String> names = const [],
    List<String> values = const [],
  }) => DwSeamCassette(
    '${directory.path}/answers.json',
    redactNames: names,
    redactValues: values,
    environment: {if (mode.isNotEmpty) mode: '1'},
  );

  test(
    'records a real HTTP exchange, redacts both sides, replays offline',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final url = Uri.parse(
        'http://127.0.0.1:${server.port}/?token=query-secret',
      );
      server.listen((request) async {
        await request.drain<void>();
        request.response.statusCode = 201;
        request.response.headers.set('set-cookie', 'session=cookie-secret');
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'id': 7,
            'access_token': 'response-secret',
            'privateField': 'custom-secret',
            'echo': 'header-secret',
          }),
        );
        await request.response.close();
      });
      final record = cassette('DW_RECORD_SEAMS', names: ['privateField']);
      final http = DwFakeOutboundHttp()..useCassette(record);
      final response = await http.client().post(
        url,
        headers: {'Authorization': 'Bearer header-secret'},
        json: {'password': 'body-secret'},
      );
      expect(response.statusCode, 201);
      expect((response.json as Map)['id'], 7);
      await server.close(force: true);
      final stored = File('${directory.path}/answers.json').readAsStringSync();
      for (final secret in [
        'query-secret',
        'header-secret',
        'cookie-secret',
        'response-secret',
        'custom-secret',
        'body-secret',
      ]) {
        expect(stored, isNot(contains(secret)), reason: secret);
      }
      final replay = cassette('', names: ['privateField']);
      http.reset();
      http.useCassette(replay);
      final answer = await http.client().post(
        url,
        headers: {'authorization': 'Bearer header-secret'},
        json: {'password': 'another-password'},
      );
      expect(answer.statusCode, 201);
      expect(answer.json, containsPair('id', 7));
      replay.verifyComplete();
      await expectLater(
        http.client().get(url),
        throwsA(
          isA<StateError>().having(
            (e) => '$e',
            'request',
            allOf(contains('GET'), isNot(contains('query-secret'))),
          ),
        ),
      );
    },
  );

  test(
    'process recordings preserve ordered repeats and failure exit codes',
    () async {
      final script = File('${directory.path}/command.dart')
        ..writeAsStringSync(
          "import 'dart:io'; void main() { stdout.write('{\"id\":7}'); stderr.write('warning'); exitCode = 3; }",
        );
      final record = cassette('DW_RECORD_SEAMS');
      final fake = DwFakeProcessRunner()..useCassette(record);
      for (var i = 0; i < 2; i++) {
        final answer = await fake.client().run(Platform.resolvedExecutable, [
          script.path,
        ]);
        expect(answer.exitCode, 3);
        expect(answer.stdout, '{"id":7}');
        expect(answer.stderr, 'warning');
      }
      script.deleteSync();
      final replay = cassette('');
      fake.reset();
      fake.useCassette(replay);
      final answer = await fake.client().run(Platform.resolvedExecutable, [
        script.path,
      ]);
      expect(answer.exitCode, 3);
      expect(answer.stderr, 'warning');
      expect(replay.verifyComplete, throwsStateError);
      await fake.client().run(Platform.resolvedExecutable, [script.path]);
      replay.verifyComplete();
      await expectLater(
        fake.client().run(Platform.resolvedExecutable, [script.path]),
        throwsStateError,
      );
    },
  );

  test(
    'drift ignores values and array length but rejects keys, types and exit status',
    () async {
      final script = File('${directory.path}/command.dart');
      void write(String output, [int code = 0]) => script.writeAsStringSync(
        "import 'dart:io'; void main() { stdout.write('$output'); exitCode = $code; }",
      );
      final request = [script.path];
      write('{"items":[{"statusCode":1}]}');
      final record = DwFakeProcessRunner()
        ..useCassette(cassette('DW_RECORD_SEAMS'));
      await record.client().run(Platform.resolvedExecutable, request);
      for (final (output, code, drift) in [
        ('{"items":[{"statusCode":2},{"statusCode":3}]}', 0, false),
        ('{"items":[{"name":2}]}', 0, true),
        ('{"items":[{"statusCode":"2"}]}', 0, true),
        ('{"items":[{"statusCode":2}]}', 1, true),
      ]) {
        write(output, code);
        final verify = DwFakeProcessRunner()
          ..useCassette(cassette('DW_VERIFY_SEAMS'));
        final call = verify.client().run(Platform.resolvedExecutable, request);
        if (drift) {
          await expectLater(call, throwsStateError);
        } else {
          expect((await call).exitCode, 0);
        }
      }
      final replay = DwFakeProcessRunner()..useCassette(cassette(''));
      expect(
        (await replay.client().run(
          Platform.resolvedExecutable,
          request,
        )).stdout,
        '{"items":[{"statusCode":1}]}',
      );
    },
  );

  test(
    'HTTP drift detects status changes without replacing the cassette',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      var status = 200;
      var value = 1;
      server.listen((request) async {
        request.response.statusCode = status;
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({'id': value}));
        await request.response.close();
      });
      final url = Uri.parse('http://127.0.0.1:${server.port}/');
      final fake = DwFakeOutboundHttp()
        ..useCassette(cassette('DW_RECORD_SEAMS'));
      await fake.client().get(url);
      final before = File('${directory.path}/answers.json').readAsStringSync();
      value = 2;
      fake.useCassette(cassette('DW_VERIFY_SEAMS'));
      expect((await fake.client().get(url)).json, {'id': 2});
      status = 403;
      fake.useCassette(cassette('DW_VERIFY_SEAMS'));
      await expectLater(fake.client().get(url), throwsStateError);
      expect(File('${directory.path}/answers.json').readAsStringSync(), before);
    },
  );

  test(
    'redacts form fields, explicit positional values and command flag names',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        await request.drain<void>();
        await request.response.close();
      });
      final recorded = cassette(
        'DW_RECORD_SEAMS',
        names: ['privateField'],
        values: ['positional-secret'],
      );
      final http = DwFakeOutboundHttp()..useCassette(recorded);
      await http.client().post(
        Uri.parse('http://127.0.0.1:${server.port}/'),
        body: {'password': 'form-secret'},
      );
      final script = File('${directory.path}/command.dart')
        ..writeAsStringSync('void main(List<String> args) { print(args); }');
      final process = DwFakeProcessRunner()..useCassette(recorded);
      await process.client().run(
        Platform.resolvedExecutable,
        [
          script.path,
          '--privateField',
          'flag-secret',
          '--token=token-secret',
          'positional-secret',
        ],
        environment: {'API_KEY': 'env-secret'},
      );
      final stored = File('${directory.path}/answers.json').readAsStringSync();
      for (final secret in [
        'form-secret',
        'flag-secret',
        'token-secret',
        'positional-secret',
        'env-secret',
      ]) {
        expect(stored, isNot(contains(secret)), reason: secret);
      }
    },
  );

  test(
    'binary secrets are redacted without interpreting application JSON as an encoding',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        if (request.uri.path == '/json') {
          request.response.headers.contentType = ContentType.json;
          request.response.write('{"base64":"application-value"}');
        } else {
          request.response.add([255, ...utf8.encode('binary-secret'), 0]);
        }
        await request.response.close();
      });
      final url = Uri.parse('http://127.0.0.1:${server.port}/');
      final fake = DwFakeOutboundHttp()
        ..useCassette(cassette('DW_RECORD_SEAMS', values: ['binary-secret']));
      await fake.client().get(url.resolve('/json'));
      await fake.client().get(url.resolve('/binary'));
      await server.close(force: true);
      final replay = cassette('', values: ['binary-secret']);
      fake.useCassette(replay);
      expect((await fake.client().get(url.resolve('/json'))).json, {
        'base64': 'application-value',
      });
      final bytes = (await fake.client().get(url.resolve('/binary'))).bodyBytes;
      expect(bytes.first, 255);
      expect(latin1.decode(bytes), isNot(contains('binary-secret')));
      expect(latin1.decode(bytes), contains('[REDACTED]'));
      replay.verifyComplete();
    },
  );

  test('commands are offline unless explicitly scripted', () async {
    final fake = DwFakeProcessRunner();
    await expectLater(
      fake.client().run('missing-command', []),
      throwsStateError,
    );
    fake.when((_) => true, (_) => const DwProcessResult(4, '', 'edge case'));
    expect((await fake.client().run('missing-command', [])).exitCode, 4);
    fake.when((_) => true, (_) => Completer<DwProcessResult>().future);
    await expectLater(
      fake.client().run(
        'missing-command',
        [],
        timeout: const Duration(milliseconds: 1),
      ),
      throwsA(isA<DwProcessException>()),
    );
  });

  test('real commands are bounded by time and combined output', () async {
    const process = DwProcessRunner(DwSystemProcess());
    final script = File('${directory.path}/command.dart')
      ..writeAsStringSync(
        "import 'dart:async'; void main() { Timer(const Duration(seconds: 60), () {}); }",
      );
    await expectLater(
      process.run(Platform.resolvedExecutable, [
        script.path,
      ], timeout: const Duration(milliseconds: 500)),
      throwsA(
        isA<DwProcessException>().having(
          (e) => e.reason,
          'reason',
          contains('timed out'),
        ),
      ),
    );
    script.writeAsStringSync(
      "import 'dart:io'; void main() { stdout.write('x' * 2000); stderr.write('y' * 2000); }",
    );
    await expectLater(
      process.run(Platform.resolvedExecutable, [
        script.path,
      ], maxOutputBytes: 100),
      throwsA(
        isA<DwProcessException>().having(
          (e) => e.reason,
          'reason',
          contains('output limit'),
        ),
      ),
    );
    await expectLater(
      process.run('dw-command-does-not-exist', []),
      throwsA(isA<DwProcessException>()),
    );
  });
}
