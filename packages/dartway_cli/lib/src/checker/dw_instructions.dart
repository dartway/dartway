import 'dart:io';

import 'package:path/path.dart' as p;

import 'dw_check_tally.dart';
import 'dw_check_type.dart';

/// Warns about root instruction text maintained separately for each agent.
class DwInstructionsInspector {
  DwInstructionsInspector({
    required this.projectRoot,
    this.filterType,
    this.filterSeverity,
  });

  final Directory projectRoot;
  final DwCheckType? filterType;
  final DwCheckSeverity? filterSeverity;

  int run({DwCheckTally? tally}) {
    const type = DwCheckType.instructionsDuplicated;
    if ((filterType != null && filterType != type) ||
        (filterSeverity != null && filterSeverity != type.severity)) {
      return 0;
    }
    final agents = File(p.join(projectRoot.path, 'AGENTS.md'));
    final claude = File(p.join(projectRoot.path, 'CLAUDE.md'));
    if (!agents.existsSync() || !claude.existsSync()) return 0;
    final text = claude.readAsStringSync().replaceAll(
      RegExp(
        r'<!-- dartway-toolkit:start -->[\s\S]*?<!-- dartway-toolkit:end -->',
      ),
      '',
    );
    final imports = RegExp(r'''^@(?:[^\s]+|"[^"]+"|'[^']+')$''');
    if (text
        .split('\n')
        .every(
          (line) => line.trim().isEmpty || imports.hasMatch(line.trim()),
        )) {
      return 0;
    }
    print(
      '\n${type.reportLabel}: instructionsDuplicated — '
      'root CLAUDE.md contains text while AGENTS.md exists. '
      'Move project rules into AGENTS.md and leave only @AGENTS.md '
      'in CLAUDE.md. The toolkit never merges owner instructions.',
    );
    tally?.add(type, 1);
    return 0;
  }
}
