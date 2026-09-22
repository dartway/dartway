import 'dart:io';

import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:test/test.dart';

/// The environment a developer's machine adds to a server started by hand.
/// Files only — no database, no storage, no server.
void main() {
  late Directory root;
  final reported = <String>[];

  setUp(() {
    root = Directory.systemTemp.createTempSync('dw_local_env');
    Directory('${root.path}/deploy').createSync();
    reported.clear();
  });
  tearDown(() => root.deleteSync(recursive: true));

  void writeConfig(String text) =>
      File('${root.path}/deploy/config.yaml').writeAsStringSync(text);
  void writeSecrets(String text) =>
      File('${root.path}/deploy/secrets.yaml').writeAsStringSync(text);

  Map<String, String> overlay(
    Map<String, String> environment, {
    Directory? from,
  }) => DwLocalEnvironment.overlay(
    environment,
    from: from ?? root,
    report: reported.add,
  );

  test('reads the local section of both files', () {
    writeConfig('''
local:
  DW_DATABASE_HOST: 127.0.0.1
  DW_DATABASE_PORT: 8090
  DW_DATABASE_SSL: false

staging:
  host: 203.0.113.10
''');
    writeSecrets('''
local:
  SMS_API_TOKEN: 'local-token'

staging:
  SMS_API_TOKEN: 'staging-token'
''');

    final env = overlay(const {});

    // A YAML scalar is typed; an environment is text either way.
    expect(env['DW_DATABASE_HOST'], '127.0.0.1');
    expect(env['DW_DATABASE_PORT'], '8090');
    expect(env['DW_DATABASE_SSL'], 'false');
    expect(env['SMS_API_TOKEN'], 'local-token');
    // Another environment's section is another environment's business.
    expect(env.length, 4);
    expect(reported.single, contains('3 key(s) from deploy/config.yaml'));
    expect(reported.single, contains('1 from deploy/secrets.yaml'));
  });

  test('the real environment wins, and says which keys it took', () {
    writeConfig('local:\n  DW_DATABASE_PORT: 8090\n');
    writeSecrets("local:\n  SMS_API_TOKEN: 'from-file'\n");

    final env = overlay(const {'DW_DATABASE_PORT': '5432'});

    expect(env['DW_DATABASE_PORT'], '5432');
    expect(env['SMS_API_TOKEN'], 'from-file');
    expect(reported.single, contains('overrides DW_DATABASE_PORT'));
  });

  test('secrets override the committed half', () {
    writeConfig("local:\n  APP_BOOTSTRAP_ADMIN: 'you@example.com'\n");
    writeSecrets("local:\n  APP_BOOTSTRAP_ADMIN: 'me@example.com'\n");

    expect(overlay(const {})['APP_BOOTSTRAP_ADMIN'], 'me@example.com');
  });

  test('finds the project root from a package below it', () {
    writeConfig('local:\n  DW_DATABASE_PORT: 8090\n');
    final server = Directory('${root.path}/app_server')..createSync();

    expect(overlay(const {}, from: server)['DW_DATABASE_PORT'], '8090');
  });

  test('without a project above it, the environment passes through', () {
    final elsewhere = Directory.systemTemp.createTempSync('dw_no_project');
    addTearDown(() => elsewhere.deleteSync(recursive: true));

    expect(
      overlay(const {'PORT': '8080'}, from: elsewhere),
      equals({'PORT': '8080'}),
    );
    // The deployed case: nothing found, nothing said.
    expect(reported, isEmpty);
  });

  test(
    'a project without a local section is not a project with an empty one',
    () {
      writeConfig('staging:\n  host: 203.0.113.10\n');

      expect(overlay(const {'PORT': '8080'}), equals({'PORT': '8080'}));
      expect(reported, isEmpty);
    },
  );

  test('a missing secrets file is the common case, not an error', () {
    writeConfig('local:\n  DW_DATABASE_PORT: 8090\n');

    expect(overlay(const {})['DW_DATABASE_PORT'], '8090');
    expect(reported.single, contains('0 from deploy/secrets.yaml'));
  });

  group('refuses to half-apply', () {
    test('a section that is not a map', () {
      writeConfig('local: 8090\n');

      expect(
        () => overlay(const {}),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            allOf(contains('deploy/config.yaml'), contains('local')),
          ),
        ),
      );
    });

    test('a name that cannot be an environment variable', () {
      writeConfig('local:\n  database_port: 8090\n');

      expect(
        () => overlay(const {}),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('database_port'),
          ),
        ),
      );
    });

    test('a value that is a document', () {
      writeSecrets('local:\n  SERVICE_ACCOUNT:\n    type: service_account\n');
      writeConfig('local:\n  DW_DATABASE_PORT: 8090\n');

      expect(
        () => overlay(const {}),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('SERVICE_ACCOUNT'),
          ),
        ),
      );
    });

    test('a file that is not YAML at all', () {
      writeConfig('local:\n  DW_DATABASE_PORT: 8090\n : :\n');

      expect(() => overlay(const {}), throwsA(isA<StateError>()));
    });
  });
}
