import 'dart:io';

import 'package:dartway_cli/src/pinned_cli.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// The toolkit, and the README every project is created with, teach the
/// commands the CLI runs.
///
/// A project command — [DwPinnedCli.projectCommands] — refuses to run from a
/// `dartway` that is not the one the project pins, and names the form that
/// is: `dart run dartway_cli:dartway <command>`. The toolkit ships into every
/// project's `.claude/` and taught the bare `dartway <command>` in 126 places,
/// so an agent following a skill typed the refused form on day one (#289).
///
/// Code is what gets typed, so code is what is held: a fenced block, or an
/// inline code span, naming a project command after a bare `dartway`. Prose
/// naming the tool is left alone. The set of commands is the CLI's own, read
/// rather than repeated.
void main() {
  final repository = () {
    var dir = Directory.current.absolute;
    while (true) {
      if (Directory(p.join(dir.path, 'toolkit', 'skills')).existsSync()) {
        return dir;
      }
      final up = dir.parent;
      if (up.path == dir.path) {
        throw StateError('no toolkit/ above ${Directory.current.path}');
      }
      dir = up;
    }
  }();

  final bare = RegExp(
    '(?<![\\w:/.-])dartway (${DwPinnedCli.projectCommands.join('|')})\\b',
  );

  /// `path:line: text` for every runnable bare project command in [file].
  List<String> findingsIn(File file) {
    final findings = <String>[];
    var fenced = false;
    final lines = file.readAsLinesSync();
    for (var index = 0; index < lines.length; index++) {
      final line = lines[index];
      if (line.trimLeft().startsWith('```')) {
        fenced = !fenced;
        continue;
      }
      for (final match in bare.allMatches(line)) {
        final inCode =
            fenced || '`'.allMatches(line.substring(0, match.start)).length.isOdd;
        if (inCode) {
          findings.add(
            '${p.relative(file.path, from: repository.path)}:${index + 1}: '
            '${line.trim()}',
          );
        }
      }
    }
    return findings;
  }

  test('no command block teaches the bare form a project command refuses',
      () {
    final files = [
      ...Directory(p.join(repository.path, 'toolkit'))
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.md')),
      File(p.join(repository.path, 'template', 'README.md')),
      File(p.join(repository.path, 'template', 'CLAUDE.md')),
    ];
    final findings = [for (final file in files) ...findingsIn(file)];
    expect(
      findings,
      isEmpty,
      reason:
          'write `dart run dartway_cli:dartway <command>` — the CLI the '
          'project pins; a bare `dartway` refuses these',
    );
  });
}
