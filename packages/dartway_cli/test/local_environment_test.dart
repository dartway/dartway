import 'dart:io';

import 'package:dartway_cli/src/deploy/local_environment.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// The `local` environment as the maintenance commands see it: two halves of
/// one list, cut along the line Git forces.
void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('dw_cli_local');
    Directory(p.join(root.path, 'deploy')).createSync();
  });
  tearDown(() => root.deleteSync(recursive: true));

  void writeConfig(String text) =>
      File(p.join(root.path, 'deploy', 'config.yaml')).writeAsStringSync(text);
  void writeSecrets(String text) =>
      File(p.join(root.path, 'deploy', 'secrets.yaml')).writeAsStringSync(text);

  DwLocalEnvironment local() => DwLocalEnvironment(root);

  test('reads the committed half and the developer\'s own', () {
    writeConfig('''
requires:
  secrets: [SMS_API_TOKEN]

local:
  DW_DATABASE_PORT: 8090
  DW_DATABASE_SSL: false

staging:
  host: 203.0.113.10
''');
    writeSecrets(
      "local:\n  SMS_API_TOKEN: 'mine'\n\nstaging:\n  SMS_API_TOKEN: 'theirs'\n",
    );

    expect(local().committed, {
      'DW_DATABASE_PORT': '8090',
      'DW_DATABASE_SSL': 'false',
    });
    expect(local().mine, {'SMS_API_TOKEN': 'mine'});
    expect(local().requiredSecrets, ['SMS_API_TOKEN']);
  });

  test('what one deployment needs is not asked of a laptop', () {
    writeConfig('''
requires:
  secrets: [SMS_API_TOKEN]

staging:
  host: 203.0.113.10
  requires:
    secrets: [SENTRY_DSN]
''');

    expect(local().requiredSecrets, ['SMS_API_TOKEN']);
  });

  test('storing a value creates the git-ignored file when it is absent', () {
    writeConfig('local:\n  DW_DATABASE_PORT: 8090\n');

    local().store('SMS_API_TOKEN', 'a-token');

    expect(local().mine, {'SMS_API_TOKEN': 'a-token'});
    expect(
      File(p.join(root.path, 'deploy', 'secrets.yaml')).readAsStringSync(),
      contains('Git-ignored'),
    );
  });

  test('storing twice replaces the line rather than duplicating the key', () {
    writeSecrets("local:\n  SMS_API_TOKEN: 'first'\n");

    local()
      ..store('SMS_API_TOKEN', 'second')
      ..store('OTHER_TOKEN', 'also');

    expect(local().mine, {'SMS_API_TOKEN': 'second', 'OTHER_TOKEN': 'also'});
  });

  test('another environment is left alone', () {
    writeSecrets("staging:\n  SMS_API_TOKEN: 'theirs'\n");

    local().store('SMS_API_TOKEN', 'mine');

    expect(local().mine, {'SMS_API_TOKEN': 'mine'});
    expect(
      File(p.join(root.path, 'deploy', 'secrets.yaml')).readAsStringSync(),
      contains("theirs"),
    );
  });

  test('a project with neither file answers empty, not an error', () {
    expect(local().committed, isEmpty);
    expect(local().mine, isEmpty);
    expect(local().requiredSecrets, isEmpty);
  });

  test('a section that is not a map is refused by name', () {
    writeConfig('local: 8090\n');

    expect(
      () => local().committed,
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('deploy/config.yaml > local'),
        ),
      ),
    );
  });
}
