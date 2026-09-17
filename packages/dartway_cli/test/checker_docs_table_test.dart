import 'dart:io';

import 'package:dartway_cli/src/checker/dw_check_type.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// `docs/5-tooling/conventions-checker.md` lists every check with its level,
/// and a reader decides from that table whether a finding can fail their
/// build. The levels live in [DwCheckType.severity]; the table is a copy, and
/// a copy nobody compares drifts the first time a check changes level (#217).
void main() {
  final page = () {
    var dir = Directory.current.absolute;
    while (true) {
      final candidate = File(
        p.join(dir.path, 'docs', '5-tooling', 'conventions-checker.md'),
      );
      if (candidate.existsSync()) return candidate;
      final up = dir.parent;
      if (up.path == dir.path) {
        throw StateError('no docs/ above ${Directory.current.path}');
      }
      dir = up;
    }
  }();
  final lines = page.readAsLinesSync();

  /// The table under "## The checks": check name to the level it states.
  Map<String, String> table() {
    final header = lines.indexWhere(
      (line) => line.startsWith('| Check | Level |'),
    );
    if (header < 0) throw StateError('no checks table in ${page.path}');
    return {
      for (final row
          in lines.skip(header + 2).takeWhile((line) => line.startsWith('|')))
        RegExp(r'^\| `(\w+)` \|').firstMatch(row)!.group(1)!: row
            .split('|')[2]
            .trim(),
    };
  }

  test('names every check once, at the level the checker gives it', () {
    expect(table(), {
      for (final check in DwCheckType.values) check.name: check.severity.name,
    });
  });

  test('counts its levels in the sentence above it', () {
    String words(int count) => const [
      'No',
      'One',
      'Two',
      'Three',
      'Four',
      'Five',
      'Six',
      'Seven',
      'Eight',
      'Nine',
      'Ten',
      'Eleven',
      'Twelve',
      'Thirteen',
      'Fourteen',
      'Fifteen',
    ][count].toLowerCase();
    int of(DwCheckSeverity level) =>
        DwCheckType.values.where((check) => check.severity == level).length;
    final errors = of(DwCheckSeverity.error);
    final warnings = of(DwCheckSeverity.warning);
    final infos = of(DwCheckSeverity.info);
    final sentence =
        '${words(errors)} error${errors == 1 ? '' : 's'}, '
        '${words(warnings)} warning${warnings == 1 ? '' : 's'}, '
        '${words(infos)} info';
    expect(
      lines.any((line) => line.toLowerCase().startsWith(sentence)),
      isTrue,
      reason: 'expected a line starting "$sentence"',
    );
  });
}
