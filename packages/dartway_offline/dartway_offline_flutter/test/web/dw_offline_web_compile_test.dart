import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('download plan compiles to JavaScript', () async {
    final outputDirectory = await Directory.systemTemp.createTemp(
      'dw_offline_web_compile_',
    );
    addTearDown(() => outputDirectory.delete(recursive: true));

    final compileResult = await Process.run(
      'dart',
      [
        'compile',
        'js',
        'test/support/dw_download_plan_web_fixture.dart',
        '-o',
        '${outputDirectory.path}/fixture.js',
      ],
      workingDirectory: Directory.current.path,
      runInShell: Platform.isWindows,
    );

    expect(
      compileResult.exitCode,
      0,
      reason: '${compileResult.stdout}\n${compileResult.stderr}',
    );
  });
}
