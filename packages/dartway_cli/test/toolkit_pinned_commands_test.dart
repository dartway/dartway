import 'dart:io';

import 'package:dartway_cli/src/pinned_cli.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// The toolkit, the README every project is created with, and the public
/// documentation teach the commands the CLI runs.
///
/// A project command — [DwPinnedCli.projectCommands] — runs the CLI the
/// project pins whichever `dartway` is typed: one of another version hands
/// it over (#643). So there is one way to type it, `dartway <command>`, and
/// the long `dart run dartway_cli:dartway <command>` that a refusing global
/// CLI once forced into 126 places of the toolkit (#289) is a second way,
/// taught nowhere but in a CI workflow, where no global CLI is installed.
///
/// Code is what gets typed, so code is what is held: a fenced block (but a
/// YAML one, which is a workflow), or an inline code span, naming a project
/// command after `dart run dartway_cli:dartway`. Prose naming the tool is
/// left alone. The set of commands is the CLI's own, read rather than
/// repeated.
///
/// One line is the exception, and it is one: `toolkit/AGENTS.md` says that
/// without a global CLI the same command is run as
/// `dart run dartway_cli:dartway <args>` from the project root.
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

  final long = RegExp(
    'dart run dartway_cli:dartway '
    '(?:(?:${DwPinnedCli.projectCommands.join('|')})\\b|<)',
  );

  /// The one place the long form is taught: the fallback for a machine
  /// without a global CLI.
  const fallback = 'Without a global CLI, run the same command as';
  final fallbackFile = p.join(repository.path, 'toolkit', 'AGENTS.md');

  /// `path:line: text` for every long-form project command in [file] outside
  /// a workflow.
  List<String> findingsIn(File file) {
    final findings = <String>[];
    var fenced = false;
    var workflow = false;
    final lines = file.readAsLinesSync();
    for (var index = 0; index < lines.length; index++) {
      final line = lines[index];
      if (line.trimLeft().startsWith('```')) {
        fenced = !fenced;
        workflow =
            fenced &&
            const {'yaml', 'yml'}.contains(line.trimLeft().substring(3).trim());
        continue;
      }
      if (workflow) continue;
      // A heading names the command a section is about; it is not typed.
      if (!fenced && line.startsWith('#')) continue;
      if (file.path == fallbackFile && line.startsWith(fallback)) continue;
      for (final match in long.allMatches(line)) {
        // `<command>` in the documentation describes the fallback; in the
        // toolkit, which the agent copies from, it is the one line above.
        if (match.group(0)!.endsWith('<') &&
            !p.isWithin(p.join(repository.path, 'toolkit'), file.path)) {
          continue;
        }
        final inCode =
            fenced ||
            '`'.allMatches(line.substring(0, match.start)).length.isOdd;
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

  test('no command block teaches the long form of a project command', () {
    final files = [
      ...Directory(p.join(repository.path, 'toolkit'))
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.md')),
      File(p.join(repository.path, 'template', 'README.md')),
      File(p.join(repository.path, 'template', 'CLAUDE.md')),
      // The public documentation too, but not the rewrite's record nor the
      // migration notes, whose before-and-after lines quote what was.
      ...Directory(p.join(repository.path, 'docs'))
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.md'))
          .where((file) {
            final relative = p.relative(file.path, from: repository.path);
            return !p.isWithin('docs/1.0', relative) &&
                !p.isWithin('docs/migrations', relative);
          }),
    ];
    final findings = [for (final file in files) ...findingsIn(file)];
    expect(
      findings,
      isEmpty,
      reason:
          'write `dartway <command>`: it runs the CLI the project pins '
          'whichever `dartway` is on the PATH',
    );
  });

  test('the fallback for a machine without a global CLI is taught once, in '
      'the toolkit constitution', () {
    final lines = File(fallbackFile).readAsLinesSync();
    final at = [
      for (var i = 0; i < lines.length; i++)
        if (lines[i].startsWith(fallback)) i,
    ];
    expect(at, hasLength(1));
    expect(
      lines[at.single],
      contains('`dart run dartway_cli:dartway <args>` from the project root'),
    );
  });
}
