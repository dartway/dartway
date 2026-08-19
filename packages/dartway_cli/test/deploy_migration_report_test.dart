import 'dart:io';

import 'package:dartway_cli/src/deploy/compose_files.dart';
import 'package:dartway_cli/src/deploy/deploy_runner.dart';
import 'package:dartway_cli/src/deploy/deploy_target.dart';
import 'package:dartway_cli/src/deploy/migration_report.dart';
import 'package:dartway_cli/src/deploy/serverpod_config.dart';
import 'package:dartway_cli/src/deploy/ssh_runner.dart';
import 'package:test/test.dart';

/// The literals below are copied out of Serverpod 3.4.11 — `Serverpod
/// ._applyMigrations`, `MigrationManager._migrateToLatestModule` and
/// `MigrationManager.verifyDatabaseIntegrity` — rather than paraphrased. They
/// are the whole contract: nothing else distinguishes a migration container
/// that did the work from one that did not, since both exit 0.
const _appliedOne = '''
SERVERPOD version: 3.4.11, dart: 3.11.0, time: 2026-08-19 06:00:00.000Z
Applied database migration:
 - 20260813134456435
''';

const _appliedSeveral = '''
Applied database migrations:
 - 20260722180525356
 - 20260723050630677
''';

const _alreadyCurrent = '''
SERVERPOD version: 3.4.11, dart: 3.11.0, time: 2026-08-19 06:00:00.000Z
Latest database migration already applied.
''';

/// What the container actually printed in the reported incident: the module's
/// tables were already there, the migration threw, and the process exited 0.
const _failedApply = '''
Failed to apply migration 20260813134456435.
DatabaseQueryException: { message: relation "dw_push_delivery" already exists, code: 42P07 }
2026-08-19 06:00:00.000Z ERROR: Failed to apply database migrations.
2026-08-19 06:00:00.000Z ERROR: Exception: relation "dw_push_delivery" already exists
#0      MigrationManager._migrateToLatestModule
''';

const _drifted = '''
WARNING: The database does not match the target database:
 - Table "dw_push_delivery" is missing.
Hint: Did you forget to run `serverpod generate`, apply the migrations (--apply-migrations), or run a repair migration (--apply-repair-migration)?
''';

DwDeployTarget _target() => DwDeployTarget(
  environment: 'staging',
  host: '203.0.113.10',
  sshUser: 'root',
  deployUser: 'deployer',
  os: 'ubuntu',
  repo: 'git@github.com:acme/shop.git',
  branch: 'master',
  sslEmail: 'ops@example.com',
  webAppDomain: 'app.example.com',
);

DwServerpodConfig _serverpod() => DwServerpodConfig(
  environment: 'staging',
  relativePath: 'shop_server/config/staging.yaml',
  apiServer: DwServerEndpoint(
    name: 'apiServer',
    port: 8080,
    publicHost: 'api.example.com',
    publicPort: 443,
    publicScheme: 'https',
  ),
  insightsServer: null,
  webServer: null,
  databaseHost: 'postgres',
  databasePort: 5432,
  databaseName: 'shop',
  databaseUser: 'shop',
  redisEnabled: false,
  redisHost: null,
);

DwDeployStep _migrateStep() => DwDeployRunner(
  ssh: DwSshRunner(host: '203.0.113.10', user: 'root'),
  target: _target(),
  serverpod: _serverpod(),
  stdout: stdout,
).steps(skipGitUpdate: true).firstWhere((step) => step.id == 'migrate');

