import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../project_layout.dart';

/// Runs DartWay convention checks (`dartway_code_checker`) on the project's
/// Flutter package. Extra arguments are passed through to the checker
/// (e.g. `--type`, `--level`, `--dir`).
class CheckCommand extends Command<int> {
  @override
  String get name => 'check';

  @override
  String get description =>
      'Run DartWay convention checks on the Flutter package.';

  @override
  String get invocation => 'dartway check [checker arguments]';

  @override
  Future<int> run() async {
    final flutterPackageDir = _findFlutterPackage();
    stdout.writeln('Checking ${flutterPackageDir.path} ...');

    final process = await Process.start('dart', [
      'run',
      'dartway_code_checker:check_flutter_app',
      ...argResults!.rest,
    ], workingDirectory: flutterPackageDir.path, runInShell: true, mode: ProcessStartMode.inheritStdio);
    final checkerExitCode = await process.exitCode;

    if (checkerExitCode == 65) {
      // `dart run` could not resolve the package.
      stderr.writeln(
        '\nIf dartway_code_checker is not available, add it to the Flutter '
        'package dev_dependencies:\n'
        '  dartway_code_checker:\n'
        '    git:\n'
        '      url: https://github.com/dartway/dartway.git\n'
        '      ref: stable\n'
        '      path: packages/dartway_code_checker',
      );
    }
    return checkerExitCode;
  }

  Directory _findFlutterPackage() {
    final currentDir = Directory.current;
    if (p.basename(currentDir.path).endsWith('_flutter')) {
      return currentDir;
    }
    return ProjectLayout.detect(currentDir).flutterPackageDir;
  }
}
