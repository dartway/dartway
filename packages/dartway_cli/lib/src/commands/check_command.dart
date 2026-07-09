import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../checker/dw_check_type.dart';
import '../checker/dw_flutter_inspector.dart';
import '../project_layout.dart';

/// Runs the built-in DartWay convention checks on the project's Flutter
/// package. Fails (non-zero exit) only on error-severity findings —
/// warnings and infos are advisory.
class CheckCommand extends Command<int> {
  CheckCommand() {
    argParser
      ..addOption(
        'type',
        help: 'Run a single check by name '
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
  String get invocation => 'dartway check [--type <check>] [--level <severity>] [--dir <folder>]';

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

    final flutterPackageDir = _findFlutterPackage();
    stdout.writeln('Checking ${flutterPackageDir.path} ...');

    final errorCount = await DwFlutterInspector(
      packageDir: flutterPackageDir,
      filterType: filterType,
      filterSeverity: filterSeverity,
      targetDirPath: results.option('dir'),
    ).run();

    return errorCount > 0 ? 1 : 0;
  }

  Directory _findFlutterPackage() {
    final currentDir = Directory.current;
    if (p.basename(currentDir.path).endsWith('_flutter')) {
      return currentDir;
    }
    return ProjectLayout.detect(currentDir).flutterPackageDir;
  }
}
