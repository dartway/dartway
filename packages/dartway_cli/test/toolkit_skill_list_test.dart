import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// The skills `toolkit/CLAUDE.md` names are the skills that exist.
///
/// The harness constitution lists them so an agent knows what it may reach
/// for, and the installer ships whatever directories are there — it walks
/// `toolkit/skills/` rather than reading the list. So the two can part without
/// anything failing: a skill that ships and is never named is a skill nobody
/// loads, and a name with no directory behind it sends an agent looking for a
/// file that is not installed.
///
/// Neither shows up as an error anywhere. This is the only thing that compares
/// them.
void main() {
  final toolkit = () {
    var dir = Directory.current.absolute;
    while (true) {
      final candidate = Directory(p.join(dir.path, 'toolkit', 'skills'));
      if (candidate.existsSync()) {
        return Directory(p.join(dir.path, 'toolkit'));
      }
      final up = dir.parent;
      if (up.path == dir.path) {
        throw StateError('no toolkit/ above ${Directory.current.path}');
      }
      dir = up;
    }
  }();

  test('CLAUDE.md names every shipped skill, and only those', () {
    final onDisk = Directory(p.join(toolkit.path, 'skills'))
        .listSync()
        .whereType<Directory>()
        .map((directory) => p.basename(directory.path))
        .where((name) => name.startsWith('dartway-'))
        .toSet();

    // The line that lists them: a run of `dartway-*` in backticks on the
    // "Skills (`.claude/skills/`)" bullet.
    final line = File(p.join(toolkit.path, 'CLAUDE.md'))
        .readAsLinesSync()
        .firstWhere(
          (line) => line.contains('Skills (`.claude/skills/`)'),
          orElse: () => throw StateError('no skills line in toolkit/CLAUDE.md'),
        );
    final named = RegExp(
      r'`(dartway-[a-z-]+)`',
    ).allMatches(line).map((match) => match.group(1)!).toSet();

    expect(
      named.difference(onDisk),
      isEmpty,
      reason: 'named in toolkit/CLAUDE.md but not shipped',
    );
    expect(
      onDisk.difference(named),
      isEmpty,
      reason:
          'shipped but not named in toolkit/CLAUDE.md — an agent will not '
          'know it exists, and the installer ships it anyway',
    );
  });
}
