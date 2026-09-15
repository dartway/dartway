import 'dart:io';

import 'package:dartway_cli/src/checker/dw_check_type.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// The law list `toolkit/CLAUDE.md` publishes is the checker's `error` set.
///
/// The harness draws its one hard line there — a law is not a project's to
/// override, a default is — and it draws it by naming checks. The naming is a
/// copy: the checks themselves live in [DwCheckType.severity], one `switch`
/// statement away, and nothing makes the two agree.
///
/// Both directions of the drift are silent and both are worse than a missing
/// list. A check promoted to `error` and never added here is a law nobody was
/// told about, enforced by a red build against a rule the project could not
/// read. A check softened to a warning and left in the table is the opposite:
/// the harness forbids a project to decide something the framework has already
/// stopped holding it to — which is the exact failure the section was written
/// to end.
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

  final claudeMd = File(p.join(toolkit.path, 'CLAUDE.md')).readAsLinesSync();

  /// The rows of the table headed "Checks that fail", as one string.
  String lawTable() {
    final header = claudeMd.indexWhere(
      (line) => line.startsWith('|') && line.contains('Checks that fail'),
    );
    if (header < 0) {
      throw StateError('no law table in toolkit/CLAUDE.md');
    }
    // Past the header and its `|---|---|` separator, up to the blank line.
    final rows = claudeMd
        .skip(header + 2)
        .takeWhile((line) => line.startsWith('|'));
    return rows.join('\n');
  }

  test('the law table names every failing check, and only those', () {
    final failing = DwCheckType.values
        .where((check) => check.severity == DwCheckSeverity.error)
        .map((check) => check.name)
        .toSet();

    final named = RegExp(
      // Digits included: `l10nNotWired` is a check name.
      r'`([a-z][A-Za-z0-9]+)`',
    ).allMatches(lawTable()).map((match) => match.group(1)!).toSet();

    expect(
      named.difference(failing),
      isEmpty,
      reason:
          'named as law in toolkit/CLAUDE.md, but the checker does not fail '
          'on it — a project is being forbidden to decide something the '
          'framework only warns about',
    );
    expect(
      failing.difference(named),
      isEmpty,
      reason:
          'the checker fails on it and toolkit/CLAUDE.md does not name it — '
          'a law a project first meets as a red build',
    );
  });

  test('the counts stated around the table are the counts', () {
    // Spelled out in the prose, so they are read rather than skimmed past.
    // Reword the sentences freely; the numbers in them have to stay true.
    const words = {
      1: 'one',
      2: 'two',
      3: 'three',
      4: 'four',
      5: 'five',
      6: 'six',
      7: 'seven',
      8: 'eight',
      9: 'nine',
      10: 'ten',
      11: 'eleven',
      12: 'twelve',
      13: 'thirteen',
      14: 'fourteen',
      15: 'fifteen',
    };

    int countOf(DwCheckSeverity severity) =>
        DwCheckType.values.where((check) => check.severity == severity).length;

    final section = claudeMd
        .skipWhile(
          (line) => !line.contains('The law list is therefore derived'),
        )
        .takeWhile((line) => !line.startsWith('## '))
        .join('\n')
        .toLowerCase();

    for (final severity in [DwCheckSeverity.error, DwCheckSeverity.warning]) {
      final word = words[countOf(severity)];
      expect(
        // Whole word only: "written" carries a "ten" that means nothing.
        word != null && RegExp('\\b$word\\b').hasMatch(section),
        isTrue,
        reason:
            'toolkit/CLAUDE.md does not say "$word" anywhere around the law '
            'table, and that is how many checks are ${severity.name}',
      );
    }
  });
}
