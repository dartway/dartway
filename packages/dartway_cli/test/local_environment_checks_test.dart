import 'dart:io';

import 'package:dartway_cli/src/checker/dw_check_type.dart';
import 'package:dartway_cli/src/checker/dw_local_environment.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// What `dartway check` says about the environment this machine starts a
/// server with.
void main() {
  late Directory root;
  late Directory serverPackage;

  setUp(() {
    root = Directory.systemTemp.createTempSync('dw_local_checks');
    Directory(p.join(root.path, 'deploy')).createSync();
    serverPackage = Directory(p.join(root.path, 'shop_server'))..createSync();
  });
  tearDown(() => root.deleteSync(recursive: true));

  void writeConfig(String text) =>
      File(p.join(root.path, 'deploy', 'config.yaml')).writeAsStringSync(text);
  void writeCompose(String text) => File(
    p.join(serverPackage.path, 'docker-compose.yaml'),
  ).writeAsStringSync(text);

  DwLocalEnvironmentInspector inspect() => DwLocalEnvironmentInspector(
    projectRoot: root,
    serverPackageDir: serverPackage,
  );

  const compose = '''
services:
  postgres:
    image: postgres:17-alpine
    ports:
      - '127.0.0.1:8090:5432'
    environment:
      POSTGRES_USER: postgres
      POSTGRES_DB: shop
      POSTGRES_PASSWORD: 'dev_pw'
  storage:
    ports:
      - '127.0.0.1:8100:9000'
    environment:
      RUSTFS_ACCESS_KEY: dev
      RUSTFS_SECRET_KEY: 'dev_storage_pw'
''';

  const matchingLocal = '''
local:
  DW_DATABASE_PORT: 8090
  DW_DATABASE_NAME: shop
  DW_DATABASE_USER: postgres
  DW_DATABASE_PASSWORD: dev_pw
  DW_STORAGE_ACCESS_KEY: dev
  DW_STORAGE_SECRET_KEY: dev_storage_pw
''';

  test('a project whose two files agree has nothing to report', () {
    writeConfig(matchingLocal);
    writeCompose(compose);

    expect(inspect().run(), 0);
    expect(inspect()..run(), _reports(DwCheckType.devComposeDrifted, isEmpty));
  });

  // Generic, deliberately: this must catch a compose file with no "storage"
  // service whatever it calls the service it has instead — the check holds
  // no name of any storage product, past or present (zero-major: no code
  // recognises the vendor a project used to run).
  test(
    'the local environment expects storage credentials but the compose file '
    'has no "storage" service — named, not silently skipped for having '
    'nothing to compare',
    () {
      writeConfig(matchingLocal);
      writeCompose('''
services:
  postgres:
    image: postgres:17-alpine
    ports:
      - '127.0.0.1:8090:5432'
    environment:
      POSTGRES_USER: postgres
      POSTGRES_DB: shop
      POSTGRES_PASSWORD: 'dev_pw'
  objectstore:
    ports:
      - '127.0.0.1:8100:9000'
    environment:
      SOME_OTHER_PRODUCTS_ACCESS_KEY: dev
      SOME_OTHER_PRODUCTS_SECRET_KEY: 'dev_storage_pw'
''');

      final inspector = inspect()..run();
      expect(
        inspector.findingsOf(DwCheckType.devComposeDrifted).single,
        allOf(contains('"storage"'), contains('storage credentials')),
      );
    },
  );

  test(
    'a project whose local environment sets no storage credentials at all '
    'has nothing to report, whatever the compose file does or does not have',
    () {
      writeConfig('''
local:
  DW_DATABASE_PORT: 8090
  DW_DATABASE_NAME: shop
  DW_DATABASE_USER: postgres
  DW_DATABASE_PASSWORD: dev_pw
''');
      writeCompose('''
services:
  postgres:
    image: postgres:17-alpine
    ports:
      - '127.0.0.1:8090:5432'
    environment:
      POSTGRES_USER: postgres
      POSTGRES_DB: shop
      POSTGRES_PASSWORD: 'dev_pw'
''');

      expect(inspect()..run(), _reports(DwCheckType.devComposeDrifted, isEmpty));
    },
  );

  test('a password changed in one file only is named with both', () {
    writeConfig(matchingLocal.replaceAll('dev_pw', 'changed_pw'));
    writeCompose(compose);

    final inspector = inspect()..run();

    expect(
      inspector.findingsOf(DwCheckType.devComposeDrifted).single,
      allOf(
        contains('POSTGRES_PASSWORD'),
        contains('DW_DATABASE_PASSWORD'),
        contains('shop_server'),
      ),
    );
  });

  test('a port published elsewhere than the server is told is drift', () {
    writeConfig(matchingLocal.replaceAll('8090', '5432'));
    writeCompose(compose);

    expect(
      inspect()..run(),
      _reports(
        DwCheckType.devComposeDrifted,
        contains(allOf(contains('8090'), contains('5432'))),
      ),
    );
  });

  test('a required secret with no local value is named, once', () {
    writeConfig('''
requires:
  secrets: [SMS_API_TOKEN, FCM_KEY]

$matchingLocal
''');
    writeCompose(compose);

    expect(
      inspect()..run(),
      _reports(
        DwCheckType.localSecretMissing,
        contains(allOf(contains('SMS_API_TOKEN'), contains('FCM_KEY'))),
      ),
    );
  });

  test('a required secret the developer stored is not missing', () {
    writeConfig('''
requires:
  secrets: [SMS_API_TOKEN]

$matchingLocal
''');
    writeCompose(compose);
    File(
      p.join(root.path, 'deploy', 'secrets.yaml'),
    ).writeAsStringSync("local:\n  SMS_API_TOKEN: 'mine'\n");

    expect(inspect()..run(), _reports(DwCheckType.localSecretMissing, isEmpty));
  });

  test('a required secret present but empty is still missing', () {
    writeConfig('''
requires:
  secrets: [SMS_API_TOKEN]

local:
  SMS_API_TOKEN:
''');

    expect(
      inspect()..run(),
      _reports(
        DwCheckType.localSecretMissing,
        contains(contains('SMS_API_TOKEN')),
      ),
    );
  });

  test('neither check fails the run: both are advisory', () {
    writeConfig('''
requires:
  secrets: [SMS_API_TOKEN]

${matchingLocal.replaceAll('dev_pw', 'changed_pw')}
''');
    writeCompose(compose);

    expect(inspect().run(), 0);
  });

  test('a project with no deploy/config.yaml is not a finding', () {
    writeCompose(compose);

    expect(inspect().run(), 0);
    expect(inspect()..run(), _reports(DwCheckType.devComposeDrifted, isEmpty));
  });
}

Matcher _reports(DwCheckType type, Matcher findings) =>
    isA<DwLocalEnvironmentInspector>().having(
      (inspector) => inspector.findingsOf(type),
      '${type.name}',
      findings,
    );