void main() {
  group('reading the outcome out of the container output', () {
    test('one applied migration is named', () {
      final report = DwMigrationReport.read(_appliedOne);

      expect(report.outcome, DwMigrationOutcome.applied);
      expect(report.appliedVersions, ['20260813134456435']);
      expect(report.failure, isNull);
      expect(report.summary, contains('20260813134456435'));
    });

    test('the plural header is read the same way', () {
      final report = DwMigrationReport.read(_appliedSeveral);

      expect(report.outcome, DwMigrationOutcome.applied);
      expect(report.appliedVersions, [
        '20260722180525356',
        '20260723050630677',
      ]);
      expect(report.failure, isNull);
    });

    test('nothing pending is a pass, not silence', () {
      final report = DwMigrationReport.read(_alreadyCurrent);

      expect(report.outcome, DwMigrationOutcome.alreadyCurrent);
      expect(report.ok, isTrue);
      expect(report.failure, isNull);
    });

    test('a failed apply fails, whatever the exit code claimed', () {
      final report = DwMigrationReport.read(_failedApply);

      expect(report.outcome, DwMigrationOutcome.failed);
      expect(report.ok, isFalse);
      expect(report.failure, contains('exited 0'));
      // The reason has to travel with the verdict: a deploy that stops without
      // the SQL error in the log sends the reader to the server for it.
      expect(report.stated.join('\n'), contains('20260813134456435'));
    });

    test('a schema that did not catch up fails even though nothing threw', () {
      final report = DwMigrationReport.read(_drifted);

      expect(report.outcome, DwMigrationOutcome.drifted);
      expect(report.failure, contains('create-repair-migration'));
    });

    test('a failure outranks the migrations that landed before it', () {
      final report = DwMigrationReport.read('$_appliedSeveral$_failedApply');

      expect(report.outcome, DwMigrationOutcome.failed);
      expect(report.appliedVersions, isNotEmpty);
      expect(report.failure, isNotNull);
    });

    test('drift is reported as drift when nothing threw', () {
      final report = DwMigrationReport.read('$_appliedOne$_drifted');

      expect(report.outcome, DwMigrationOutcome.drifted);
    });

    test('a disabled migration feature is not a successful step', () {
      final report = DwMigrationReport.read(
        'Migrations are disabled in this project, skipping applying '
        'migration(s).',
      );

      expect(report.outcome, DwMigrationOutcome.disabled);
      expect(report.failure, isNotNull);
    });

    test('saying nothing about the schema is a failure, not a pass', () {
      // The exact shape of the reported blind spot: a step that prints its
      // title and nothing else used to be indistinguishable from a good one.
      final report = DwMigrationReport.read('Creating shop-backend-run-1a2b\n');

      expect(report.outcome, DwMigrationOutcome.silent);
      expect(report.ok, isFalse);
      expect(report.failure, contains('server_entrypoint'));
    });

    test('an empty transcript is silence too', () {
      expect(DwMigrationReport.read('').outcome, DwMigrationOutcome.silent);
    });
  });

  group('the migrate step', () {
    test('prints its output whether or not it succeeded', () {
      expect(_migrateStep().showOutput, isTrue);
    });

    test('passes a successful container', () {
      final verdict = _migrateStep().verdict!(
        DwSshResult(exitCode: 0, stdout: _appliedOne, stderr: ''),
      );

      expect(verdict, isNull);
    });

    test('fails a container that exited 0 having applied nothing', () {
      final verdict = _migrateStep().verdict!(
        DwSshResult(exitCode: 0, stdout: '', stderr: _failedApply),
      );

      expect(verdict, isNotNull);
      expect(verdict, contains('relation "dw_push_delivery" already exists'));
    });

    test('reads stdout and stderr together', () {
      // Serverpod puts the success lines on stdout and the failures on stderr,
      // so a verdict that looked at one stream would miss half the outcomes.
      final verdict = _migrateStep().verdict!(
        DwSshResult(exitCode: 0, stdout: _appliedOne, stderr: _drifted),
      );

      expect(verdict, isNotNull);
    });

    test('the step is still the one docker compose invocation', () {
      // Guards against the verdict being wired to a second, separate command:
      // a check that asks a different question than the deploy answered is the
      // shape this whole change exists to remove.
      expect(_migrateStep().title, 'Apply database migrations');
      expect(
        DwComposeFiles.commandIn('/home/deployer/shop', 'run --rm -T'),
        contains('-f ${DwComposeFiles.projectOverride}'),
      );
    });
  });
}
