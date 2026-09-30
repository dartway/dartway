import 'dart:io';

import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:test/test.dart';

/// Reading the environment: typed values, every problem in one error, and
/// the framework's own variables. No database, no storage, no server.
void main() {
  List<String> problemsOf(void Function(DwEnvironmentReader read) body) {
    try {
      DwEnvironmentReader.read(const {}, body);
    } on DwEnvironmentException catch (error) {
      return error.problems;
    }
    return const [];
  }

  List<String> problemsReading(
    Map<String, String> variables,
    void Function(DwEnvironmentReader read) body,
  ) {
    try {
      DwEnvironmentReader.read(variables, body);
    } on DwEnvironmentException catch (error) {
      return error.problems;
    }
    return const [];
  }

  group('DwEnvironmentReader', () {
    test('reads typed values', () {
      final value = DwEnvironmentReader.read(
        {
          'NAME': 'shop',
          'EMPTY': '',
          'WORKERS': '4',
          'ENABLED': 'TRUE',
          'HOSTS': ' a.example.com, ,b.example.com ',
        },
        (read) => (
          name: read.required('NAME'),
          empty: read.optional('EMPTY'),
          absent: read.optional('ABSENT'),
          workers: read.integer('WORKERS'),
          port: read.integer('PORT', fallback: 8080),
          enabled: read.flag('ENABLED'),
          verbose: read.flag('VERBOSE'),
          strict: read.flag('STRICT', fallback: true),
          hosts: read.list('HOSTS'),
          none: read.list('NONE'),
        ),
      );
      expect(value.name, 'shop');
      expect(value.empty, isNull, reason: 'an empty value is unset');
      expect(value.absent, isNull);
      expect(value.workers, 4);
      expect(value.port, 8080);
      expect(value.enabled, isTrue);
      expect(value.verbose, isFalse);
      expect(value.strict, isTrue);
      expect(value.hosts, ['a.example.com', 'b.example.com']);
      expect(value.none, isEmpty);
    });

    test('lists every missing and malformed variable in one error', () {
      expect(
        problemsReading(
          {'WORKERS': 'four', 'ENABLED': 'yes', 'EMPTY_TOKEN': ''},
          (read) {
            read.required('API_TOKEN');
            read.required('EMPTY_TOKEN');
            read.integer('WORKERS');
            read.integer('RETRIES');
            read.flag('ENABLED');
            read.report('SMS_LOGIN and SMS_PASSWORD go together');
          },
        ),
        [
          'API_TOKEN is not set',
          'EMPTY_TOKEN is not set',
          'WORKERS must be an integer, got "four"',
          'RETRIES is not set',
          'ENABLED must be "true" or "false", got "yes"',
          'SMS_LOGIN and SMS_PASSWORD go together',
        ],
      );
    });

    test('never repeats a secret, nor any text value', () {
      final problems = problemsReading(
        {'PIN': 'hunter2', 'SIGNED': 'maybe-s3cr3t'},
        (read) {
          read.integer('PIN', secret: true);
          read.flag('SIGNED', secret: true);
        },
      );
      expect(problems, hasLength(2));
      expect(problems.join(), isNot(contains('hunter2')));
      expect(problems.join(), isNot(contains('s3cr3t')));
      expect(problems.first, startsWith('PIN must be an integer'));

      final error = DwEnvironmentException(problems);
      expect('$error', isNot(contains('hunter2')));
    });

    test('builds nothing out of a broken environment', () {
      var built = false;
      expect(
        () => DwEnvironmentReader.read(const {}, (read) {
          read.required('TOKEN');
          built = true;
          return built;
        }),
        throwsA(isA<DwEnvironmentException>()),
      );
      expect(built, isTrue, reason: 'build runs to collect every problem');
      expect(problemsOf((read) => read.optional('TOKEN')), isEmpty);
    });
  });

  group('DwServerEnvironment', () {
    const database = {
      'DW_DATABASE_HOST': '127.0.0.1',
      'DW_DATABASE_NAME': 'shop',
      'DW_DATABASE_USER': 'postgres',
      'DW_DATABASE_PASSWORD': 'pw',
    };

    DwServerEnvironment read(
      Map<String, String> variables, {
      String? publicBucket,
      String? privateBucket,
    }) => DwEnvironmentReader.read(
      variables,
      (read) => DwServerEnvironment.read(
        read,
        defaultPublicBucket: publicBucket,
        defaultPrivateBucket: privateBucket,
      ),
    );

    test('reads the database, the port and the origins', () {
      final environment = read({
        ...database,
        'PORT': '9000',
        'DW_ALLOWED_ORIGINS': 'https://app.example.com, http://localhost:5000',
      });
      expect(environment.database.host, '127.0.0.1');
      expect(environment.database.name, 'shop');
      expect(environment.port, 9000);
      expect(environment.allowedOrigins, {
        'https://app.example.com',
        'http://localhost:5000',
      });
      expect(environment.storage, isNull);
      expect(environment.provisionStorage, isFalse);
    });

    test('defaults the port to 8080 and has no origins', () {
      final environment = read(database);
      expect(environment.port, 8080);
      expect(environment.allowedOrigins, isEmpty);
    });

    test('fills a development storage in from the endpoint', () {
      final environment = read(
        {
          ...database,
          'DW_STORAGE_ENDPOINT': 'http://127.0.0.1:8100/',
          'DW_STORAGE_ACCESS_KEY': 'key',
          'DW_STORAGE_SECRET_KEY': 'secret',
          'DW_STORAGE_PROVISION': 'true',
        },
        publicBucket: 'shop-public',
        privateBucket: 'shop-private',
      );
      final storage = environment.storage!;
      expect(storage.publicBucket, 'shop-public');
      expect(storage.privateBucket, 'shop-private');
      expect(
        storage.publicBaseUrl,
        Uri.parse('http://127.0.0.1:8100/shop-public'),
      );
      expect(environment.provisionStorage, isTrue);
    });

    test('keeps the buckets and the base the environment names', () {
      final storage = read({
        ...database,
        'DW_STORAGE_ENDPOINT': 'https://storage.example.com',
        'DW_STORAGE_ACCESS_KEY': 'key',
        'DW_STORAGE_SECRET_KEY': 'secret',
        'DW_STORAGE_PUBLIC_BUCKET': 'files',
        'DW_STORAGE_PUBLIC_BASE_URL': 'https://cdn.example.com',
      }, publicBucket: 'shop-public').storage!;
      expect(storage.publicBucket, 'files');
      expect(storage.publicBaseUrl, Uri.parse('https://cdn.example.com'));
      expect(storage.privateBucket, isNull);
    });

    test("reports the database's, the storage's and its own problems at "
        'once, without a secret', () {
      final problems = problemsReading({
        'DW_DATABASE_HOST': '127.0.0.1',
        'DW_DATABASE_PASSWORD': 'pw-s3cr3t',
        'DW_STORAGE_ENDPOINT': 'http://127.0.0.1:8100',
        'DW_STORAGE_SECRET_KEY': 'storage-s3cr3t',
        'PORT': 'eighty',
      }, (read) => DwServerEnvironment.read(read));
      final text = problems.join('\n');
      expect(text, contains('DW_DATABASE_NAME is not set'));
      expect(text, contains('DW_DATABASE_USER is not set'));
      expect(text, contains('DW_STORAGE_ACCESS_KEY is not set'));
      expect(text, contains('PORT must be an integer, got "eighty"'));
      expect(text, isNot(contains('s3cr3t')));
    });

    test('refuses to provision a storage that is not configured', () {
      expect(
        problemsReading({
          ...database,
          'DW_STORAGE_PROVISION': 'true',
        }, (read) => DwServerEnvironment.read(read)),
        [contains('DW_STORAGE_PROVISION is true and DW_STORAGE_ENDPOINT')],
      );
    });

    test('reads the first administrator and migrate-only', () {
      final environment = read({
        ...database,
        'DW_ADMIN_IDENTIFIER': ' admin@example.com ',
        'DW_MIGRATE_ONLY': 'true',
      });
      expect(environment.adminIdentifier, 'admin@example.com');
      expect(environment.migrateOnly, isTrue);
      final none = read(database);
      expect(none.adminIdentifier, isNull);
      expect(none.migrateOnly, isFalse);
      expect(
        problemsReading({
          ...database,
          'DW_MIGRATE_ONLY': 'yes',
        }, (read) => DwServerEnvironment.read(read)),
        [contains('DW_MIGRATE_ONLY must be "true" or "false"')],
      );
    });

    test('honours what only the local overlay sets (#402)', () {
      final root = Directory.systemTemp.createTempSync('dw_env_overlay');
      addTearDown(() => root.deleteSync(recursive: true));
      File('${root.path}/deploy/config.yaml')
        ..createSync(recursive: true)
        ..writeAsStringSync('''
local:
  DW_ADMIN_IDENTIFIER: admin@example.com
  DW_MIGRATE_ONLY: true
  PORT: 9100
''');
      final environment = read(
        DwLocalEnvironment.overlay(database, from: root, report: (_) {}),
      );
      expect(environment.adminIdentifier, 'admin@example.com');
      expect(environment.migrateOnly, isTrue);
      expect(environment.port, 9100);
    });

    test('never names the credentials in a storage URL', () {
      final problems = problemsReading({
        ...database,
        'DW_STORAGE_ENDPOINT': 'ftp://key:s3cr3t@storage.example.com',
        'DW_STORAGE_ACCESS_KEY': 'key',
        'DW_STORAGE_SECRET_KEY': 'secret',
      }, (read) => DwServerEnvironment.read(read));
      expect(problems.join(), contains('ftp://storage.example.com'));
      expect(problems.join(), isNot(contains('s3cr3t')));
    });

    test('refuses a port out of range', () {
      expect(
        problemsReading({
          ...database,
          'PORT': '70000',
        }, (read) => DwServerEnvironment.read(read)),
        [contains('PORT must be a port number')],
      );
    });
  });
}
