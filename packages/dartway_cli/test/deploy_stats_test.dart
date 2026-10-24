import 'dart:convert';

import 'package:args/command_runner.dart';
import 'package:dartway_cli/src/commands/deploy_command.dart';
import 'package:dartway_cli/src/deploy/deploy_stats.dart';
import 'package:dartway_cli/src/deploy/ssh_runner.dart';
import 'package:test/test.dart';

import 'support/deploy_fixtures.dart';

/// One line of the proxy's log in the rendered format, as nginx writes it.
String _logged({
  required String call,
  required double seconds,
  int status = 200,
  String uri = '/dw/x',
}) =>
    '{"time":"2026-10-21T10:00:00+00:00","host":"api.example.com",'
    '"method":"POST","uri":"$uri","call":"$call","status":$status,'
    '"request_time":${seconds.toStringAsFixed(3)},"upstream_time":"0.001",'
    '"bytes":12}';

void main() {
  group('the percentiles, computed on the server', () {
    Future<List<String>> pipe(List<String> log) async {
      final result = await LocalShell().run(
        "printf '%s\\n' ${log.map((line) => "'$line'").join(' ')} | "
        '${DwDeployStats.extractScript} | ${DwDeployStats.percentileScript}',
      );
      expect(result.ok, isTrue, reason: result.stderr);
      return const LineSplitter().convert(result.stdout);
    }

    test('nearest rank per call, the slowest time and the 5xx', () async {
      final rows = await pipe([
        // GetProfile: 1..20 ms, shuffled; two of them failed.
        for (final ms in [7, 3, 20, 1, 14, 9, 2, 18, 5, 11, 4, 16, 8, 13])
          _logged(call: 'GetProfile', seconds: ms / 1000),
        for (final ms in [6, 10, 12, 15, 17, 19])
          _logged(call: 'GetProfile', seconds: ms / 1000, status: 503),
        _logged(call: 'SaveProfile', seconds: 0.25, status: 422),
      ]);
      expect(rows, [
        'GetProfile\t20\t0.010\t0.019\t0.020\t6',
        'SaveProfile\t1\t0.250\t0.250\t0.250\t0',
      ]);
    });

    test('what is not a call is not counted', () async {
      final rows = await pipe([
        _logged(call: '', seconds: 3600, uri: '/dw/live'),
        _logged(call: '', seconds: 0.001, uri: '/main.dart.js'),
        '2026/10/21 10:00:00 [error] 22#22: *1 connect() failed',
        '/docker-entrypoint.sh: Configuration complete; ready for start up',
        _logged(call: 'GetProfile', seconds: 0.004),
      ]);
      expect(rows, ['GetProfile\t1\t0.004\t0.004\t0.004\t0']);
    });
  });

  group('the report', () {
    const answer =
        '--dw-stats-calls--\n'
        'GetProfile\t1200\t0.012\t0.048\t0.310\t0\n'
        'ListPosts\t300\t0.040\t0.900\t2.500\t3\n'
        '--dw-stats-slow--\n'
        '4\n'
        '--dw-stats-statements--\n'
        'since\t2026-10-20 09:00:00.1+00\n'
        '1500\t9000.5\t6.0\t1500\tSELECT * FROM post WHERE author_id = \$1\n'
        '80\t120.0\t1.5\t80\tSELECT 1\n';

    test('slowest p95 first, statements by total time', () {
      final report = DwDeployStats.parse(answer);
      expect(report.calls.map((row) => row.call), ['ListPosts', 'GetProfile']);
      expect(report.calls.first.p95, 0.9);
      expect(report.calls.first.serverErrors, 3);
      expect(report.slowStatements, 4);
      expect(report.statementsSince, '2026-10-20 09:00:00.1+00');
      expect(report.statements!.first.query, startsWith('SELECT * FROM post'));
      expect(report.statements!.first.totalMs, 9000.5);
    });

    test('an extension that is not there is said, not a table', () {
      final report = DwDeployStats.parse(
        '--dw-stats-calls--\n'
        '--dw-stats-slow--\n0\n'
        '--dw-stats-statements--\n'
        'psql:<stdin>:1: ERROR:  relation "pg_stat_statements_info" does not '
        'exist\n',
      );
      expect(report.statements, isNull);
      expect(
        report.statementsProblem,
        'ERROR:  relation "pg_stat_statements_info" does not exist',
      );
    });

    test('a stopped database is a problem, not "none counted"', () {
      final report = DwDeployStats.parse(
        '--dw-stats-calls--\n--dw-stats-slow--\n0\n'
        '--dw-stats-statements--\n'
        'service "postgres" is not running\n',
      );
      expect(report.statements, isNull);
      expect(report.statementsProblem, 'service "postgres" is not running');
    });
  });

  group('dartway deploy stats', () {
    Future<(String, List<String>)> run(
      List<String> arguments, {
      String extra = '',
      String answer = '',
    }) async {
      final ssh = RecordingSsh([
        (
          '--dw-stats-calls--',
          DwSshResult(exitCode: 0, stdout: answer, stderr: ''),
        ),
      ]);
      final out = StringBuffer();
      final runner = CommandRunner<int>('dartway', '')
        ..addCommand(
          DeployStatsCommand(
            stack: stackFrom(extra: extra),
            connection: ssh,
            out: out,
          ),
        );
      expect(await runner.run(['stats', ...arguments]), 0);
      return (out.toString(), ssh.issued);
    }

    test('prints p95 per call and the top statements', () async {
      final (printed, issued) = await run(
        ['--hours', '6', '--top', '5'],
        answer:
            '--dw-stats-calls--\n'
            'GetProfile\t1200\t0.012\t0.048\t0.310\t0\n'
            '--dw-stats-slow--\n2\n'
            '--dw-stats-statements--\n'
            'since\t2026-10-20 09:00:00+00\n'
            '1500\t9000.5\t6.0\t1500\tSELECT * FROM post WHERE id = \$1\n',
      );
      expect(printed, contains('last 6 h'));
      expect(printed, contains(RegExp(r'GetProfile +1200 +12 +48 +310 +0')));
      expect(printed, contains('counted since 2026-10-20 09:00:00+00'));
      expect(printed, contains('SELECT * FROM post WHERE id = \$1'));
      expect(printed, contains('Statements over 500 ms, last 6 h: 2'));
      final script = issued.single;
      expect(script, contains('--since 6h nginx'));
      expect(script, contains('LIMIT 5;'));
      // Read-only: nothing is started, stopped, built or written.
      for (final changing in [' up ', ' stop ', ' build', ' rm ', ' restart']) {
        expect(script, isNot(contains(changing)));
      }
    });

    test('an external database is not asked', () async {
      final (printed, issued) = await run(
        const [],
        extra: '  database: external\n',
        answer: '--dw-stats-calls--\n',
      );
      expect(issued.single, isNot(contains('psql')));
      expect(printed, contains('the database is external'));
      expect(printed, contains('none logged'));
    });

    test('--hours must be a whole number above 0', () async {
      expect(() => run(['--hours', '0']), throwsA(isA<UsageException>()));
    });
  });
}
