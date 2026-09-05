import 'dart:io';

import 'package:dartway_cli/src/framework_versions.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Where a project stands against the framework, read out of the two files
/// that actually say so: the project's lock files and the packages' own
/// pubspecs.
///
/// The case that makes this worth testing is a project whose halves disagree.
/// A Flutter package and a server package each carry their own lock, they are
/// upgraded at different times, and the half that is behind is the half that
/// still owes the migrations — so "which version is this project on" has to
/// mean the oldest copy, not whichever file was read last.
void main() {
  late Directory sandbox;

  setUp(() {
    sandbox = Directory.systemTemp.createTempSync('dw_framework_versions');
  });
  tearDown(() => sandbox.deleteSync(recursive: true));

  String hostedEntry(String name, String version) =>
      '  $name:\n'
      '    dependency: "direct main"\n'
      '    description:\n'
      '      name: $name\n'
      '      url: "https://pub.dev"\n'
      '    source: hosted\n'
      '    version: "$version"\n';

  String gitEntry(String name, String version) =>
      '  $name:\n'
      '    dependency: "direct main"\n'
      '    description:\n'
      '      path: "packages/$name"\n'
      '      ref: master\n'
      '      resolved-ref: "0123456789abcdef0123456789abcdef01234567"\n'
      '      url: "https://github.com/dartway/dartway.git"\n'
      '    source: git\n'
      '    version: "$version"\n';

  void writeLock(String package, List<String> entries) {
    final dir = Directory(p.join(sandbox.path, package))
      ..createSync(recursive: true);
    File(p.join(dir.path, 'pubspec.lock')).writeAsStringSync(
      'packages:\n${entries.join()}sdks:\n  dart: ">=3.11.0 <4.0.0"\n',
    );
  }

  void writePackage(String path, String name, String version) {
    final dir = Directory(p.join(sandbox.path, 'monorepo', 'packages', path))
      ..createSync(recursive: true);
    File(
      p.join(dir.path, 'pubspec.yaml'),
    ).writeAsStringSync('name: $name\nversion: $version\n');
  }

  Directory monorepo() => Directory(p.join(sandbox.path, 'monorepo'));

  group('readFrameworkVersions', () {
    test('reads packages one and two levels deep', () {
      // The multi-package modules — the core, push, offline — sit a directory
      // deeper than the single ones, and a walk that stopped at the first level
      // would silently report the core as absent.
      writePackage('dartway_flutter', 'dartway_flutter', '0.8.0');
      writePackage(
        p.join('dartway_serverpod_core', 'dartway_serverpod_core_server'),
        'dartway_serverpod_core_server',
        '0.12.1',
      );

      expect(readFrameworkVersions(monorepo()), {
        'dartway_flutter': '0.8.0',
        'dartway_serverpod_core_server': '0.12.1',
      });
    });

    test('ignores anything that is not a framework package', () {
      writePackage('something', 'some_helper', '1.0.0');
      expect(readFrameworkVersions(monorepo()), isEmpty);
    });
  });

  group('compareToFramework', () {
    test('the oldest copy is the version the project is on', () {
      writeLock('app_flutter', [hostedEntry('dartway_flutter', '0.8.0')]);
      writeLock('app_server', [hostedEntry('dartway_flutter', '0.4.0')]);

      final gaps = compareToFramework(
        projectRoot: sandbox,
        frameworkVersions: const {'dartway_flutter': '0.8.0'},
      );

      expect(gaps.single.projectVersion, '0.4.0');
      expect(gaps.single.isBehind, isTrue);
      expect(gaps.single.locations, ['app_flutter', 'app_server']);
    });

    test('a package that matches the framework is not behind', () {
      writeLock('app_flutter', [hostedEntry('dartway_router', '1.1.2')]);

      final gaps = compareToFramework(
        projectRoot: sandbox,
        frameworkVersions: const {'dartway_router': '1.1.2'},
      );

      expect(gaps.single.isBehind, isFalse);
    });

    test('versions compare numerically, not as text', () {
      // `0.11.0` sorts below `0.9.0` as text, and a report built on that would
      // send a project to redo a migration it has already applied.
      writeLock('app_flutter', [hostedEntry('dartway_flutter', '0.11.0')]);

      final gaps = compareToFramework(
        projectRoot: sandbox,
        frameworkVersions: const {'dartway_flutter': '0.9.0'},
      );

      expect(gaps.single.isBehind, isFalse);
      expect(gaps.single.isAhead, isTrue);
    });

    test('a git dependency states its version too, and is marked as git', () {
      // The instruction differs by source — a caret is edited, a git pin is
      // upgraded — so the report has to know which it is looking at.
      writeLock('app_flutter', [gitEntry('dartway_flutter', '0.4.0')]);

      final gaps = compareToFramework(
        projectRoot: sandbox,
        frameworkVersions: const {'dartway_flutter': '0.8.0'},
      );

      expect(gaps.single.fromGit, isTrue);
      expect(gaps.single.projectVersion, '0.4.0');
    });

    test('a package the project never asked for is not a gap', () {
      writeLock('app_flutter', [hostedEntry('dartway_flutter', '0.8.0')]);

      final gaps = compareToFramework(
        projectRoot: sandbox,
        frameworkVersions: const {
          'dartway_flutter': '0.8.0',
          'dartway_telegram': '0.2.0',
        },
      );

      expect(gaps.map((gap) => gap.name), ['dartway_flutter']);
    });
  });
}
