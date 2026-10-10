import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Every `example/…` and `template/…` path the toolkit and the docs name
/// exists in this tree.
///
/// A skill points at a real file instead of copying a long sample into its
/// prose, and the toolkit ships into every project: a file renamed in
/// `example/` or `template/` would otherwise leave a dead pointer in all of
/// them, with nothing failing. Three spellings are read:
///
/// - a path from the repository root — `example/dartway_example_server/…`,
///   `template/dartway_starter_flutter/…`;
/// - a link to it on GitHub — `…/dartway/dartway/blob/master/example/…`;
/// - a toolkit path under a package token — `__SERVER_PKG__/lib/src/…` —
///   which a project receives from the skeleton, so it is checked against
///   `template/`.
///
/// A path is read up to the first character a file name here does not use,
/// so a placeholder (`lib/src/<feature>/`) or a glob (`template/*/…`) is
/// checked as far as it is literal. `docs/1.0/` is the rewrite's record and
/// quotes paths that were renamed since; it is not read.
void main() {
  final root = _repositoryRoot();

  const tokens = {
    '__SHARED_PKG__': 'template/dartway_starter_shared',
    '__SERVER_PKG__': 'template/dartway_starter_server',
    '__FLUTTER_PKG__': 'template/dartway_starter_flutter',
  };

  final files = [
    for (final folder in ['toolkit', 'docs'])
      ...Directory(p.join(root.path, folder))
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.md'))
          .where(
            (file) => !p.isWithin(p.join(root.path, 'docs', '1.0'), file.path),
          ),
  ]..sort((a, b) => a.path.compareTo(b.path));

  /// `path — file:line` for every named path that does not resolve.
  List<String> deadPathsIn(File file) {
    final where = p.relative(file.path, from: root.path);
    final dead = <String>[];
    final lines = file.readAsLinesSync();
    for (var index = 0; index < lines.length; index++) {
      final line = lines[index];
      final named = <String>{
        for (final match in _rootPath.allMatches(line)) match.group(1)!,
        for (final match in _githubPath.allMatches(line)) match.group(1)!,
        for (final match in _tokenPath.allMatches(line))
          '${tokens[match.group(1)]!}${match.group(2) ?? ''}',
      };
      for (final path in named) {
        final trimmed = path.replaceFirst(RegExp(r'[.\-]+$'), '');
        final resolved = p.join(root.path, trimmed);
        if (FileSystemEntity.typeSync(resolved) ==
            FileSystemEntityType.notFound) {
          dead.add('$trimmed — $where:${index + 1}');
        }
      }
    }
    return dead;
  }

  test('reads the toolkit and the docs', () {
    // A guard against the walk finding nothing and passing on that.
    expect(files.length, greaterThan(20));
    expect(
      files.map((file) => p.relative(file.path, from: root.path)),
      contains('toolkit/CLAUDE.md'),
    );
  });

  test('every example/ and template/ path they name resolves', () {
    expect(
      [for (final file in files) ...deadPathsIn(file)],
      isEmpty,
      reason:
          'named in the prose, absent from the tree — renamed or removed; '
          'point at the file that holds it now',
    );
  });
}

/// `example/…` or `template/…` from the repository root: not the tail of a
/// longer path (`packages/dartway_lints/example`) or of a word.
final _rootPath = RegExp(r'(?<![\w./-])((?:example|template)/[\w./-]*)');

/// The same path in a link to this repository on GitHub.
final _githubPath = RegExp(
  r'github\.com/dartway/dartway/(?:blob|tree)/[\w.-]+/((?:example|template)/[\w./-]*)',
);

/// A skeleton path under a package token.
final _tokenPath = RegExp(r'(__(?:SHARED|SERVER|FLUTTER)_PKG__)(/[\w./-]*)?');

Directory _repositoryRoot() {
  var dir = Directory.current.absolute;
  while (true) {
    if (Directory(p.join(dir.path, 'toolkit', 'skills')).existsSync() &&
        Directory(p.join(dir.path, 'template')).existsSync()) {
      return dir;
    }
    final up = dir.parent;
    if (up.path == dir.path) {
      throw StateError('no repository root above ${Directory.current.path}');
    }
    dir = up;
  }
}
