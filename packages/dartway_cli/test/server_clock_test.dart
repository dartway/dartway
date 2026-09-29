import 'dart:io';

import 'package:dartway_cli/src/checker/dw_check_tally.dart';
import 'package:dartway_cli/src/checker/dw_check_type.dart';
import 'package:dartway_cli/src/checker/dw_server_clock_use.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// The server reads the time from its clock, `ctx.now` (#385): the system
/// clock in a server's `lib/src/` is a time no test can set.
void main() {
  group('reads of the system clock', () {
    test('are found called and torn off, each on its own line', () {
      expect(
        DwServerClockInspector.readsIn('''
final a = DateTime.now();
final b = DateTime.now().toUtc();
final c = DateTime.timestamp();
final DateTime Function() d = DateTime.now;
final e = DateTime
    .now();
'''),
        [
          (1, 'DateTime.now'),
          (2, 'DateTime.now'),
          (3, 'DateTime.timestamp'),
          (4, 'DateTime.now'),
          (5, 'DateTime.now'),
        ],
      );
    });

    test('inside an interpolation are code', () {
      expect(
        DwServerClockInspector.readsIn(r'''
final text = 'at ${DateTime.now()}';
'''),
        [(1, 'DateTime.now')],
      );
    });

    test('in comments and strings are not', () {
      expect(
        DwServerClockInspector.readsIn(r'''
// DateTime.now() is refused here
/* DateTime.now() */
/// Not `DateTime.now()`: `ctx.now`.
final text = 'DateTime.now()';
final raw = r'${DateTime.now()}';
final now = ctx.now;
final later = DateTime.nowadays;
'''),
        isEmpty,
      );
    });

    test('through package:clock count only where it is imported', () {
      const body = '''
final a = clock.now();
final b = session.clock.now();
''';
      expect(DwServerClockInspector.readsIn(body), isEmpty);
      expect(
        DwServerClockInspector.readsIn(
          "import 'package:clock/clock.dart';\n$body",
        ),
        [(2, 'clock.now')],
      );
    });
  });

  test('through a prefixed package:clock import count too', () {
    expect(
      DwServerClockInspector.readsIn('''
import 'package:clock/clock.dart' as c;

final a = c.clock.now();
final b = c . clock.now();
final d = clock.now();
'''),
      [(3, 'c.clock.now'), (4, 'c.clock.now')],
      reason: 'unprefixed `clock` is not that package here',
    );
  });

  group('over a server package', () {
    late Directory root;
    late Directory server;

    setUp(() {
      root = Directory.systemTemp.createTempSync('dw_server_clock');
      server = Directory(p.join(root.path, 'shop_server'));
    });
    tearDown(() => root.deleteSync(recursive: true));

    void write(String path, String content) => File(p.join(server.path, path))
      ..createSync(recursive: true)
      ..writeAsStringSync(content);

    test("fails on lib/ and names each file and line; bin/ and test/ "
        'decide their own time', () {
      write('lib/src/billing/billing_handlers.dart', '''
Future<void> pay(DwCallContext ctx) async {
  final paidAt = DateTime.now().toUtc();
}
''');
      write('lib/src/billing/billing_jobs.dart', '''
final due = ctx.now.add(const Duration(days: 1));
''');
      write('bin/seed_dev.dart', 'final today = DateTime.now();\n');
      write('test/billing_test.dart', 'final today = DateTime.now();\n');

      final tally = DwCheckTally();
      final inspector = DwServerClockInspector(serverPackageDir: server);
      expect(inspector.run(tally: tally), 1);
      expect(inspector.findings.single, contains('DateTime.now'));
      expect(
        inspector.findings.single,
        contains(
          p.join(
            'shop_server',
            'lib',
            'src',
            'billing',
            'billing_handlers.dart',
          ),
        ),
      );
      expect(inspector.findings.single, contains(':2;'));
      expect(tally.counts, {DwCheckType.forbiddenDateTimeNow: 1});
    });

    test('judges all of lib/, the factory file beside src/ included', () {
      write('lib/shop_server.dart', '''
DwAppServer build() => DwAppServer(startedAt: DateTime.now());
''');
      write('lib/src/billing/billing_handlers.dart', 'final a = ctx.now;\n');
      final inspector = DwServerClockInspector(serverPackageDir: server);
      expect(inspector.run(), 1);
      expect(
        inspector.findings.single,
        contains('${p.join('shop_server', 'lib', 'shop_server.dart')}:1;'),
      );
    });

    test('passes a server that reads ctx.now', () {
      write('lib/src/billing/billing_handlers.dart', '''
Future<void> pay(DwCallContext ctx) async {
  final paidAt = ctx.now;
}
''');
      final inspector = DwServerClockInspector(serverPackageDir: server);
      expect(inspector.run(), 0);
      expect(inspector.findings, isEmpty);
    });

    test('is an error, and runs only when asked for or unfiltered', () {
      expect(DwCheckType.forbiddenDateTimeNow.severity, DwCheckSeverity.error);
      write('lib/src/a.dart', 'final a = DateTime.now();\n');
      expect(
        DwServerClockInspector(
          serverPackageDir: server,
          filterType: DwCheckType.fileLong,
        ).run(),
        0,
      );
      expect(
        DwServerClockInspector(
          serverPackageDir: server,
          filterSeverity: DwCheckSeverity.warning,
        ).run(),
        0,
      );
    });
  });
}
