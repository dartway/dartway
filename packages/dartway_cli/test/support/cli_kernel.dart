import 'dart:io';

import 'package:path/path.dart' as p;

Future<String>? _kernel;

/// A kernel snapshot of `bin/dartway.dart`, compiled once per test file;
/// run it as `dart --packages=<the workspace's config> <snapshot>`.
///
/// Run from source, every call compiled the CLI and the analyzer under it
/// all over again — seconds a call, and the suites that drive the real CLI
/// make dozens of them. The snapshot lies in this package's own
/// `.dart_tool/test_kernels/`, so the CLI still finds its package by walking
/// up from `Platform.script`; it is written under a unique name and renamed
/// into place, so test files compiling it at the same time never run a
/// half-written one.
Future<String> cliKernel(String repository) => _kernel ??= () async {
  final package = p.join(repository, 'packages', 'dartway_cli');
  final directory = Directory(p.join(package, '.dart_tool', 'test_kernels'))
    ..createSync(recursive: true);
  final target = p.join(directory.path, 'dartway.dill');
  final staging = '$target.$pid.${DateTime.now().microsecondsSinceEpoch}';
  final result = await Process.run(Platform.resolvedExecutable, [
    'compile',
    'kernel',
    '--packages=${p.join(repository, '.dart_tool', 'package_config.json')}',
    '--output=$staging',
    p.join(package, 'bin', 'dartway.dart'),
  ]);
  if (result.exitCode != 0) {
    throw StateError(
      'compiling bin/dartway.dart failed:\n${result.stdout}${result.stderr}',
    );
  }
  File(staging).renameSync(target);
  return target;
}();
