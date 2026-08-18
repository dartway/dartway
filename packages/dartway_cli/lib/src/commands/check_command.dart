import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../checker/dw_check_type.dart';
import '../checker/dw_flutter_inspector.dart';
import '../checker/dw_framework_lock.dart';
import '../checker/dw_generated_format.dart';
import '../checker/dw_layout.dart';
import '../project_layout.dart';

/// Runs the built-in DartWay convention checks on the project's Flutter
/// package. Fails (non-zero exit) only on error-severity findings —
/// warnings and infos are advisory.
class CheckCommand extends Command<int> {
  CheckCommand() {
    argParser
      ..addOption(
        'type',
        help:
            'Run a single check by name '
            '(${DwCheckType.values.map((t) => t.name).join(', ')}).',
      )
      ..addOption(
        'level',
        allowed: DwCheckSeverity.values.map((s) => s.name),
        help: 'Run only checks of the given severity.',
      )
      ..addOption(
        'dir',
        help: 'Validate a single folder (relative to the Flutter package).',
      );
  }

  @override
  String get name => 'check';

  @override
  String get description =>
      'Run DartWay convention checks on the Flutter package.';

  @override
  String get invocation =>
      'dartway check [--type <check>] [--level <severity>] [--dir <folder>]';

  @override
  Future<int> run() async {
    final results = argResults!;

    DwCheckType? filterType;
    final typeArg = results.option('type');
    if (typeArg != null) {
      filterType = DwCheckType.values
          .where((t) => t.name.toLowerCase() == typeArg.toLowerCase())
          .firstOrNull;
      if (filterType == null) {
        usageException('Unknown check type: $typeArg');
      }
    }

    final levelArg = results.option('level');
    final filterSeverity = levelArg == null
        ? null
        : DwCheckSeverity.values.byName(levelArg);

    final layout = _detectLayout();
    final flutterPackageDir = layout?.flutterPackageDir ?? Directory.current;
    stdout.writeln('Checking ${flutterPackageDir.path} ...');

    var errorCount = 0;

    // The layout check judges the whole package, so it has nothing to say when
    // the run is narrowed to one folder — the same reason `--dir` skips the
    // ui_kit pass.
    if (results.option('dir') == null) {
      errorCount += DwLayoutInspector(
        flutterPackageDir: flutterPackageDir,
        serverPackageDir: layout?.serverPackageDir,
        filterType: filterType,
        filterSeverity: filterSeverity,
      ).run();

      // Judges the server and client packages, so it is out of scope for a run
      // narrowed to a folder of the Flutter package, and silent when the
      // Flutter package was found standing on its own.
      errorCount += DwGeneratedFormatInspector(
        serverPackageDir: layout?.serverPackageDir,
        clientPackageDir: layout?.clientPackageDir,
        filterType: filterType,
        filterSeverity: filterSeverity,
      ).run();

      // Judges the project rather than any one package, so it is skipped by
      // `--dir` for the same reason the layout check is.
      errorCount += DwFrameworkLockInspector(
        projectRoot: layout?.root ?? flutterPackageDir,
        filterType: filterType,
        filterSeverity: filterSeverity,
      ).run();
    }

    errorCount += await DwFlutterInspector(
      packageDir: flutterPackageDir,
      filterType: filterType,
      filterSeverity: filterSeverity,
      targetDirPath: results.option('dir'),
    ).run();

    // Said once, by the only place that has both counts. The Flutter inspector
    // used to print it from inside itself, knowing nothing of the layout check
    // that ran first — so a run could show two layout errors and then announce
    // that the check passes, while exiting 1.
    if (errorCount > 0) {
      stdout.writeln(
        '\n🔴 Errors: $errorCount (warnings/infos do not fail the check)',
      );
    } else {
      stdout.writeln('\n🟡 No errors — only warnings/infos, check passes');
    }

    return errorCount > 0 ? 1 : 0;
  }

  /// The project root, whether the command was run there or inside the Flutter
  /// package. Returns null only for a Flutter package standing on its own —
  /// it is still worth checking, minus the server pass. Run from anywhere
  /// else, the detector's own "this is not a DartWay project" wins.
  ProjectLayout? _detectLayout() {
    final currentDir = Directory.current;
    final insideFlutterPackage = p
        .basename(currentDir.path)
        .endsWith('_flutter');
    try {
      return ProjectLayout.detect(
        insideFlutterPackage ? currentDir.parent : currentDir,
      );
    } on StateError {
      if (!insideFlutterPackage) rethrow;
      return null;
    }
  }
}
