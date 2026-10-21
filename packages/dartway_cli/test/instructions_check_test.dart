import 'dart:io';

import 'package:dartway_cli/src/checker/dw_check_tally.dart';
import 'package:dartway_cli/src/checker/dw_check_type.dart';
import 'package:dartway_cli/src/checker/dw_instructions.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory root;
  setUp(() => root = Directory.systemTemp.createTempSync('dw-instructions-'));
  tearDown(() => root.deleteSync(recursive: true));

  for (final (text, count) in [
    ('@AGENTS.md\n', 0),
    ('\n@AGENTS.md\n@other.md\n', 0),
    ('@"rules with spaces.md"\n', 0),
    ('Project rules\n', 1),
    ('@AGENTS.md\nExtra rule\n', 1),
    ('@AGENTS.md extra prose\n', 1),
    (
      '<!-- dartway-toolkit:start -->\nRead `.agents/DARTWAY.md`.\n'
          '<!-- dartway-toolkit:end -->\n',
      0,
    ),
  ]) {
    test('root instructions: $text', () {
      File(p.join(root.path, 'AGENTS.md')).writeAsStringSync('owner');
      final claude = File(p.join(root.path, 'CLAUDE.md'))
        ..writeAsStringSync(text);
      final tally = DwCheckTally();
      expect(DwInstructionsInspector(projectRoot: root).run(tally: tally), 0);
      expect(tally.counts[DwCheckType.instructionsDuplicated] ?? 0, count);
      expect(tally.errors, 0);
      expect(claude.readAsStringSync(), text);
    });
  }
  test('requires both root files and respects filters', () {
    File(p.join(root.path, 'CLAUDE.md')).writeAsStringSync('owner');
    final tally = DwCheckTally();
    DwInstructionsInspector(projectRoot: root).run(tally: tally);
    expect(tally.counts, isEmpty);
    File(p.join(root.path, 'AGENTS.md')).writeAsStringSync('owner');
    DwInstructionsInspector(
      projectRoot: root,
      filterType: DwCheckType.fileLong,
    ).run(tally: tally);
    DwInstructionsInspector(
      projectRoot: root,
      filterSeverity: DwCheckSeverity.error,
    ).run(tally: tally);
    expect(tally.counts, isEmpty);
  });
}
