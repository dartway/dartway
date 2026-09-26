@Tags(['docker'])
library;

import 'dart:async';
import 'dart:io';

import 'package:dartway_orm/dartway_orm.dart';
// White-box: `dwSslMode`/`dwSecurityContext` are `@internal` — the one shared
// source `DwPooledConnection.open` and `_DwListener.connect`
// (`dw_postgres_database.dart`) both call, so a connection opened exactly the
// way `.listen()` opens one can be proven to reject a wrong CA without first
// needing `DwPostgresDatabase.open()` to succeed against that same CA (it
// wouldn't — see the module doc below).
import 'package:dartway_orm/src/db/dw_connection_pool.dart';
import 'package:path/path.dart' as p;
import 'package:postgres/postgres.dart' as pg;
import 'package:test/test.dart';

/// Proves `DwDatabaseConfig.caFile` end to end against a real Postgres: a
/// server certificate signed by a throwaway CA connects when that CA is
/// named, and is refused — with a certificate error, not a hang or a silent
/// downgrade — when a different CA is named, or when the right CA signed a
/// certificate for a different host. `sslmode=require` (no `caFile`) is
/// exercised elsewhere; this file is only about `verify-full`
/// (dartway/dartway#342).
///
/// Also proves the fix for a real regression found in review: `.listen()`
/// (`_DwListener.connect()`) used to make its own, separate `require`/
/// `disable` choice, ignoring `caFile` entirely — a `DwJobRunner` session
/// (`jobWorkers > 0`) authenticated unverified even with a CA configured.
/// `DwPostgresDatabase.open()` and `.listen()` share one immutable `config`,
/// so once both call the same `dwSslMode`/`dwSecurityContext`, there is no
/// live scenario left where one succeeds against a certificate the other
/// would refuse — proving that is the point of testing the shared functions
/// directly, exactly as `.listen()` calls them, rather than only through
/// `DwPostgresDatabase.open()`, which a wrong CA already refuses before a
/// listener could ever be attached.
void main() {
  const dbUser = 'probe';
  const dbName = 'probe';
  const dbPassword = 'dw-test-secret-value';
  const image = 'postgres:17-alpine';

  late Directory dir;
  late String caKeyPath;
  late String caCertPath;
  late String wrongCaCertPath;

  // The server whose certificate is right in every way: signed by [caCertPath],
  // SAN covering how this test reaches it.
  late String certVolume;
  late String container;
  late int port;

  // A second server, same CA, but its certificate's SAN names a different
  // host — proving `verify-full` checks the host, not merely the chain
  // (dropping the explicit choice to plain `require`, which leans on libpq's
  // undocumented-outside-its-own-docs behaviour of upgrading `require` to
  // `verify-ca` whenever a root cert is configured, would let this connect:
  // `verify-ca` validates the chain and skips the hostname check entirely).
  late String wrongHostVolume;
  late String wrongHostContainer;
  late int wrongHostPort;

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

  /// Signs a server certificate for [sanList] with the CA at [caCertPath]/
  /// [caKeyPath], starts a Postgres container using it, and returns the
  /// published loopback port once it answers the SSL handshake reliably.
  Future<int> startTlsPostgres({
    required String label,
    required String volume,
    required String container,
    required String sanList,
  }) async {
    final keyPath = p.join(dir.path, '$label.key');
    final csrPath = p.join(dir.path, '$label.csr');
    final crtPath = p.join(dir.path, '$label.crt');
    final extPath = p.join(dir.path, '$label.ext');

    openssl([
      'req',
      '-newkey',
      'rsa:2048',
      '-nodes',
      '-keyout',
      keyPath,
      '-out',
      csrPath,
      '-subj',
      '/CN=$label',
    ]);
    // Extended key usage matters here, not just the chain: BoringSSL (which
    // `dart:io` embeds) checks the leaf's purpose during verification and
    // rejects a certificate with none as "application verification failure"
    // even though it chains to a trusted CA and `openssl verify` accepts it.
    File(extPath).writeAsStringSync(
      'subjectAltName=$sanList\n'
      'basicConstraints=CA:FALSE\n'
      'keyUsage=digitalSignature,keyEncipherment\n'
      'extendedKeyUsage=serverAuth\n',
    );
    openssl([
      'x509',
      '-req',
      '-in',
      csrPath,
      '-CA',
      caCertPath,
      '-CAkey',
      caKeyPath,
      '-CAcreateserial',
      '-out',
      crtPath,
      '-days',
      '1',
      '-extfile',
      extPath,
    ]);

    var result = await docker(['volume', 'create', volume]);
    if (result.exitCode != 0) {
      fail('could not create a volume: ${result.stderr}');
    }
    result = await docker([
      'run',
      '--rm',
      '-v',
      '${dir.path}:/host:ro',
      '-v',
      '$volume:/certs',
      image,
      'sh',
      '-c',
      'cp /host/$label.crt /certs/server.crt && '
          'cp /host/$label.key /certs/server.key && '
          'chown postgres:postgres /certs/server.key /certs/server.crt && '
          'chmod 600 /certs/server.key',
    ]);
    if (result.exitCode != 0) {
      fail(
        'could not prepare the certificate volume for $label: ${result.stderr}',
      );
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
      '$volume:/certs:ro',
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
      fail('could not start the $label database: ${result.stderr}');
    }

    final portResult = await docker(['port', container, '5432/tcp']);
    final resolved = portResult.exitCode == 0
        ? publishedPort(portResult.stdout as String)
        : null;
    if (resolved == null) fail('could not read the published port for $label');
    final port = resolved;

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
        fail('the $label database never became ready');
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
        fail('the $label database never answered the SSL handshake reliably');
      }
    }
    return port;
  }

  setUpAll(() async {
    dir = Directory.systemTemp.createTempSync('dw_orm_verify_full_');
    final suffix = DateTime.now().microsecondsSinceEpoch;
    certVolume = 'dw_test_verify_full_cert_$suffix';
    container = 'dw_test_verify_full_pg_$suffix';
    wrongHostVolume = 'dw_test_verify_full_wronghost_$suffix';
    wrongHostContainer = 'dw_test_verify_full_wronghost_pg_$suffix';
    caKeyPath = p.join(dir.path, 'ca.key');
    caCertPath = p.join(dir.path, 'ca.crt');
    wrongCaCertPath = p.join(dir.path, 'wrong-ca.crt');

    // The CA that actually signs both servers' certificates below.
    openssl([
      'req',
      '-x509',
      '-newkey',
      'rsa:2048',
      '-nodes',
      '-keyout',
      caKeyPath,
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

    port = await startTlsPostgres(
      label: 'server',
      volume: certVolume,
      container: container,
      sanList: 'DNS:localhost,IP:127.0.0.1',
    );
    wrongHostPort = await startTlsPostgres(
      label: 'wrong-host',
      volume: wrongHostVolume,
      container: wrongHostContainer,
      // Deliberately not localhost/127.0.0.1 — the same real CA signs this
      // one too, so only the hostname is wrong.
      sanList: 'DNS:elsewhere.invalid',
    );
  });

  tearDownAll(() async {
    await docker(['rm', '--force', container]);
    await docker(['volume', 'rm', '--force', certVolume]);
    await docker(['rm', '--force', wrongHostContainer]);
    await docker(['volume', 'rm', '--force', wrongHostVolume]);
    dir.deleteSync(recursive: true);
  });

  DwDatabaseConfig configWith(String caFile, {required int port}) =>
      DwDatabaseConfig(
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
    final database = await DwPostgresDatabase.open(
      configWith(caCertPath, port: port),
    );
    addTearDown(database.close);
    expect(await database.db.query('SELECT 1 AS one'), [
      {'one': 1},
    ]);
  });

  test('a different CA is refused with a certificate verification error, not a '
      'silent pass and not a hang', () async {
    await expectLater(
      DwPostgresDatabase.open(configWith(wrongCaCertPath, port: port)),
      throwsA(
        isA<DwDatabaseException>().having(
          (e) => e.message.toLowerCase(),
          'message',
          contains('certificate'),
        ),
      ),
    );
  });

  test('the right CA but the wrong host in the certificate is refused too — '
      'verify-full checks the host, not merely the chain', () async {
    await expectLater(
      DwPostgresDatabase.open(configWith(caCertPath, port: wrongHostPort)),
      throwsA(isA<DwDatabaseException>()),
    );
  });

  test('listen() shares the pool\'s verify-full: the right CA connects and '
      'delivers a live notification', () async {
    final database = await DwPostgresDatabase.open(
      configWith(caCertPath, port: port),
    );
    addTearDown(database.close);
    final stream = await database.listen('dw_verify_full_test');
    final received = Completer<String>();
    final subscription = stream.listen(received.complete);
    addTearDown(subscription.cancel);
    await database.db.notify('dw_verify_full_test', 'hello');
    expect(await received.future.timeout(const Duration(seconds: 10)), 'hello');
  });

  test('the exact connection settings .listen() opens with — dwSslMode and '
      'dwSecurityContext, the one source the pool also calls — reject a '
      'certificate from the wrong CA', () async {
    final config = configWith(wrongCaCertPath, port: port);
    await expectLater(
      pg.Connection.open(
        pg.Endpoint(
          host: config.host,
          port: config.port,
          database: config.name,
          username: config.user,
          password: config.password,
        ),
        settings: pg.ConnectionSettings(
          sslMode: dwSslMode(config),
          securityContext: dwSecurityContext(config),
          applicationName: '${config.applicationName}-listen',
          connectTimeout: config.connectTimeout,
        ),
      ),
      throwsA(isA<pg.PgException>()),
    );
  });
}
