import 'package:dartway_cli/src/test_database.dart';
import 'package:test/test.dart';

void main() {
  group('parsePublishedPort', () {
    test('reads the host port Docker assigned', () {
      expect(parsePublishedPort('0.0.0.0:54321\n'), 54321);
    });

    test('survives the second line the daemon adds for IPv6', () {
      // Both lines carry the same port; the address is what differs, and an
      // IPv6 one is full of colons — which is why the port is taken from the
      // right and not from a split on ':'.
      expect(parsePublishedPort('0.0.0.0:54321\n[::]:54321\n'), 54321);
    });

    test('reads a port when only the IPv6 line is published', () {
      expect(parsePublishedPort('[::]:32768'), 32768);
    });

    test('answers null when Docker published nothing', () {
      // The case that must not be mistaken for a port: a container started
      // without its port published prints an empty line, and treating that as
      // success is how the old arrangement sent a suite to a neighbour's
      // database.
      expect(parsePublishedPort(''), isNull);
      expect(parsePublishedPort('\n  \n'), isNull);
    });

    test('answers null on a line that carries no number', () {
      expect(parsePublishedPort('0.0.0.0:not-a-port'), isNull);
    });
  });

  group('EphemeralDatabase', () {
    test('states the coordinates in the names the server reads', () {
      // These keys are the contract with `DwDatabaseConfig.fromEnvironment`.
      // Renaming one here leaves the suite without a database — loudly, since
      // that config reports every missing key — and `SSL` has to be off: the
      // container serves no TLS and the driver requires it by default.
      const database = EphemeralDatabase(id: 'abc', port: 54321, password: 'p');

      expect(database.databaseEnvironment(name: 'postgres', user: 'postgres'), {
        'DW_DATABASE_HOST': 'localhost',
        'DW_DATABASE_PORT': '54321',
        'DW_DATABASE_NAME': 'postgres',
        'DW_DATABASE_USER': 'postgres',
        'DW_DATABASE_PASSWORD': 'p',
        'DW_DATABASE_SSL': 'false',
      });
    });
  });
}
