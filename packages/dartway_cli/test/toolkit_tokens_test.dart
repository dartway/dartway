import 'dart:io';

import 'package:dartway_cli/src/project_layout.dart';
import 'package:dartway_cli/src/toolkit_installer.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Every `__TOKEN__` the toolkit writes is filled with a real name when it is
/// installed.
///
/// An unfilled token is not a crash but a sentence: the installer once filled
/// `__CLIENT_PKG__` with an empty string for a project that has no client
/// package, and the skills told the agent to format `..//lib/src/protocol`.
/// So this holds the whole path — the toolkit of this checkout, a project laid
/// out as `dartway create` lays it out, and the installed files read back —
/// and the installer's own refusal of a toolkit it cannot fill.
void main() {
  final repository = () {
    var dir = Directory.current.absolute;
    while (!Directory(p.join(dir.path, 'toolkit')).existsSync() ||
        !Directory(p.join(dir.path, 'packages')).existsSync()) {
      final up = dir.parent;
      if (up.path == dir.path) throw StateError('not inside the monorepo');
      dir = up;
    }
    return dir;
  }();

  late Directory sandbox;

  setUp(() => sandbox = Directory.systemTemp.createTempSync('dw_tokens'));
  tearDown(() => sandbox.deleteSync(recursive: true));

  Directory projectIn(Directory root) {
    for (final package in ['shop_shared', 'shop_server', 'shop_flutter']) {
      Directory(p.join(root.path, package)).createSync(recursive: true);
    }
    return root;
  }

  List<String> leftovers(Directory root) => [
    for (final entity in root.listSync(recursive: true))
      if (entity is File)
        for (final match in RegExp(
          r'__[A-Za-z0-9]+(?:_[A-Za-z0-9]+)*__',
        ).allMatches(entity.readAsStringSync()))
          '${p.relative(entity.path, from: root.path)}: ${match.group(0)}',
  ];

  test('the toolkit of this checkout installs with no token left', () async {
    final project = projectIn(sandbox);
    await ToolkitInstaller.install(
      toolkitDir: Directory(p.join(repository.path, 'toolkit')),
      projectRoot: project,
      tokens: ProjectLayout.detect(project).toolkitTokens(baseBranch: 'master'),
    );

    expect(leftovers(Directory(p.join(project.path, '.claude'))), isEmpty);
    expect(
      leftovers(Directory(p.join(project.path, 'docs', 'dev_notes'))),
      isEmpty,
    );
    expect(
      File(p.join(project.path, '.claude', 'CLAUDE.md')).readAsStringSync(),
      contains('shop_shared'),
    );
  });

  test('every token is filled with a name, never with nothing', () {
    final tokens = ProjectLayout.detect(
      projectIn(sandbox),
    ).toolkitTokens(baseBranch: 'master');

    expect(tokens.values, everyElement(isNotEmpty));
    expect(tokens.keys, everyElement(matches(ToolkitInstaller.tokenPattern)));
  });

  test('a project without its shared package is not a DartWay project', () {
    Directory(p.join(sandbox.path, 'shop_server')).createSync();
    Directory(p.join(sandbox.path, 'shop_flutter')).createSync();

    expect(
      () => ProjectLayout.detect(sandbox),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('*_shared'),
        ),
      ),
    );
  });

  test('a toolkit naming a token the CLI does not fill is refused before '
      'anything is written', () async {
    final toolkit = Directory(p.join(sandbox.path, 'toolkit'))..createSync();
    Directory(p.join(toolkit.path, 'commands')).createSync();
    File(p.join(toolkit.path, 'skills', 'dartway-x', 'SKILL.md'))
      ..createSync(recursive: true)
      ..writeAsStringSync('format ../__CLIENT_PKG__/lib/src/protocol\n');
    File(p.join(toolkit.path, 'CLAUDE.md')).writeAsStringSync('harness\n');

    final project = projectIn(
      Directory(p.join(sandbox.path, 'project'))..createSync(),
    );
    final existing = File(p.join(project.path, '.claude', 'CLAUDE.md'))
      ..createSync(recursive: true)
      ..writeAsStringSync('installed before\n');

    await expectLater(
      ToolkitInstaller.install(
        toolkitDir: toolkit,
        projectRoot: project,
        tokens: ProjectLayout.detect(
          project,
        ).toolkitTokens(baseBranch: 'master'),
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('skills/dartway-x/SKILL.md: __CLIENT_PKG__'),
        ),
      ),
    );
    expect(existing.readAsStringSync(), 'installed before\n');
  });
}
