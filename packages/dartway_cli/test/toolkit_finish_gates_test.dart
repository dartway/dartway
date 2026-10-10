import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Execute the shipped skill's gate block with recording tools: CI selections
/// must reach each runner, and an unaffected suite must not run in full.
void main() {
  var repository = Directory.current.absolute;
  while (!Directory(
    p.join(repository.path, 'toolkit', 'skills'),
  ).existsSync()) {
    if (repository.parent.path == repository.path) {
      throw StateError('no toolkit/ above ${Directory.current.path}');
    }
    repository = repository.parent;
  }
  final skill = File(
    p.join(repository.path, 'toolkit/skills/dartway-finish/SKILL.md'),
  ).readAsStringSync();
  final gates = skill.split('## A.2 ').last.split('## A.3 ').first;
  final block = RegExp(
    r'```bash\n([\s\S]*?)\n```',
  ).firstMatch(gates)!.group(1)!;

  late Directory sandbox;
  late File log;
  setUp(() {
    sandbox = Directory.systemTemp.createTempSync('dw-finish-gates-');
    log = File(p.join(sandbox.path, 'calls'));
    for (final name in ['shared', 'server', 'flutter', 'bin']) {
      Directory(p.join(sandbox.path, name)).createSync();
    }
    for (final tool in ['dart', 'flutter', 'git']) {
      final executable = File(p.join(sandbox.path, 'bin', tool));
      executable.writeAsStringSync('''#!/bin/bash
if [[ "\${0##*/}" == git ]]; then
  echo trusted-base
else
  printf '%s:%s' "\${PWD##*/}" "\${0##*/}" >> "\$GATE_LOG"
  printf ' <%s>' "\$@" >> "\$GATE_LOG"
  printf '\\n' >> "\$GATE_LOG"
fi
''');
      final chmod = Process.runSync('chmod', ['+x', executable.path]);
      expect(chmod.exitCode, 0);
    }
  });
  tearDown(() => sandbox.deleteSync(recursive: true));

  Future<List<String>> run(String selection) async {
    final script = '$selection\n$block'
        .replaceAll('__SHARED_PKG__', 'shared')
        .replaceAll('__SERVER_PKG__', 'server')
        .replaceAll('__FLUTTER_PKG__', 'flutter')
        .replaceAll('__BASE_BRANCH__', 'master');
    final result = await Process.run(
      'bash',
      ['-e', '-c', script],
      workingDirectory: sandbox.path,
      environment: {
        'PATH':
            '${p.join(sandbox.path, 'bin')}:${Platform.environment['PATH']}',
        'GATE_LOG': log.path,
      },
    );
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    final calls = log.readAsLinesSync();
    // These gates cannot disappear when CI carries all three suites.
    expect(calls, contains('shared:dart <analyze>'));
    expect(calls, contains('server:dart <analyze>'));
    expect(calls, contains('flutter:dart <analyze> <--fatal-infos>'));
    expect(
      calls,
      contains(
        'flutter:dart <run> <dartway_cli:dartway> <generate> <--check> '
        '<--contract-base> <trusted-base>',
      ),
    );
    expect(
      calls,
      contains(
        'flutter:dart <run> <dartway_cli:dartway> <check> '
        '<--contract-base> <trusted-base>',
      ),
    );
    return calls;
  }

  const runAll = '''
RUN_MIGRATE_CHECK=true
RUN_SHARED_TESTS=true
RUN_SERVER_TESTS=true
RUN_FLUTTER_TESTS=true
SHARED_TEST_FILES=()
SERVER_TEST_FILES=()
FLUTTER_TEST_FILES=()
''';

  test('CI selections are forwarded relative to the suite package', () async {
    final calls = await run('''$runAll
RUN_MIGRATE_CHECK=false
SHARED_TEST_FILES=(test/contract_test.dart)
SERVER_TEST_FILES=(test/src/accounts/accounts_acceptance_test.dart)
FLUTTER_TEST_FILES=(test/admin/users 'test/app/sign in/page_test.dart')
''');
    expect(calls, contains('shared:dart <test> <test/contract_test.dart>'));
    expect(
      calls,
      contains(
        'flutter:dart <run> <dartway_cli:dartway> <test> <--> '
        '<test/src/accounts/accounts_acceptance_test.dart>',
      ),
    );
    expect(
      calls,
      contains(
        'flutter:flutter <test> <test/admin/users> '
        '<test/app/sign in/page_test.dart>',
      ),
    );
    expect(calls.any((call) => call.contains('<bin/migrate.dart>')), isFalse);
  });

  test('no CI or an unmapped change can run full suites', () async {
    final calls = await run(runAll);
    expect(calls, contains('shared:dart <test>'));
    expect(
      calls,
      contains('flutter:dart <run> <dartway_cli:dartway> <test> <-->'),
    );
    expect(calls, contains('flutter:flutter <test>'));
    expect(calls, contains('server:dart <run> <bin/migrate.dart> <check>'));
  });

  test(
    'unaffected CI suites are omitted without omitting fast gates',
    () async {
      final calls = await run('''$runAll
RUN_MIGRATE_CHECK=false
RUN_SHARED_TESTS=false
RUN_SERVER_TESTS=false
RUN_FLUTTER_TESTS=false
''');
      expect(calls.any((call) => call.contains('<test>')), isFalse);
    },
  );

  test(
    'a full fallback for one suite preserves another suite selection',
    () async {
      final calls = await run('''$runAll
RUN_FLUTTER_TESTS=false
SERVER_TEST_FILES=(test/src/accounts/accounts_acceptance_test.dart)
''');
      expect(calls, contains('shared:dart <test>'));
      expect(
        calls,
        contains(
          'flutter:dart <run> <dartway_cli:dartway> <test> <--> '
          '<test/src/accounts/accounts_acceptance_test.dart>',
        ),
      );
      expect(calls.any((call) => call.startsWith('flutter:flutter')), isFalse);
    },
  );
}
