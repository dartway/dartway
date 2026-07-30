import 'dart:io';

import 'package:dartway_cli/src/deploy/master_passwords_file.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  late Directory sandbox;

  setUp(() {
    sandbox = Directory.systemTemp.createTempSync('dw_master_passwords');
  });

  tearDown(() {
    sandbox.deleteSync(recursive: true);
  });

  DwMasterPasswordsFile fileWith(String content) {
    final file = File(p.join(sandbox.path, 'passwords.yaml'))
      ..writeAsStringSync(content);
    return DwMasterPasswordsFile(file);
  }

  const sample = '''
# Master copy — every environment.
shared:
  unisenderKey: ''
  AWSAccessKeyId: 'AKIA'

development:
  database: 'dev-pass'
  # Empty while test mode is on.
  dwTinkoffPassword: ''

production:
  database: ''
  serviceSecret: ''
''';

  test('replaces an empty placeholder instead of duplicating the key', () {
    final master = fileWith(sample);

    master.write({
      'production': {'database': 'live-pass', 'serviceSecret': 'live-secret'},
    });

    // The regression this guards: appending a second "database:" line makes a
    // duplicate mapping key, and the file stops parsing entirely.
    final document = loadYaml(master.file.readAsStringSync()) as YamlMap;
    final production = document['production'] as YamlMap;
    expect(production['database'], 'live-pass');
    expect(production['serviceSecret'], 'live-secret');

    final databaseLines = master.file
        .readAsLinesSync()
        .where((line) => line.trim().startsWith('database:'))
        .length;
    expect(databaseLines, 2, reason: 'one in development, one in production');
  });

  test('inserts keys the section does not have', () {
    final master = fileWith(sample);

    master.write({
      'production': {'dwAuthKeySalt': 'salt'},
    });

    final document = loadYaml(master.file.readAsStringSync()) as YamlMap;
    expect((document['production'] as YamlMap)['dwAuthKeySalt'], 'salt');
    expect((document['production'] as YamlMap)['database'], '');
  });

  test('leaves other sections untouched', () {
    final master = fileWith(sample);

    master.write({
      'production': {'database': 'live'},
    });

    final document = loadYaml(master.file.readAsStringSync()) as YamlMap;
    expect((document['development'] as YamlMap)['database'], 'dev-pass');
    expect((document['shared'] as YamlMap)['AWSAccessKeyId'], 'AKIA');
  });

  test('keeps comments', () {
    final master = fileWith(sample);

    master.write({
      'production': {'database': 'live'},
    });

    final text = master.file.readAsStringSync();
    expect(text, contains('# Master copy'));
    expect(text, contains('# Empty while test mode is on.'));
  });

  test('appends a section that does not exist', () {
    final master = fileWith(sample);

    master.write({
      'staging': {'database': 'staging-pass'},
    });

    final document = loadYaml(master.file.readAsStringSync()) as YamlMap;
    expect((document['staging'] as YamlMap)['database'], 'staging-pass');
    expect(document.keys, containsAll(['shared', 'development', 'production']));
  });

  test('encodes values that would otherwise break the file', () {
    final master = fileWith(sample);

    master.write({
      'production': {'database': "p'wd: with #hash"},
    });

    final document = loadYaml(master.file.readAsStringSync()) as YamlMap;
    expect((document['production'] as YamlMap)['database'], "p'wd: with #hash");
  });

  test('effective merges shared under the run mode', () {
    final master = fileWith(sample);
    final sections = master.read()!;

    final development = DwMasterPasswordsFile.effective(
      sections,
      'development',
    );
    expect(development['AWSAccessKeyId'], 'AKIA');
    expect(development['database'], 'dev-pass');

    final production = DwMasterPasswordsFile.effective(sections, 'production');
    expect(production['database'], '', reason: 'run mode wins over shared');
  });

  test('write is idempotent', () {
    final master = fileWith(sample);
    final values = {
      'production': {'database': 'live'},
    };

    master.write(values);
    final once = master.file.readAsStringSync();
    master.write(values);
    expect(master.file.readAsStringSync(), once);
  });
}
