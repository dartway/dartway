import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../checker/dw_flutter_stat.dart';
import '../project_layout.dart';

/// Prints code-size statistics for the feature folders of the project's
/// Flutter package.
class StatsCommand extends Command<int> {
  @override
  String get name => 'stats';

  @override
  String get description =>
      'Show code-size statistics for the Flutter package features.';

  @override
  String get invocation => 'dartway stats';

  @override
  Future<int> run() async {
    final flutterPackageDir = _findFlutterPackage();
    await DwFlutterStat(packageDir: flutterPackageDir).run();
    return 0;
  }

  Directory _findFlutterPackage() {
    final currentDir = Directory.current;
    if (p.basename(currentDir.path).endsWith('_flutter')) {
      return currentDir;
    }
    return ProjectLayout.detect(currentDir).flutterPackageDir;
  }
}
