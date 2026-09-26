@Tags(['docker'])
library;

import 'dart:io';

import 'package:dartway_orm/dartway_orm.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Proves `DwDatabaseConfig.caFile` end to end against a real Postgres: a
/// server certificate signed by a throwaway CA connects when that CA is
/// named, and is refused — with a certificate error, not a hang or a silent
/// downgrade — when a different CA is named instead. `sslmode=require`
/// (no `caFile`) is exercised elsewhere; this file is only about `verify-full`
/// (dartway/dartway#342).
void main() {
  const dbUser = 'probe';
  const dbName = 'probe';
  const dbPassword = 'dw-test-secret-value';
  const image = 'postgres:17-alpine';

  late Directory dir;
  late String certVolume;
  late String container;
  late int port;
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

  int? publishedPort(String dockerPortOutput) {
    for (final line in dockerPortOutput.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final separator = trimmed.lastIndexOf(':');
      if (separator < 0) continue;
      final value = int.tryParse(trimmed.substring(separator + 1));
      if (value != null) return value;
    }
    return null;
  }

  setUpAll(() async {
    dir = Directory.systemTemp.createTempSync('dw_orm_verify_full_');
    final suffix = DateTime.now().microsecondsSinceEpoch;
    certVolume = 'dw_test_verify_full_cert_$suffix';
    container = 'dw_test_verify_full_pg_$suffix';
    caCertPath = p.join(dir.path, 'ca.crt');
    wrongCaCertPath = p.join(dir.path, 'wrong-ca.crt');

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
    // An unrelated CA — never used to sign anything — standing in for "the
    // wrong provider's CA": a server certificate valid under the real CA
    // must not also verify under this one.
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

    // The server's own key and certificate, signed by the real CA above, with
    // a SAN matching how this test reaches it (loopback).
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
      '/CN=localhost',
    ]);
    // Extended key usage matters here, not just the chain: BoringSSL (which
    // `dart:io` embeds) checks the leaf's purpose during verification and
    // rejects a certificate with none as "application verification failure"
    // even though it chains to a trusted CA and `openssl verify` accepts it.
    final extFile = File(p.join(dir.path, 'server.ext'))
      ..writeAsStringSync(
        'subjectAltName=DNS:localhost,IP:127.0.0.1\n'
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

    var result = await docker(['volume', 'create', certVolume]);
    if (result.exitCode != 0) {
      fail('could not create a volume: ${result.stderr}');
    }
    result = await docker([
      'run',
      '--rm',
      '-v',
      '${dir.path}:/host:ro',
      '-v',
      '$certVolume:/certs',
      image,
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
      '--publish',
      '127.0.0.1::5432',
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
      image,
      '-c',
      'ssl=on',
      '-c',
      'ssl_cert_file=/certs/server.crt',
      '-c',
      'ssl_key_file=/certs/server.key',
    ]);
    if (result.exitCode != 0) {
      fail('could not start the database: ${result.stderr}');
    }

    final portResult = await docker(['port', container, '5432/tcp']);
    final resolved = portResult.exitCode == 0
        ? publishedPort(portResult.stdout as String)
        : null;
    if (resolved == null) fail('could not read the published port');
    port = resolved;

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
      if (DateTime.now().isAfter(deadline)) {
        fail('the database never became ready');
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }

    // `pg_isready` answers before the TLS listener has settled on some hosts
    // (seen under emulation): the very first raw SSL probe a test's
    // connection makes can then race a socket the server has not opened yet.
    // Repeat the exact handshake `DwConnectionPool` itself starts with —
    // SSLRequest, expect 'S' — until it succeeds a few times in a row.
    var consecutive = 0;
    while (consecutive < 3) {
      try {
        final socket = await Socket.connect(
          '127.0.0.1',
          port,
          timeout: const Duration(seconds: 2),
        );
        socket.add(const [0, 0, 0, 8, 4, 210, 22, 47]);
        await socket.flush();
        final answer = await socket.first.timeout(const Duration(seconds: 2));
        socket.destroy();
        consecutive = (answer.isNotEmpty && answer.first == 0x53)
            ? consecutive + 1
            : 0;
      } catch (_) {
        consecutive = 0;
      }
      if (DateTime.now().isAfter(deadline)) {
        fail('the database never answered the SSL handshake reliably');
      }
    }
  });

  tearDownAll(() async {
    await docker(['rm', '--force', container]);
    await docker(['volume', 'rm', '--force', certVolume]);
    dir.deleteSync(recursive: true);
  });

  DwDatabaseConfig configWith(String caFile) => DwDatabaseConfig(
    host: '127.0.0.1',
    port: port,
    name: dbName,
    user: dbUser,
    password: dbPassword,
    ssl: true,
    caFile: caFile,
    maxConnections: 1,
  );

  test('the CA that actually signed the server certificate connects and '
      'queries — verify-full, not merely require', () async {
    final database = await DwPostgresDatabase.open(configWith(caCertPath));
    addTearDown(database.close);
    expect(await database.db.query('SELECT 1 AS one'), [
      {'one': 1},
    ]);
  });

  test('a different CA is refused with a certificate verification error, not a '
      'silent pass and not a hang', () async {
    await expectLater(
      DwPostgresDatabase.open(configWith(wrongCaCertPath)),
      throwsA(
        isA<DwDatabaseException>().having(
          (e) => e.message.toLowerCase(),
          'message',
          contains('certificate'),
        ),
      ),
    );
  });
}
