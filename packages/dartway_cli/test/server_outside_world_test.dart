import 'dart:io';

import 'package:dartway_cli/src/checker/dw_check_tally.dart';
import 'package:dartway_cli/src/checker/dw_check_type.dart';
import 'package:dartway_cli/src/checker/dw_server_outside_world.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// The server reads its environment in `core/environment.dart` and sends
/// outbound requests through `ctx.http` (#386).
void main() {
  group('reads of the environment', () {
    test('are found, qualified or not, each on its own line', () {
      expect(
        DwServerOutsideWorldInspector.environmentReadsIn(r'''
final a = Platform.environment['A'];
final b = io.Platform.environment;
final c = Platform
    .environment['C'];
final d = 'at ${Platform.environment['HOME']}';
'''),
        [1, 2, 3, 5],
      );
    });

    test('in comments and strings are not', () {
      expect(
        DwServerOutsideWorldInspector.environmentReadsIn(r'''
// Platform.environment is read in core/environment.dart
/* Platform.environment */
/// Not `Platform.environment`: `AppEnvironment`.
final text = 'Platform.environment';
final raw = r'${Platform.environment}';
final env = AppEnvironment.read(variables);
'''),
        isEmpty,
      );
    });
  });

  group('HTTP clients of their own', () {
    test('are a constructed HttpClient and an import of package:http', () {
      expect(
        DwServerOutsideWorldInspector.httpClientsIn('''
import 'dart:io';
import 'package:http/http.dart' as http;

final a = HttpClient();
final b = HttpClient()..connectionTimeout = timeout;
final HttpClient Function() c = HttpClient.new;
'''),
        [2, 4, 5, 6],
      );
    });

    test('are not a type named, a comment or ctx.http', () {
      expect(
        DwServerOutsideWorldInspector.httpClientsIn('''
// import 'package:http/http.dart';
/// Not an `HttpClient()`: `ctx.http`.
final text = 'HttpClient()';
Future<void> send(HttpClientRequest request, HttpClient client) async {}
final response = await ctx.http.post(url, json: body);
'''),
        isEmpty,
      );
    });
  });

  group('over a server package', () {
    late Directory root;
    late Directory server;

    setUp(() {
      root = Directory.systemTemp.createTempSync('dw_outside_world');
      server = Directory(p.join(root.path, 'shop_server'));
    });
    tearDown(() => root.deleteSync(recursive: true));

    void write(String path, String content) => File(p.join(server.path, path))
      ..createSync(recursive: true)
      ..writeAsStringSync(content);

    test('fails on lib/ and lib/src/, names each file and line, and leaves '
        'core/environment.dart, bin/ and test/ alone', () {
      write('lib/src/core/environment.dart', '''
final home = Platform.environment['HOME'];
''');
      write('lib/src/sms/sms_handlers.dart', '''
import 'package:http/http.dart' as http;

final token = Platform.environment['SMS_TOKEN'];
''');
      write('lib/shop_server.dart', '''
final port = Platform.environment['PORT'];
final client = HttpClient();
''');
      write('bin/server.dart', '''
final env = Platform.environment;
final client = HttpClient();
''');
      write('test/sms_test.dart', "import 'package:http/http.dart';\n");

      final tally = DwCheckTally();
      final inspector = DwServerOutsideWorldInspector(serverPackageDir: server);
      expect(inspector.run(tally: tally), 3);
      final findings = inspector.findings;
      expect(
        findings
            .where((f) => f.$1 == DwCheckType.forbiddenEnvironmentRead)
            .map((f) => f.$2),
        [
          contains(p.join('shop_server', 'lib', 'shop_server.dart:1;')),
          contains(
            p.join('shop_server', 'lib', 'src', 'sms', 'sms_handlers.dart:3;'),
          ),
        ],
      );
      expect(
        findings
            .where((f) => f.$1 == DwCheckType.forbiddenHttpClient)
            .map((f) => f.$2),
        [
          contains(
            p.join('shop_server', 'lib', 'src', 'sms', 'sms_handlers.dart:1;'),
          ),
        ],
        reason: 'the package library is not lib/src/',
      );
      expect(tally.counts, {
        DwCheckType.forbiddenEnvironmentRead: 2,
        DwCheckType.forbiddenHttpClient: 1,
      });
    });

    test('passes a server that reads AppEnvironment and sends through '
        'ctx.http', () {
      write('lib/src/core/environment.dart', '''
static AppEnvironment read(Map<String, String> variables) =>
    DwEnvironmentReader.read(variables, (read) => AppEnvironment(
      server: DwServerEnvironment.read(read),
    ));
''');
      write('lib/src/sms/sms_handlers.dart', '''
Future<void> send(DwCallContext ctx, AppSmsEnvironment sms) =>
    ctx.http.post(sms.endpoint, body: {'login': sms.login});
''');
      final inspector = DwServerOutsideWorldInspector(serverPackageDir: server);
      expect(inspector.run(), 0);
      expect(inspector.findings, isEmpty);
    });

    test('are errors, and run only when asked for or unfiltered', () {
      expect(
        DwCheckType.forbiddenEnvironmentRead.severity,
        DwCheckSeverity.error,
      );
      expect(DwCheckType.forbiddenHttpClient.severity, DwCheckSeverity.error);
      write('lib/src/a/a_handlers.dart', '''
final a = Platform.environment['A'];
final b = HttpClient();
''');
      int run({DwCheckType? type, DwCheckSeverity? level}) =>
          DwServerOutsideWorldInspector(
            serverPackageDir: server,
            filterType: type,
            filterSeverity: level,
          ).run();
      expect(run(type: DwCheckType.fileLong), 0);
      expect(run(level: DwCheckSeverity.warning), 0);
      expect(run(type: DwCheckType.forbiddenHttpClient), 1);
      expect(run(type: DwCheckType.forbiddenEnvironmentRead), 1);
      expect(run(), 2);
    });
  });
}
