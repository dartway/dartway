@Tags(['docker'])
library;

import 'dart:io';

import 'package:dartway_cli/src/deploy/deploy_runner.dart';
import 'package:dartway_cli/src/deploy/deploy_stats.dart';
import 'package:dartway_cli/src/deploy/renderer.dart';
import 'package:dartway_cli/src/deploy/ssh_runner.dart';
import 'package:dartway_cli/src/deploy/stack.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support/deploy_fixtures.dart';

/// The bundled Postgres as the rendered compose file starts it and the
/// deploy's database step leaves it: `pg_stat_statements` loaded and
/// created, the slow-statement log at `slow_query_ms` — and `deploy stats`
/// reading both back.
void main() {
  late Directory dir;
  final shell = LocalShell();
  final stack = stackFrom(
    extra: '  project: dwpgstats645\n  slow_query_ms: 200\n',
  );

  Future<DwSshResult> sh(String script) async {
    final result = await shell.run(script);
    expect(
      result.ok,
      isTrue,
      reason: '$script\n${result.stdout}\n${result.stderr}',
    );
    return result;
  }

  Future<String> psql(String sql) async => (await sh(
    "cd '${dir.path}' && docker compose exec -T ${DwStack.postgresService} "
    "psql -X -A -t -U ${stack.databaseName} -d ${stack.databaseName} "
    "-c \"$sql\"",
  )).stdout.trim();

  setUp(() {
    dir = Directory.systemTemp.createTempSync('dw_pg_stats_');
    File(
      p.join(dir.path, 'docker-compose.yml'),
    ).writeAsStringSync(DwStackRenderer(stack: stack).composeFile);
    for (final package in [stack.serverPackage, stack.flutterPackage]) {
      File(p.join(dir.path, package, 'Dockerfile'))
        ..createSync(recursive: true)
        ..writeAsStringSync('FROM scratch\n');
    }
    File(p.join(dir.path, '.env')).writeAsStringSync(
      stack.requiredSecretKeys.map((key) => "$key='value'\n").join(),
    );
  });

  tearDown(() async {
    await shell.run(
      "cd '${dir.path}' && docker compose down -v >/dev/null 2>&1",
    );
    dir.deleteSync(recursive: true);
  });

  test(
    'statements are counted and slow ones logged, read back by stats',
    () async {
      final runner = DwDeployRunner(
        ssh: shell,
        stack: stack,
        appDir: dir.path,
        storeDir: p.join(dir.path, 'state'),
      );
      final started = await runner.startDatabase();
      expect(
        started.ok,
        isTrue,
        reason: '${started.stdout}\n${started.stderr}',
      );
      expect(started.stdout, contains('statements over 200 ms are logged'));
      expect(await psql('SHOW shared_preload_libraries'), 'pg_stat_statements');
      expect(await psql('SHOW log_min_duration_statement'), '200ms');
      expect(await psql('SHOW log_parameter_max_length'), '0');
      expect(await psql('SHOW log_parameter_max_length_on_error'), '0');

      // Run again: the database is not restarted, the step is idempotent.
      final startedAt = await psql('SELECT pg_postmaster_start_time()');
      expect((await runner.startDatabase()).ok, isTrue);
      expect(await psql('SELECT pg_postmaster_start_time()'), startedAt);

      await psql('CREATE TABLE post (id int)');
      for (var i = 0; i < 3; i++) {
        await psql('SELECT count(*) FROM post WHERE id = $i');
      }
      await psql('SELECT pg_sleep(0.3)');

      // Extended-query bind values never reach either slow or error logs.
      await sh('''
cd '${dir.path}'
docker compose exec -T postgres psql -X -q -U ${stack.databaseName} -d ${stack.databaseName} <<'SQL'
SELECT pg_sleep(0.3), \$1::text
\\bind 'dw-private-slow-parameter'
\\g
SELECT 1 / \$1::int
\\bind '0'
\\g
SQL
''');
      final log = (await sh(
        "cd '${dir.path}' && docker compose logs postgres",
      )).stdout;
      expect(log, contains('duration:'));
      expect(log, isNot(contains('dw-private-slow-parameter')));
      expect(log, isNot(contains('parameters:')));

      final stats = DwDeployStats(ssh: shell, stack: stack, appDir: dir.path);
      final report = await stats.read(hours: 1, top: 50);
      expect(report.statementsProblem, isNull);
      expect(report.statementsSince, isNotNull);
      final counted = report.statements!.firstWhere(
        (row) => row.query.contains('FROM post WHERE id ='),
      );
      expect(counted.calls, 3);
      expect(counted.query, contains(r'$1'), reason: 'literals are normalised');
      expect(report.slowStatements, greaterThanOrEqualTo(1));
      expect(
        stats.format(report, hours: 1),
        contains('Statements over 200 ms, last 1 h: '),
      );
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
