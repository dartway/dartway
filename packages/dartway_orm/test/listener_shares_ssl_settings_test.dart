import 'dart:io';

import 'package:test/test.dart';

/// `_DwListener.connect()` (`dw_postgres_database.dart`) opens its own
/// `pg.Connection` — a `LISTEN` session cannot be pooled — and once made its
/// own, separate choice of `sslMode`/`securityContext`, hardcoding
/// `_config.ssl ? require : disable` and nothing for `securityContext`. That
/// silently ignored a configured `caFile`: a `DwJobRunner` session
/// (`jobWorkers > 0`, which calls `listen()`) authenticated unverified even
/// when the pool's own connections were verifying against a CA.
///
/// The fix is one source, not a second copy kept in sync by hand: `dwSslMode`
/// and `dwSecurityContext` in `dw_connection_pool.dart`, called by both
/// `DwPooledConnection.open` and `_DwListener.connect`. A live TLS proof that
/// those two functions themselves enforce `verify-full` lives in the
/// docker-tagged `tls_verify_full_docker_test.dart` — real certificates, a
/// real refusal. What a live test structurally cannot prove is that
/// `_DwListener.connect()` still *calls* them rather than a reintroduced
/// inline duplicate: `DwPostgresDatabase.open()` already refuses any `caFile`
/// mismatch through the pool before an instance exists to call `.listen()`
/// on, so a config the listener alone would mishandle never reaches it. This
/// reads the source instead — cheap, exact, and the one check that actually
/// catches "someone copied the logic back out," which is exactly the bug
/// this file exists to keep fixed.
void main() {
  test(
    '_DwListener.connect() calls the shared dwSslMode/dwSecurityContext, not '
    'a hardcoded ssl-only choice of its own',
    () {
      // `dart test` always runs with the package root as the working
      // directory — the same assumption `dart_test.yaml` and every other
      // relative path in this suite already make.
      final file = File('lib/src/db/dw_postgres_database.dart');
      final text = file.readAsStringSync();
      final listenerStart = text.indexOf('class _DwListener');
      expect(
        listenerStart,
        greaterThan(-1),
        reason: '_DwListener moved or was renamed; update this test',
      );
      final connectStart = text.indexOf(
        'Future<void> connect()',
        listenerStart,
      );
      expect(
        connectStart,
        greaterThan(-1),
        reason: '_DwListener.connect() moved or was renamed; update this test',
      );
      // The next `}` at the start of a line closes the method; the settings
      // construction is a handful of lines above it.
      final connectEnd = text.indexOf('\n  }', connectStart);
      final body = text.substring(connectStart, connectEnd);

      expect(
        body,
        contains('sslMode: dwSslMode(_config)'),
        reason:
            'a hardcoded sslMode here (e.g. "_config.ssl ? require : '
            'disable") silently drops a configured caFile for every '
            'listener session',
      );
      expect(
        body,
        contains('securityContext: dwSecurityContext(_config)'),
        reason:
            'without this, a listener connection never even offers the '
            'trusted CA to the driver, whatever sslMode says',
      );
      expect(
        body,
        isNot(contains('SslMode.require')),
        reason:
            'a literal SslMode here is the duplicate this test guards against',
      );
    },
  );
}
