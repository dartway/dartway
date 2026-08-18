import 'dart:io';

import 'package:dartway_cli/src/checker/dw_framework_lock.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// A project that consumes DartWay by git writes `ref: master` on every
/// framework package, which reads as "all of it from master" and is not what
/// the lock does: each package is pinned at the commit master happened to be on
/// when *that* package was added. There is no version number on a git
/// dependency, so nothing else in the project says the halves have drifted.
///
/// The cases worth defending are the two ends: refs that agree must stay quiet
/// (a rule that cries on a healthy project gets turned off), and refs that
/// disagree must name the packages *and* the directories, because the fix is a
/// command run in a particular place.
void main() {
  late Directory sandbox;

  setUp(() {
    sandbox = Directory.systemTemp.createTempSync('dw_framework_lock');
  });

  tearDown(() {
    sandbox.deleteSync(recursive: true);
  });

  const dartwayUrl = 'https://github.com/dartway/dartway.git';

  /// One `packages:` entry of a `pubspec.lock`, as pub writes it.
  String gitEntry(
    String name, {
    required String resolvedRef,
    String url = dartwayUrl,
    String version = '0.0.0',
  }) =>
      '  $name:\n'
      '    dependency: "direct main"\n'
      '    description:\n'
      '      path: "packages/$name"\n'
      '      ref: master\n'
      '      resolved-ref: "$resolvedRef"\n'
      '      url: "$url"\n'
      '    source: git\n'
      '    version: "$version"\n';

  /// Writes `<package>/pubspec.lock` holding [entries].
  void writeLock(String package, List<String> entries) {
    final dir = Directory(p.join(sandbox.path, package))
      ..createSync(recursive: true);
    File(p.join(dir.path, 'pubspec.lock')).writeAsStringSync(
      'packages:\n${entries.join()}sdks:\n  dart: ">=3.11.0 <4.0.0"\n',
    );
  }

  List<String> findings() {
    final inspector = DwFrameworkLockInspector(projectRoot: sandbox);
    inspector.run();
    return inspector.findings;
  }

  test('one commit across every package says nothing', () {
    writeLock('my_flutter', [
      gitEntry('dartway_flutter', resolvedRef: 'a' * 40),
      gitEntry('dartway_serverpod_core_flutter', resolvedRef: 'a' * 40),
    ]);
    writeLock('my_server', [
      gitEntry('dartway_serverpod_core_server', resolvedRef: 'a' * 40),
    ]);

    expect(findings(), isEmpty);
  });

  test('two commits are reported, with the packages and where they live', () {
    writeLock('my_flutter', [
      gitEntry('dartway_flutter', resolvedRef: 'abcdef1${'0' * 33}'),
    ]);
    writeLock('my_server', [
      gitEntry(
        'dartway_serverpod_core_server',
        resolvedRef: '9876543${'0' * 33}',
      ),
    ]);

    final reported = findings();
    expect(reported, hasLength(1));
    expect(reported.single, contains('2 different commits'));
    expect(reported.single, contains('abcdef1'));
    expect(reported.single, contains('9876543'));
    expect(reported.single, contains('dartway_flutter in my_flutter'));
    expect(
      reported.single,
      contains('dartway_serverpod_core_server in my_server'),
    );
    // The fix is a command, and a command has to be run somewhere.
    expect(reported.single, contains('my_flutter, my_server'));
  });

  test('the divergence is caught inside a single package too', () {
    writeLock('my_flutter', [
      gitEntry('dartway_flutter', resolvedRef: 'a' * 40),
      gitEntry('dartway_push_flutter', resolvedRef: 'b' * 40),
    ]);

    expect(findings(), hasLength(1));
  });

  test('different repositories are not compared with each other', () {
    writeLock('my_flutter', [
      gitEntry('dartway_flutter', resolvedRef: 'a' * 40),
      gitEntry(
        'dartway_something_else',
        resolvedRef: 'b' * 40,
        url: 'https://github.com/someone/other.git',
      ),
    ]);

    expect(findings(), isEmpty);
  });

  test('hosted and path packages are outside the question', () {
    // Semver already answers it for a hosted package, and a path dependency is
    // somebody deliberately working on the framework.
    writeLock('my_flutter', [
      gitEntry('dartway_flutter', resolvedRef: 'a' * 40),
      '  dartway_lints:\n'
          '    dependency: "direct dev"\n'
          '    description:\n'
          '      name: dartway_lints\n'
          '      sha256: "0000"\n'
          '      url: "https://pub.dev"\n'
          '    source: hosted\n'
          '    version: "0.3.0"\n',
      '  dartway_studio_bridge:\n'
          '    dependency: "direct main"\n'
          '    description:\n'
          '      path: "../../dartway/packages/dartway_studio_bridge"\n'
          '      relative: true\n'
          '    source: path\n'
          '    version: "0.7.1"\n',
    ]);

    expect(findings(), isEmpty);
  });

  test('a project with no framework git dependencies is not a finding', () {
    writeLock('my_flutter', [
      '  flutter_svg:\n'
          '    dependency: "direct main"\n'
          '    description:\n'
          '      name: flutter_svg\n'
          '      sha256: "0000"\n'
          '      url: "https://pub.dev"\n'
          '    source: hosted\n'
          '    version: "2.0.10"\n',
    ]);

    expect(findings(), isEmpty);
  });

  test('a lock file that does not parse is nobody\'s finding', () {
    final dir = Directory(p.join(sandbox.path, 'my_flutter'))
      ..createSync(recursive: true);
    File(
      p.join(dir.path, 'pubspec.lock'),
    ).writeAsStringSync('packages:\n  broken: [unclosed\n');

    expect(findings, returnsNormally);
    expect(findings(), isEmpty);
  });

  test('a project with no lock files at all is silent', () {
    expect(findings(), isEmpty);
  });
}
