@Tags(['docker'])
library;

import 'dart:io';

import 'package:dartway_cli/src/deploy/remote_checks.dart';
import 'package:dartway_cli/src/deploy/ssh_runner.dart';
import 'package:dartway_cli/src/deploy/stack.dart';
import 'package:dartway_cli/src/test_database.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support/deploy_fixtures.dart';

/// Proves `database-reachable` against real Postgres containers standing in
/// for a managed provider: the exact three outcomes the check exists to tell
/// apart — a real success, a wrong password, and a server that does not speak
/// TLS while `sslmode=require` asks for it.
///
/// Every container sits on one throwaway Docker network, addressed by
/// container name — the same shape as reaching a real host over the internet
/// as far as the script is concerned, and without the loopback/NAT
/// indirection a container cannot see through on every platform this runs on.
void main() {
  const dbUser = 'probe';
  const dbName = 'probe';
  const dbPassword = 'dw-test-secret-value';

  late Directory dir;
  late String network;
  late String certVolume;
  late String tlsContainer;
  late String plainAlias;
  late TestDatabase plainDb;
  late EphemeralDatabase plain;

  Future<ProcessResult> docker(List<String> arguments) =>
      Process.run('docker', arguments);

  File storeFile(String name, Map<String, String> values) {
    final file = File(p.join(dir.path, '$name.env'));
    final buffer = StringBuffer();
    values.forEach((key, value) => buffer.writeln("$key='$value'"));
    file.writeAsStringSync(buffer.toString());
    return file;
  }

  Future<DwSshResult> probe(File store, {String? forNetwork}) => LocalShell()
      .run(
        dwDatabaseReachabilityScript(
          storeFile: store.path,
          image: DwStack.postgresImage,
          network: forNetwork ?? network,
        ),
      );

  setUpAll(() async {
    dir = Directory.systemTemp.createTempSync('dw_db_reachable_');
    network = 'dw_test_dbreach_${DateTime.now().microsecondsSinceEpoch}';
    certVolume = '${network}_cert';
    tlsContainer = '${network}_pg_tls';
    plainAlias = '${network}_pg_plain';

    var result = await docker(['network', 'create', network]);
    if (result.exitCode != 0) fail('could not create a network: ${result.stderr}');

    // A self-signed certificate, generated with the host's own openssl (no
    // extra image, no network dependency the pinned Postgres image does not
    // already carry) and handed to the postgres user's ownership entirely
    // inside a container — a host bind-mount would keep the host's numeric
    // uid, which Postgres's own permission check rejects.
    final certDir = Directory(p.join(dir.path, 'cert'))..createSync();
    result = Process.runSync('openssl', [
      'req',
      '-x509',
      '-newkey',
      'rsa:2048',
      '-nodes',
      '-keyout',
      p.join(certDir.path, 'server.key'),
      '-out',
      p.join(certDir.path, 'server.crt'),
      '-days',
      '1',
      '-subj',
      '/CN=localhost',
    ]);
    if (result.exitCode != 0) {
      fail('could not generate a self-signed certificate: ${result.stderr}');
    }
    result = await docker(['volume', 'create', certVolume]);
    if (result.exitCode != 0) fail('could not create a volume: ${result.stderr}');
    result = await docker([
      'run', '--rm',
      '-v', '${certDir.path}:/host:ro',
      '-v', '$certVolume:/certs',
      DwStack.postgresImage,
      'sh', '-c',
      'cp /host/server.crt /host/server.key /certs/ && '
          'chown postgres:postgres /certs/server.key /certs/server.crt && '
          'chmod 600 /certs/server.key',
    ]);
    if (result.exitCode != 0) {
      fail('could not prepare the certificate volume: ${result.stderr}');
    }

    result = await docker([
      'run', '--detach', '--rm',
      '--name', tlsContainer,
      '--network', network,
      '--tmpfs', '/var/lib/postgresql/data',
      '-v', '$certVolume:/certs:ro',
      '--env', 'POSTGRES_USER=$dbUser',
      '--env', 'POSTGRES_DB=$dbName',
      '--env', 'POSTGRES_PASSWORD=$dbPassword',
      DwStack.postgresImage,
      '-c', 'ssl=on',
      '-c', 'ssl_cert_file=/certs/server.crt',
      '-c', 'ssl_key_file=/certs/server.key',
    ]);
    if (result.exitCode != 0) {
      fail('could not start the TLS database: ${result.stderr}');
    }

    final deadline = DateTime.now().add(const Duration(seconds: 30));
    while (true) {
      final ready = await docker([
        'exec', tlsContainer,
        'pg_isready', '--username', dbUser, '--dbname', dbName,
      ]);
      if (ready.exitCode == 0) break;
      if (DateTime.now().isAfter(deadline)) {
        fail('the TLS database never became ready');
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }

    // The plain (non-TLS) database for the "TLS required but not offered"
    // case — the existing test helper `dartway test` itself uses, already
    // proven and already on the compose project's network by name.
    plainDb = TestDatabase(image: DwStack.postgresImage, name: dbName, user: dbUser);
    final started = await plainDb.start();
    if (started == null) fail('could not start the plain database');
    plain = started;
    result = await docker([
      'network', 'connect', '--alias', plainAlias, network, plain.id,
    ]);
    if (result.exitCode != 0) {
      fail('could not attach the plain database to the test network: '
          '${result.stderr}');
    }
    final plainReady = await plainDb.waitUntilReady(
      plain,
      const Duration(seconds: 30),
    );
    if (!plainReady) fail('the plain database never became ready');
  });

  tearDownAll(() async {
    await docker(['rm', '--force', tlsContainer]);
    await plainDb.remove(plain);
    await docker(['volume', 'rm', '--force', certVolume]);
    await docker(['network', 'rm', network]);
    dir.deleteSync(recursive: true);
  });

  test(
    'a real database, correct credentials, sslmode=require: connects and '
    'queries — the pass this check exists to give',
    () async {
      final store = storeFile('ok', {
        'DW_DATABASE_HOST': tlsContainer,
        'DW_DATABASE_PORT': '5432',
        'DW_DATABASE_NAME': dbName,
        'DW_DATABASE_USER': dbUser,
        'DW_DATABASE_PASSWORD': dbPassword,
      });
      final result = await probe(store);
      final verdict = dwJudgeDatabaseReachable(result);
      expect(
        verdict.ok,
        isTrue,
        reason: '${result.stdout}\n${result.stderr}\n${verdict.detail}',
      );
    },
  );

  test(
    'a wrong password is reported as an authentication failure, never as a '
    'pass',
    () async {
      final store = storeFile('bad-password', {
        'DW_DATABASE_HOST': tlsContainer,
        'DW_DATABASE_PORT': '5432',
        'DW_DATABASE_NAME': dbName,
        'DW_DATABASE_USER': dbUser,
        'DW_DATABASE_PASSWORD': 'definitely-not-the-password',
      });
      final result = await probe(store);
      final verdict = dwJudgeDatabaseReachable(result);
      expect(verdict.ok, isFalse);
      expect(verdict.detail.toLowerCase(), contains('auth'));
    },
  );

  test(
    'TLS required but not offered is reported as a TLS failure, never as a '
    'pass — a bare TCP probe would miss exactly this',
    () async {
      final store = storeFile('no-tls', {
        'DW_DATABASE_HOST': plainAlias,
        'DW_DATABASE_PORT': '5432',
        'DW_DATABASE_NAME': dbName,
        'DW_DATABASE_USER': dbUser,
        'DW_DATABASE_PASSWORD': plain.password,
      });
      final result = await probe(store);
      final verdict = dwJudgeDatabaseReachable(result);
      expect(verdict.ok, isFalse);
      expect(verdict.detail.toLowerCase(), contains('tls'));
    },
  );

  test(
    'DW_DATABASE_SSL=false against a database with no TLS at all connects — '
    'the check honours it exactly as the server does, disable not require',
    () async {
      final store = storeFile('ssl-false', {
        'DW_DATABASE_HOST': plainAlias,
        'DW_DATABASE_PORT': '5432',
        'DW_DATABASE_NAME': dbName,
        'DW_DATABASE_USER': dbUser,
        'DW_DATABASE_PASSWORD': plain.password,
        'DW_DATABASE_SSL': 'false',
      });
      final result = await probe(store);
      final verdict = dwJudgeDatabaseReachable(result);
      expect(
        verdict.ok,
        isTrue,
        reason: '${result.stdout}\n${result.stderr}\n${verdict.detail}',
      );
    },
  );
}
