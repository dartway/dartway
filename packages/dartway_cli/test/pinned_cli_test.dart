import 'dart:convert';
import 'dart:io';

import 'package:dartway_cli/src/pinned_cli.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// A project pins its CLI like everything else of the framework. This is how
/// a `dartway` that is not that one finds out — before it writes anything.
void main() {
  late Directory temp;
  setUp(() => temp = Directory.systemTemp.createTempSync('dw_pinned_cli_'));
  tearDown(() => temp.deleteSync(recursive: true));

  /// A package with a pubspec of [version] at [path], and the answer of
  /// `Platform.script` for a CLI living in it.
  Uri package(String path, String version) {
    final root = Directory(p.join(temp.path, path))..createSync(recursive: true);
    File(p.join(root.path, 'pubspec.yaml'))
        .writeAsStringSync('name: dartway_cli\nversion: $version\n');
    final bin = Directory(p.join(root.path, 'bin'))..createSync();
    return File(p.join(bin.path, 'dartway.dart')).uri;
  }

  /// A project at [root] whose package config resolves dartway_cli to
  /// [cliRoot].
  Directory project(String cliRoot, {String? inPackage}) {
    final root = Directory(p.join(temp.path, 'shop'))..createSync();
    final owner = inPackage == null
        ? root
        : (Directory(p.join(root.path, inPackage))..createSync());
    final tool = Directory(p.join(owner.path, '.dart_tool'))..createSync();
    File(p.join(tool.path, 'package_config.json')).writeAsStringSync(
      jsonEncode({
        'configVersion': 2,
        'packages': [
          {'name': 'shop_flutter', 'rootUri': '../'},
          {'name': 'dartway_cli', 'rootUri': p.join(temp.path, cliRoot)},
        ],
      }),
    );
    return root;
  }

  test('the CLI a project pins and the one that is running are the same, and '
      'nothing is said', () {
    final script = package('cli', '0.10.1');
    final root = project('cli');
    final pinned = DwPinnedCli.of(root, script: script);
    expect(pinned.pinnedVersion, '0.10.1');
    expect(pinned.runningVersion, '0.10.1');
    expect(pinned.isPinnedOne, isTrue);
  });

  test('a global CLI older than the project it stands in is refused, and the '
      'message is the command that would have worked', () {
    final script = package('global/dartway_cli-0.10.0', '0.10.0');
    final root = project('cli');
    package('cli', '0.11.0');
    final pinned = DwPinnedCli.of(root, script: script);
    expect(pinned.isPinnedOne, isFalse);
    expect(
      pinned.complaintFor('generate --check'),
      allOf(
        contains('0.11.0'),
        contains('0.10.0'),
        contains('dart run dartway_cli:dartway generate --check'),
      ),
    );
  });

  test('the pin is found in the Flutter package too, which is where a '
      'project keeps it', () {
    final script = package('cli', '0.10.1');
    final root = project('cli', inPackage: 'shop_flutter');
    expect(DwPinnedCli.of(root, script: script).pinnedVersion, '0.10.1');
  });

  test('a directory that pins nothing disagrees with nothing: create and '
      'quickstart run where there is no project yet', () {
    final script = package('cli', '0.10.1');
    final root = Directory(p.join(temp.path, 'empty'))..createSync();
    final pinned = DwPinnedCli.of(root, script: script);
    expect(pinned.pinnedVersion, isNull);
    expect(pinned.isPinnedOne, isTrue);
  });

  test('a package config naming a CLI that is not there is not a pin', () {
    final script = package('cli', '0.10.1');
    final root = project('gone');
    expect(DwPinnedCli.of(root, script: script).pinnedVersion, isNull);
  });
}
