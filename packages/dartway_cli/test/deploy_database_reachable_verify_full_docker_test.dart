@Tags(['docker'])
library;

import 'dart:io';

import 'package:dartway_cli/src/deploy/remote_checks.dart';
import 'package:dartway_cli/src/deploy/ssh_runner.dart';
import 'package:dartway_cli/src/deploy/stack.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support/deploy_fixtures.dart';

/// Proves `database-reachable` connects `verify-full` when
/// `DW_DATABASE_CA_FILE` names the CA that actually signed the server's
/// certificate, and is refused — with a TLS-shaped reason, not a pass and not
/// an "unrecognised failure" — when a different CA is named instead
/// (dartway/dartway#342). `sslmode=require` and the config-only refusals
/// (contradiction, undeclared file, undelivered file) are exercised in
/// `deploy_database_reachable_test.dart`, without Docker.
void main() {
  const dbUser = 'probe';
  const dbName = 'probe';
  const dbPassword = 'dw-test-secret-value';

  late Directory dir;
  late String network;
  late String certVolume;
  late String container;
  late String caCertPath;
  late String wrongCaCertPath;

  Future<ProcessResult> docker(List<String> arguments) =>
      Process.run('docker', arguments);

  void openssl(List<String> arguments) {
    final result = Process.runSync('openssl', arguments);
    if (result.exitCode != 0) {
      fail('openssl ${arguments.join(' ')} failed: ${result.stderr}');
    }
  }

  File storeFile(String name, Map<String, String> values) {
    final file = File(p.join(dir.path, '$name.env'));
    final buffer = StringBuffer();
    values.forEach((key, value) => buffer.writeln("$key='$value'"));
    file.writeAsStringSync(buffer.toString());
    return file;
  }

  Future<DwSshResult> probe(
    File store, {
    required List<String> requiredFiles,
  }) => LocalShell().run(
    dwDatabaseReachabilityScript(
      storeFile: store.path,
      image: DwStack.postgresImage,
      network: network,
      requiredFiles: requiredFiles,
    ),
  );

  setUpAll(() async {
    dir = Directory.systemTemp.createTempSync('dw_db_verify_full_');
    final suffix = DateTime.now().microsecondsSinceEpoch;
    network = 'dw_test_verifyfull_$suffix';
    certVolume = '${network}_cert';
    container = '${network}_pg';
    caCertPath = p.join(dir.path, 'ca.crt');
    wrongCaCertPath = p.join(dir.path, 'wrong-ca.crt');

    var result = await docker(['network', 'create', network]);
    if (result.exitCode != 0)
      fail('could not create a network: ${result.stderr}');

    // The CA that actually signs the server's certificate.
    openssl([
      'req',
      '-x509',
      '-newkey',
      'rsa:2048',
      '-nodes',
      '-keyout',
      p.join(dir.path, 'ca.key'),
      '-out',
      caCertPath,
      '-days',
      '1',
      '-subj',
      '/CN=Dartway Test CA',
    ]);
    // Unrelated — never used to sign anything — standing in for "the wrong
    // provider's CA".
    openssl([
      'req',
      '-x509',
      '-newkey',
      'rsa:2048',
      '-nodes',
      '-keyout',
      p.join(dir.path, 'wrong-ca.key'),
      '-out',
      wrongCaCertPath,
      '-days',
      '1',
      '-subj',
      '/CN=Wrong Test CA',
    ]);

    // The server's own key and certificate, signed by the real CA, with a
    // SAN matching the container name this test reaches it by (the throwaway
    // Docker network resolves it exactly like a real host name would).
    openssl([
      'req',
      '-newkey',
      'rsa:2048',
      '-nodes',
      '-keyout',
      p.join(dir.path, 'server.key'),
      '-out',
      p.join(dir.path, 'server.csr'),
      '-subj',
      '/CN=$container',
    ]);
    // A proper server certificate, key usage and extended key usage included
    // — `libpq`/OpenSSL accepts one without them, but this is what a real
    // provider issues, and it is what `dartway_orm`'s own verify-full test
    // (`tls_verify_full_docker_test.dart`) needs: `dart:io`'s BoringSSL
    // rejects a leaf with no declared purpose even when it chains to a
    // trusted CA.
    final extFile = File(p.join(dir.path, 'server.ext'))
      ..writeAsStringSync(
        'subjectAltName=DNS:$container\n'
        'basicConstraints=CA:FALSE\n'
        'keyUsage=digitalSignature,keyEncipherment\n'
        'extendedKeyUsage=serverAuth\n',
      );
    openssl([
      'x509',
      '-req',
      '-in',
      p.join(dir.path, 'server.csr'),
      '-CA',
      caCertPath,
      '-CAkey',
      p.join(dir.path, 'ca.key'),
      '-CAcreateserial',
      '-out',
      p.join(dir.path, 'server.crt'),
      '-days',
      '1',
      '-extfile',
      extFile.path,
    ]);

    result = await docker(['volume', 'create', certVolume]);
    if (result.exitCode != 0)
      fail('could not create a volume: ${result.stderr}');
    result = await docker([
      'run',
      '--rm',
      '-v',
      '${dir.path}:/host:ro',
      '-v',
      '$certVolume:/certs',
      DwStack.postgresImage,
      'sh',
      '-c',
      'cp /host/server.crt /host/server.key /certs/ && '
          'chown postgres:postgres /certs/server.key /certs/server.crt && '
          'chmod 600 /certs/server.key',
    ]);
    if (result.exitCode != 0) {
      fail('could not prepare the certificate volume: ${result.stderr}');
    }

    result = await docker([
      'run',
      '--detach',
      '--rm',
      '--name',
      container,
      '--network',
      network,
      '--tmpfs',
      '/var/lib/postgresql/data',
      '-v',
      '$certVolume:/certs:ro',
      '--env',
      'POSTGRES_USER=$dbUser',
      '--env',
      'POSTGRES_DB=$dbName',
      '--env',
      'POSTGRES_PASSWORD=$dbPassword',
      DwStack.postgresImage,
      '-c',
      'ssl=on',
      '-c',
      'ssl_cert_file=/certs/server.crt',
      '-c',
      'ssl_key_file=/certs/server.key',
    ]);
    if (result.exitCode != 0)
      fail('could not start the database: ${result.stderr}');

    final deadline = DateTime.now().add(const Duration(seconds: 30));
    while (true) {
      final ready = await docker([
        'exec',
        container,
        'pg_isready',
        '--username',
        dbUser,
        '--dbname',
        dbName,
      ]);
      if (ready.exitCode == 0) break;
      if (DateTime.now().isAfter(deadline))
        fail('the database never became ready');
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
  });

  tearDownAll(() async {
    await docker(['rm', '--force', container]);
    await docker(['volume', 'rm', '--force', certVolume]);
    await docker(['network', 'rm', network]);
    dir.deleteSync(recursive: true);
  });

  test('the CA that actually signed the server certificate: verify-full '
      'connects and queries', () async {
    final ca = File(p.join(dir.path, 'db-ca.pem'))
      ..writeAsStringSync(File(caCertPath).readAsStringSync());
    addTearDown(ca.deleteSync);
    final store = storeFile('ok', {
      'DW_DATABASE_HOST': container,
      'DW_DATABASE_PORT': '5432',
      'DW_DATABASE_NAME': dbName,
      'DW_DATABASE_USER': dbUser,
      'DW_DATABASE_PASSWORD': dbPassword,
      'DW_DATABASE_CA_FILE': '/run/secrets/db-ca.pem',
    });
    final result = await probe(store, requiredFiles: ['db-ca.pem']);
    final verdict = dwJudgeDatabaseReachable(result);
    expect(
      verdict.ok,
      isTrue,
      reason: '${result.stdout}\n${result.stderr}\n${verdict.detail}',
    );
  });

  test(
    'a different CA is refused with a TLS-shaped reason, never a pass',
    () async {
      final ca = File(p.join(dir.path, 'db-ca.pem'))
        ..writeAsStringSync(File(wrongCaCertPath).readAsStringSync());
      addTearDown(ca.deleteSync);
      final store = storeFile('wrong-ca', {
        'DW_DATABASE_HOST': container,
        'DW_DATABASE_PORT': '5432',
        'DW_DATABASE_NAME': dbName,
        'DW_DATABASE_USER': dbUser,
        'DW_DATABASE_PASSWORD': dbPassword,
        'DW_DATABASE_CA_FILE': '/run/secrets/db-ca.pem',
      });
      final result = await probe(store, requiredFiles: ['db-ca.pem']);
      final verdict = dwJudgeDatabaseReachable(result);
      expect(verdict.ok, isFalse);
      expect(verdict.detail.toLowerCase(), contains('tls'));
    },
  );
}
