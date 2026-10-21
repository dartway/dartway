import 'dart:io';

import 'package:dartway_cli/src/toolkit_install.dart';
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
  late Directory sandbox;
  late File log;
  String root = '';
  setUp(() {
    sandbox = Directory.systemTemp.createTempSync('dw-finish-gates-');
    log = File(p.join(sandbox.path, 'calls'));
    root = p.basename(sandbox.path);
    for (final name in [
      'sample_shared',
      'sample_server',
      'sample_flutter',
      'bin',
    ]) {
      Directory(p.join(sandbox.path, name)).createSync();
    }
    for (final tool in ['dart', 'flutter', 'git', 'dartway']) {
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

  Future<List<String>> run(
    String selection, {
    String releaseBranch = '',
  }) async {
    await installToolkitInto(
      projectRoot: sandbox,
      choice: ToolkitInstallChoice(
        baseBranch: 'develop',
        releaseBranch: releaseBranch,
        language: 'English',
        notesTracker: 'none',
        channel: 'master',
        localRepo: repository.path,
        channelWasExplicit: false,
        channelChosen: false,
      ),
      installed: null,
    );
    final skill = File(
      p.join(sandbox.path, '.agents/skills/dartway-finish/SKILL.md'),
    ).readAsStringSync();
    expect(
      File(
        p.join(sandbox.path, '.claude/skills/dartway-finish/SKILL.md'),
      ).readAsStringSync(),
      skill,
    );
    final gates = skill.split('## A.2 ').last.split('## A.3 ').first;
    final block = RegExp(
      r'```bash\n([\s\S]*?)\n```',
    ).firstMatch(gates)!.group(1)!;
    if (releaseBranch.isEmpty) {
      expect(
        block,
        contains('CONTRACT_BASE="\$(git merge-base HEAD origin/develop)"'),
      );
    } else {
      expect(block, isNot(contains('CONTRACT_BASE')));
      expect(block, isNot(contains('--contract-base')));
    }
    final script = '$selection\n$block';
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
    // The project commands run from the root; the pinned CLI takes them
    // from there whichever `dartway` is on the PATH.
    expect(calls, contains('$root:dartway <format> <--check>'));
    // These gates cannot disappear when CI carries all three suites.
    expect(calls, contains('sample_shared:dart <analyze>'));
    expect(calls, contains('sample_server:dart <analyze>'));
    expect(calls, contains('sample_flutter:dart <analyze> <--fatal-infos>'));
    final contractArgs = releaseBranch.isEmpty
        ? ' <--contract-base> <trusted-base>'
        : '';
    expect(calls, contains('$root:dartway <generate> <--check>$contractArgs'));
    expect(calls, contains('$root:dartway <check>$contractArgs'));
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

  for (final releaseBranch in ['', 'stage']) {
    test('rendered gates with releaseBranch="$releaseBranch"', () async {
      await run(runAll, releaseBranch: releaseBranch);
    });
  }

  test('CI selections are forwarded relative to the suite package', () async {
    final calls = await run('''$runAll
RUN_MIGRATE_CHECK=false
SHARED_TEST_FILES=(test/contract_test.dart)
SERVER_TEST_FILES=(test/src/accounts/accounts_acceptance_test.dart)
FLUTTER_TEST_FILES=(test/admin/users 'test/app/sign in/page_test.dart')
''');
    expect(
      calls,
      contains('sample_shared:dart <test> <test/contract_test.dart>'),
    );
    expect(
      calls,
      contains(
        '$root:dartway <test> <--> '
        '<test/src/accounts/accounts_acceptance_test.dart>',
      ),
    );
    expect(
      calls,
      contains(
        'sample_flutter:flutter <test> <test/admin/users> '
        '<test/app/sign in/page_test.dart>',
      ),
    );
    expect(calls.any((call) => call.contains('<bin/migrate.dart>')), isFalse);
  });

  test('no CI or an unmapped change can run full suites', () async {
    final calls = await run(runAll);
    expect(calls, contains('sample_shared:dart <test>'));
    expect(calls, contains('$root:dartway <test> <-->'));
    expect(calls, contains('sample_flutter:flutter <test>'));
    expect(
      calls,
      contains('sample_server:dart <run> <bin/migrate.dart> <check>'),
    );
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
      expect(calls, contains('sample_shared:dart <test>'));
      expect(
        calls,
        contains(
          '$root:dartway <test> <--> '
          '<test/src/accounts/accounts_acceptance_test.dart>',
        ),
      );
      expect(
        calls.any((call) => call.startsWith('sample_flutter:flutter')),
        isFalse,
      );
    },
  );
}
