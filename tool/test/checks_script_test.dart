import 'dart:io';

import 'package:test/test.dart';

void main() {
  final repository = () {
    var dir = Directory.current.absolute;
    while (!File('${dir.path}/tool/checks.sh').existsSync()) {
      final parent = dir.parent;
      if (parent.path == dir.path) throw StateError('not inside the monorepo');
      dir = parent;
    }
    return dir;
  }();

  test('checks.sh forwards only a configured contract baseline', () async {
    final fixture = await Directory.systemTemp.createTemp('checks-script-');
    addTearDown(() => fixture.delete(recursive: true));
    final calls = File('${fixture.path}/dart-calls');
    final bin = Directory('${fixture.path}/bin')..createSync();

    void writeExecutable(String name, String contents) {
      final path = '${bin.path}/$name';
      File(path).writeAsStringSync(contents);
      final chmod = Process.runSync('chmod', ['+x', path]);
      expect(chmod.exitCode, 0, reason: chmod.stderr as String);
    }

    writeExecutable('flutter', '''#!/bin/sh
if [ "\${1:-}" = --version ]; then
  echo 'Flutter 3.47.6'
fi
''');
    writeExecutable('dart', '''#!/bin/sh
if [ "\${1:-}" = run ]; then
  printf '%s\\n' "\$PWD|\$*" >> '${calls.path}'
fi
''');

    Future<ProcessResult> run({String? contractBase}) {
      final environment = Map<String, String>.of(Platform.environment)
        ..['PATH'] = '${bin.path}:${Platform.environment['PATH']}'
        ..remove('DW_CONTRACT_BASE');
      if (contractBase != null) environment['DW_CONTRACT_BASE'] = contractBase;
      return Process.run(
        '/bin/bash',
        ['tool/checks.sh', 'analyze'],
        workingDirectory: repository.path,
        environment: environment,
        includeParentEnvironment: false,
      );
    }

    var result = await run();
    expect(result.exitCode, 0, reason: result.stderr as String);
    var checkCalls = calls.readAsLinesSync().where(
      (line) => line.contains('dartway check'),
    );
    expect(checkCalls, hasLength(2));
    expect(checkCalls, everyElement(isNot(contains('--contract-base'))));

    calls.writeAsStringSync('');
    result = await run(contractBase: 'HEAD');
    expect(result.exitCode, 0, reason: result.stderr as String);
    final contractSha = (await Process.run('git', [
      'rev-parse',
      'HEAD',
    ], workingDirectory: repository.path)).stdout.toString().trim();
    checkCalls = calls.readAsLinesSync().where(
      (line) => line.contains('dartway check'),
    );
    expect(checkCalls, hasLength(2));
    expect(
      checkCalls,
      everyElement(endsWith('check --contract-base $contractSha')),
    );
  });

  test('DW_CHECKS_ONLY runs the suites of the packages it names', () async {
    final fixture = await Directory.systemTemp.createTemp('checks-only-');
    addTearDown(() => fixture.delete(recursive: true));
    final calls = File('${fixture.path}/test-calls');
    final bin = Directory('${fixture.path}/bin')..createSync();
    for (final tool in ['flutter', 'dart']) {
      final path = '${bin.path}/$tool';
      File(path).writeAsStringSync('''#!/bin/sh
if [ "\${1:-}" = --version ]; then
  echo 'Flutter 3.47.6'
elif [ "\${1:-}" = test ]; then
  printf '%s\\n' "\$PWD" >> '${calls.path}'
fi
''');
      expect(Process.runSync('chmod', ['+x', path]).exitCode, 0);
    }

    Future<ProcessResult> run(String only) => Process.run(
      '/bin/bash',
      ['tool/checks.sh', 'test'],
      workingDirectory: repository.path,
      environment: {
        ...Platform.environment,
        'PATH': '${bin.path}:${Platform.environment['PATH']}',
        'DW_CHECKS_ONLY': only,
      },
      includeParentEnvironment: false,
    );

    var result = await run('packages/dartway_core_shared tool');
    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    expect(calls.readAsLinesSync(), [
      '${repository.path}/packages/dartway_core_shared',
      '${repository.path}/tool',
    ]);

    calls.writeAsStringSync('');
    result = await run('');
    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    expect(calls.readAsLinesSync(), isEmpty);

    result = await run('packages/dartway_core_shard');
    expect(result.exitCode, 64);
    expect(result.stderr, contains('packages/dartway_core_shard'));
  });
}
