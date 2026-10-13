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
        ..remove('DW_CONTRACT_BASE')
        ..remove('DW_CHECKS_ONLY')
        ..remove('DW_TEST_PART');
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
  printf '%s\\n' "\$PWD|\$*" >> '${calls.path}'
fi
''');
      expect(Process.runSync('chmod', ['+x', path]).exitCode, 0);
    }

    Future<ProcessResult> run(String only, {String part = '1/1'}) =>
        Process.run(
          '/bin/bash',
          ['tool/checks.sh', 'test'],
          workingDirectory: repository.path,
          environment: {
            ...Platform.environment,
            'PATH': '${bin.path}:${Platform.environment['PATH']}',
            'DW_CHECKS_ONLY': only,
            'DW_TEST_PART': part,
          },
          includeParentEnvironment: false,
        );

    var result = await run('packages/dartway_core_shared tool');
    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    // Side by side: in whatever order they end.
    expect(
      calls.readAsLinesSync(),
      unorderedEquals([
        '${repository.path}/packages/dartway_core_shared|test',
        '${repository.path}/tool|test',
      ]),
    );

    // A test file runs alone.
    calls.writeAsStringSync('');
    result = await run('packages/dartway_cli/test/pinned_cli_test.dart');
    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    expect(calls.readAsLinesSync(), [
      '${repository.path}/packages/dartway_cli|test test/pinned_cli_test.dart',
    ]);

    // A part takes every n-th suite that runs; one suite, its n-th of tests.
    calls.writeAsStringSync('');
    const files =
        'packages/dartway_cli/test/pinned_cli_test.dart '
        'packages/dartway_cli/test/build_context_test.dart '
        'packages/dartway_core_shared tool';
    result = await run(files, part: '2/2');
    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    expect(
      calls.readAsLinesSync(),
      unorderedEquals([
        '${repository.path}/packages/dartway_cli|test test/build_context_test.dart',
        '${repository.path}/tool|test',
      ]),
    );
    calls.writeAsStringSync('');
    result = await run(
      'packages/dartway_cli/test/pinned_cli_test.dart',
      part: '2/3',
    );
    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    expect(calls.readAsLinesSync(), [
      '${repository.path}/packages/dartway_cli|'
          'test --total-shards 3 --shard-index 1 test/pinned_cli_test.dart',
    ]);
    result = await run('tool', part: '3/2');
    expect(result.exitCode, 64);

    calls.writeAsStringSync('');
    result = await run('');
    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    expect(calls.readAsLinesSync(), isEmpty);

    result = await run('packages/dartway_core_shard');
    expect(result.exitCode, 64);
    expect(result.stderr, contains('packages/dartway_core_shard'));
    result = await run('packages/dartway_cli/test/missing_test.dart');
    expect(result.exitCode, 64);
  });

  test('DW_CHECKS_ONLY narrows analyze to the roots it names', () async {
    final fixture = await Directory.systemTemp.createTemp('checks-analyze-');
    addTearDown(() => fixture.delete(recursive: true));
    final calls = File('${fixture.path}/dart-calls');
    final bin = Directory('${fixture.path}/bin')..createSync();
    for (final tool in ['flutter', 'dart']) {
      final path = '${bin.path}/$tool';
      File(path).writeAsStringSync('''#!/bin/sh
if [ "\${1:-}" = --version ]; then
  echo 'Flutter 3.47.6'
elif [ "$tool" = dart ]; then
  printf '%s\\n' "\$PWD|\$*" >> '${calls.path}'
fi
''');
      expect(Process.runSync('chmod', ['+x', path]).exitCode, 0);
    }

    final result = await Process.run(
      '/bin/bash',
      ['tool/checks.sh', 'analyze'],
      workingDirectory: repository.path,
      // CI sets a contract baseline; this test is about the roots.
      environment: {
        ...Platform.environment,
        'PATH': '${bin.path}:${Platform.environment['PATH']}',
        'DW_CHECKS_ONLY':
            'packages/dartway_core_shared template/dartway_starter_server',
      }..remove('DW_CONTRACT_BASE'),
      includeParentEnvironment: false,
    );
    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    final root = repository.path;
    expect(
      calls.readAsLinesSync(),
      unorderedEquals([
        '$root|analyze --no-fatal-warnings packages/dartway_core_shared',
        '$root/template/dartway_starter_server|analyze --no-fatal-warnings',
        // The whole project is checked once one of its packages is reached.
        '$root/template/dartway_starter_flutter|run dartway_cli:dartway check',
      ]),
    );
  });
}
