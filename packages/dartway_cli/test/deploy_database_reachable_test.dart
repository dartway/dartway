import 'dart:io';

import 'package:dartway_cli/src/checker/dw_check_type.dart';
import 'package:dartway_cli/src/deploy/deploy_check.dart';
import 'package:dartway_cli/src/deploy/deploy_target.dart';
import 'package:dartway_cli/src/deploy/remote_checks.dart';
import 'package:dartway_cli/src/deploy/ssh_runner.dart';
import 'package:test/test.dart';

import 'support/deploy_fixtures.dart';

DwSshResult _ok(String output) =>
    DwSshResult(exitCode: 0, stdout: output, stderr: '');

DwSshResult _fail(String message, {int exitCode = 2}) =>
    DwSshResult(exitCode: exitCode, stdout: '', stderr: message);

void main() {
  // The classifier is pure and needs no container: every shape a real
  // psql/libpq answers with, pinned here so a check that regresses to "any
  // exit code is fine" goes red immediately rather than waiting for the
  // docker-tagged proof in deploy_database_reachable_docker_test.dart.
  group('dwJudgeDatabaseReachable — classifying a real client\'s output', () {
    test('a bare "1" on a clean exit is the only shape that passes', () {
      final verdict = dwJudgeDatabaseReachable(_ok('1\n'));
      expect(verdict.ok, isTrue);
    });

    test(
      'exit 0 with no recognisable answer is not silently a pass — a check '
      'that only reads the exit code must fail this',
      () {
        expect(dwJudgeDatabaseReachable(_ok('')).ok, isFalse);
        expect(dwJudgeDatabaseReachable(_ok('something else')).ok, isFalse);
      },
    );

    test('DNS: the configured host does not resolve', () {
      final verdict = dwJudgeDatabaseReachable(
        _fail(
          'psql: error: could not translate host name "db.example.invalid" '
          'to address: Name or service not known',
        ),
      );
      expect(verdict.ok, isFalse);
      expect(verdict.detail, contains('DNS'));
    });

    test('refused: nothing is listening at the configured host and port', () {
      final verdict = dwJudgeDatabaseReachable(
        _fail(
          'psql: error: connection to server at "127.0.0.1", port 5433 '
          'failed: Connection refused',
        ),
      );
      expect(verdict.ok, isFalse);
      expect(verdict.detail, contains('refused'));
    });

    test('auth: the server rejected the credentials', () {
      final verdict = dwJudgeDatabaseReachable(
        _fail(
          'psql: error: connection to server at "db" (10.0.0.5), port 5432 '
          'failed: FATAL:  password authentication failed for user '
          '"dartway"',
        ),
      );
      expect(verdict.ok, isFalse);
      expect(verdict.detail, contains('auth'));
    });

    test(
      'TLS: the server did not offer it though sslmode=require asked for it',
      () {
        final verdict = dwJudgeDatabaseReachable(
          _fail(
            'psql: error: connection to server at "db" (10.0.0.5), port '
            '5432 failed: server does not support SSL, but SSL was required',
          ),
        );
        expect(verdict.ok, isFalse);
        expect(verdict.detail, contains('TLS'));
      },
    );

    test('not configured: the store never received the credentials', () {
      final verdict = dwJudgeDatabaseReachable(
        _fail('ERROR: missing in the secret store: DW_DATABASE_PASSWORD'),
      );
      expect(verdict.ok, isFalse);
      expect(verdict.detail, contains('not configured'));
    });

    test('a message matching nothing known is reported, not swallowed', () {
      final verdict = dwJudgeDatabaseReachable(
        _fail('something entirely unexpected happened'),
      );
      expect(verdict.ok, isFalse);
      expect(verdict.detail, contains('something entirely unexpected'));
    });
  });

  group('database-reachable, wired into deploy check', () {
    final check = dwRemoteDeployChecks.firstWhere(
      (c) => c.id == 'database-reachable',
    );

    test(
      'needs SSH, is an error, and runs at the remote stage — a managed '
      'database that refuses the deploy\'s own credentials is worse '
      'discovered at run than at check',
      () {
        expect(check.requiresSsh, isTrue);
        expect(check.severity, DwCheckSeverity.error);
        expect(check.stage, DwDeployCheckStage.remote);
      },
    );

    test('a bundled database is skipped, not judged — there is nothing '
        'external to reach', () async {
      final stack = stackFrom();
      expect(stack.target.database, DwDatabaseMode.bundled);
      final verdict = await check.evaluate(
        DwDeployContext(
          projectRoot: Directory.systemTemp,
          stack: stack,
          ssh: LocalShell(),
        ),
      );
      expect(verdict.skipped, isTrue);
    });
  });
}
