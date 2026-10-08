import 'package:dartway_cli/src/test_servers.dart';
import 'package:test/test.dart';

void main() {
  test(
    'URL credentials decode once and endpoint never contains them',
    () async {
      final server = TestServerUrl.parse(
        'postgres://test%40user:p%3A%2F%25@127.0.0.1:55460/maintenance',
        database: true,
      );
      expect(await server.environment(database: true, allowRemote: false), {
        'DW_DATABASE_HOST': '127.0.0.1',
        'DW_DATABASE_PORT': '55460',
        'DW_DATABASE_NAME': 'maintenance',
        'DW_DATABASE_USER': 'test@user',
        'DW_DATABASE_PASSWORD': 'p:/%',
        'DW_DATABASE_SSL': 'false',
      });
      final storage = TestServerUrl.parse(
        'https://key:s%3Aecret@localhost:9000',
        database: false,
      );
      expect(await storage.environment(database: false, allowRemote: false), {
        'DW_STORAGE_ENDPOINT': 'https://localhost:9000',
        'DW_STORAGE_ACCESS_KEY': 'key',
        'DW_STORAGE_SECRET_KEY': 's:ecret',
        'DW_STORAGE_PATH_STYLE': 'true',
        'DW_STORAGE_REGION': 'us-east-1',
      });
    },
  );

  test(
    'IPv6 loopback and dedicated remote opt-in',
    () async {
      final local = TestServerUrl.parse(
        'postgres://test:secret@[::1]/postgres',
        database: true,
      );
      final environment = await local.environment(
        database: true,
        allowRemote: false,
      );
      expect(environment['DW_DATABASE_PORT'], '5432');
      expect(environment['DW_DATABASE_PASSWORD'], 'secret');
      final remote = TestServerUrl.parse(
        'postgres://test:secret@192.0.2.1/postgres',
        database: true,
      );
      await expectLater(
        remote.environment(database: true, allowRemote: false),
        throwsFormatException,
      );
      expect(
        (await remote.environment(
          database: true,
          allowRemote: true,
        ))['DW_DATABASE_HOST'],
        '192.0.2.1',
      );
    },
  );

  test(
    'malformed URLs fail without echoing input or accepting extra configuration',
    () {
      for (final (url, database) in [
        ('postgres://test:private-value@localhost', true),
        (
          'postgres://test:private-value@localhost/postgres?sslmode=disable',
          true,
        ),
        ('http://test:private-value@localhost/postgres', true),
        ('postgres://test@localhost/postgres', true),
        ('http://test:private-value@localhost/bucket', false),
        ('http://test@localhost:9000', false),
        ('https://test:private-value@localhost:0', false),
      ]) {
        expect(
          () => TestServerUrl.parse(url, database: database),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'safe diagnostic',
              isNot(contains('private-value')),
            ),
          ),
        );
      }
    },
  );
}
