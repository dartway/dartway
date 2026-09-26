import 'dart:io';

import 'package:dartway_cli/src/checker/dw_check_type.dart';
import 'package:dartway_cli/src/deploy/deploy_check.dart';
import 'package:dartway_cli/src/deploy/deploy_target.dart';
import 'package:dartway_cli/src/deploy/remote_checks.dart';
import 'package:dartway_cli/src/deploy/ssh_runner.dart';
import 'package:path/path.dart' as p;
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

    test('exit 0 with no recognisable answer is not silently a pass — a check '
        'that only reads the exit code must fail this', () {
      expect(dwJudgeDatabaseReachable(_ok('')).ok, isFalse);
      expect(dwJudgeDatabaseReachable(_ok('something else')).ok, isFalse);
    });

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

    test('auth: a wrong password', () {
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

    // A distinct libpq message from the one above — a role that was never
    // created, rather than one whose password is wrong. Both must classify as
    // "auth": a mutant that keeps only the password-mismatch phrase and drops
    // this one would still pass the test above and fail this one.
    test('auth: a role the provider never created', () {
      final verdict = dwJudgeDatabaseReachable(
        _fail(
          'psql: error: connection to server at "db" (10.0.0.5), port 5432 '
          'failed: FATAL:  role "doadmim" does not exist',
        ),
      );
      expect(verdict.ok, isFalse);
      expect(verdict.detail, contains('auth'));
    });

    test('timeout: no answer at all — a firewall not admitting this host', () {
      final verdict = dwJudgeDatabaseReachable(
        _fail(
          'psql: error: connection to server at "10.0.0.5", port 25060 '
          'failed: Connection timed out\n'
          '\tIs the server running on that host and accepting\n'
          '\tTCP/IP connections?',
        ),
      );
      expect(verdict.ok, isFalse);
      expect(verdict.detail, contains('timeout'));
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

    test('config: a stored value the server itself would refuse to parse', () {
      final verdict = dwJudgeDatabaseReachable(
        _fail(
          'ERROR: invalid in the secret store: '
          'DW_DATABASE_PORT=[abc]-must-be-a-positive-integer',
        ),
      );
      expect(verdict.ok, isFalse);
      expect(verdict.detail, contains('config'));
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

    test('needs SSH, is an error, and runs at the remote stage — a managed '
        'database that refuses the deploy\'s own credentials is worse '
        'discovered at run than at check', () {
      expect(check.requiresSsh, isTrue);
      expect(check.severity, DwCheckSeverity.error);
      expect(check.stage, DwDeployCheckStage.remote);
    });

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

    // The regression a `database.database != external` guard turned into
    // `if (true)` would hide: every external environment would report
    // "skipped" forever, never actually judged. This runs the real script
    // through a real shell (no Docker needed — there is no store at all, so
    // it exits before ever reaching `docker run`), and the one thing that
    // must never be true is `skipped`.
    test('an external database is judged, never skipped, even when nothing is '
        'configured yet', () async {
      final stack = stackFrom(extra: '  database: external\n');
      expect(stack.target.database, DwDatabaseMode.external);
      final verdict = await check.evaluate(
        DwDeployContext(
          projectRoot: Directory.systemTemp,
          stack: stack,
          ssh: LocalShell(),
        ),
      );
      expect(verdict.skipped, isFalse);
      expect(verdict.passed, isFalse);
      expect(verdict.detail, contains('not configured'));
    });
  });

  // The validation half of the script itself, run through a real shell —
  // no Docker involved, because every invalid case here exits before the
  // script ever reaches `docker run`.
  group('dwDatabaseReachabilityScript — validating before connecting', () {
    late Directory dir;

    setUp(() => dir = Directory.systemTemp.createTempSync('dw_db_script_'));
    tearDown(() => dir.deleteSync(recursive: true));

    File storeFile(Map<String, String> values) {
      final file = File(p.join(dir.path, 'store.env'));
      final buffer = StringBuffer();
      values.forEach((key, value) => buffer.writeln("$key='$value'"));
      file.writeAsStringSync(buffer.toString());
      return file;
    }

    const valid = {
      'DW_DATABASE_HOST': 'db.example.com',
      'DW_DATABASE_PORT': '25060',
      'DW_DATABASE_NAME': 'defaultdb',
      'DW_DATABASE_USER': 'doadmin',
      'DW_DATABASE_PASSWORD': 'x',
    };

    Future<DwSshResult> run(Map<String, String> values) => LocalShell().run(
      dwDatabaseReachabilityScript(
        storeFile: storeFile(values).path,
        image: 'postgres:17-alpine',
      ),
    );

    test(
      'a non-numeric port fails before any connection is attempted',
      () async {
        final result = await run({...valid, 'DW_DATABASE_PORT': 'abc'});
        expect(result.ok, isFalse);
        expect(result.stderr, contains('DW_DATABASE_PORT'));
      },
    );

    test('a port of zero fails — positive, not merely numeric', () async {
      final result = await run({...valid, 'DW_DATABASE_PORT': '0'});
      expect(result.ok, isFalse);
      expect(result.stderr, contains('DW_DATABASE_PORT'));
    });

    test(
      'DW_DATABASE_SSL that is neither true nor false fails, named',
      () async {
        final result = await run({...valid, 'DW_DATABASE_SSL': 'maybe'});
        expect(result.ok, isFalse);
        expect(result.stderr, contains('DW_DATABASE_SSL'));
      },
    );

    test(
      'DW_DATABASE_SSL is accepted case-insensitively, like the server',
      () async {
        // TRUE/FALSE in any case must clear validation — the failure that
        // follows (no real host) proves it got past validation, not that it
        // silently short-circuited.
        final result = await run({...valid, 'DW_DATABASE_SSL': 'TRUE'});
        expect(result.stderr, isNot(contains('DW_DATABASE_SSL')));
      },
    );

    test('a non-positive DW_DATABASE_MAX_CONNECTIONS fails, named', () async {
      final result = await run({...valid, 'DW_DATABASE_MAX_CONNECTIONS': '0'});
      expect(result.ok, isFalse);
      expect(result.stderr, contains('DW_DATABASE_MAX_CONNECTIONS'));
    });

    test('every invalid value is named at once, not one at a time', () async {
      final result = await run({
        ...valid,
        'DW_DATABASE_PORT': 'abc',
        'DW_DATABASE_SSL': 'maybe',
        'DW_DATABASE_MAX_CONNECTIONS': '-1',
      });
      expect(result.stderr, contains('DW_DATABASE_PORT'));
      expect(result.stderr, contains('DW_DATABASE_SSL'));
      expect(result.stderr, contains('DW_DATABASE_MAX_CONNECTIONS'));
    });
  });

  // DW_DATABASE_CA_FILE — additive, and validated exactly as
  // DwDatabaseConfig.fromEnvironment validates it, before anything connects.
  group('dwDatabaseReachabilityScript — DW_DATABASE_CA_FILE', () {
    late Directory dir;

    setUp(() => dir = Directory.systemTemp.createTempSync('dw_db_ca_script_'));
    tearDown(() => dir.deleteSync(recursive: true));

    File storeFile(Map<String, String> values) {
      final file = File(p.join(dir.path, 'store.env'));
      final buffer = StringBuffer();
      values.forEach((key, value) => buffer.writeln("$key='$value'"));
      file.writeAsStringSync(buffer.toString());
      return file;
    }

    const valid = {
      'DW_DATABASE_HOST': 'db.example.com',
      'DW_DATABASE_PORT': '25060',
      'DW_DATABASE_NAME': 'defaultdb',
      'DW_DATABASE_USER': 'doadmin',
      'DW_DATABASE_PASSWORD': 'x',
    };

    Future<DwSshResult> run(
      Map<String, String> values, {
      List<String> requiredFiles = const [],
    }) => LocalShell().run(
      dwDatabaseReachabilityScript(
        storeFile: storeFile(values).path,
        image: 'postgres:17-alpine',
        requiredFiles: requiredFiles,
      ),
    );

    test(
      'set together with DW_DATABASE_SSL=false is refused as a contradiction '
      '— a CA has nothing to verify without TLS',
      () async {
        final result = await run(
          {
            ...valid,
            'DW_DATABASE_SSL': 'false',
            'DW_DATABASE_CA_FILE': '/run/secrets/db-ca.pem',
          },
          requiredFiles: ['db-ca.pem'],
        );
        expect(result.ok, isFalse);
        expect(result.stderr, contains('DW_DATABASE_CA_FILE'));
        expect(result.stderr, contains('DW_DATABASE_SSL'));
      },
    );

    test('naming a file not declared under requires.files fails, named — never '
        'silently mounted from wherever it happens to be', () async {
      final result = await run({
        ...valid,
        'DW_DATABASE_CA_FILE': '/run/secrets/db-ca.pem',
      }, requiredFiles: const []);
      expect(result.ok, isFalse);
      expect(result.stderr, contains('DW_DATABASE_CA_FILE'));
      expect(result.stderr, contains('requires.files'));
    });

    // The server opens the literal path DW_DATABASE_CA_FILE names, never just
    // its basename — so the value has to be exactly `/run/secrets/<name>`,
    // not merely end in a declared name. Each of these matches a declared
    // file by basename and is refused anyway, for three different reasons a
    // basename-only check would have missed.
    for (final MapEntry(key: path, value: why) in {
      '/etc/ssl/x.pem': 'a directory nothing declares, not the mounted one',
      'x.pem': 'no directory at all — a bare file name',
      '/run/secrets/a/x.pem':
          'a subdirectory of the mount, not the mount itself',
    }.entries) {
      test('"$path" ($why) names a declared file but is refused for the '
          'directory, not mounted directly under /run/secrets', () async {
        final result = await run(
          {...valid, 'DW_DATABASE_CA_FILE': path},
          requiredFiles: ['x.pem'],
        );
        expect(result.ok, isFalse);
        expect(result.stderr, contains('DW_DATABASE_CA_FILE'));
        expect(result.stderr, contains('must-be-mounted-directly-under'));
      });
    }

    test('declared but never delivered (secret put-file was never run) fails, '
        'named', () async {
      final result = await run(
        {...valid, 'DW_DATABASE_CA_FILE': '/run/secrets/db-ca.pem'},
        requiredFiles: ['db-ca.pem'],
      );
      expect(result.ok, isFalse);
      expect(result.stderr, contains('DW_DATABASE_CA_FILE'));
      expect(result.stderr, contains('not-delivered'));
    });

    // Runs with no real `docker` on PATH — a fake one recording exactly how it
    // was invoked, so this proves what the script *decided* (verify-full, the
    // root cert mounted and referenced) without needing a Docker daemon in
    // the tier that promises it needs no services, and without the earlier,
    // weaker version of this test's assumption that "no error mentions
    // DW_DATABASE_CA_FILE" meant validation passed — it could just as well
    // have meant the check silently fell back to `require`.
    test(
      'declared and delivered: verify-full is chosen, the root cert is '
      'mounted and PGSSLROOTCERT points at it — not merely "no error"',
      () async {
        File(
          p.join(dir.path, 'db-ca.pem'),
        ).writeAsStringSync('-----BEGIN CERTIFICATE-----\ndummy\n');
        final fakeDockerDir = Directory(p.join(dir.path, 'fake-bin'))
          ..createSync();
        final fakeDocker = File(p.join(fakeDockerDir.path, 'docker'))
          ..writeAsStringSync('''
#!/bin/sh
prev=""
for arg in "\$@"; do
  if [ "\$prev" = "--env-file" ]; then
    echo "===ENVFILE==="
    cat "\$arg"
    echo "===END==="
  fi
  if [ "\$prev" = "-v" ]; then
    echo "MOUNT:\$arg"
  fi
  prev="\$arg"
done
echo 1
''');
        Process.runSync('chmod', ['+x', fakeDocker.path]);
        final path = Platform.environment['PATH'] ?? '/usr/bin:/bin';
        final result =
            await LocalShell(
              environment: {'PATH': '${fakeDockerDir.path}:$path'},
            ).run(
              dwDatabaseReachabilityScript(
                storeFile: storeFile({
                  ...valid,
                  'DW_DATABASE_CA_FILE': '/run/secrets/db-ca.pem',
                }).path,
                image: 'postgres:17-alpine',
                requiredFiles: ['db-ca.pem'],
              ),
            );
        expect(result.stderr, isNot(contains('DW_DATABASE_CA_FILE')));
        expect(result.stdout, contains('PGSSLMODE=verify-full'));
        expect(result.stdout, contains('PGSSLROOTCERT=/dw-database-ca.pem'));
        expect(
          result.stdout,
          contains('MOUNT:${dir.path}/db-ca.pem:/dw-database-ca.pem:ro'),
        );
      },
    );
  });
}
