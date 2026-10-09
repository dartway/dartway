import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:dartway_cli/src/commands/deploy_command.dart';
import 'package:dartway_cli/src/commands/deploy_run.dart';
import 'package:dartway_cli/src/deploy/deploy_progress.dart';
import 'package:dartway_cli/src/deploy/ssh_runner.dart';
import 'package:test/test.dart';

import 'support/deploy_fixtures.dart';

/// A script or a CI job decides by the exit code whether a deploy went
/// through, so a step that fails has to make `deploy run` answer non-zero —
/// whatever else it prints (#433 reported an exit 0 that the CLI, read
/// closely, could not have given; this keeps it that way).
void main() {
  Future<({int code, String human, List<Map<String, Object?>> events})> runWith(
    RecordingSsh ssh, {
    List<String> arguments = const ['--env', 'staging'],
  }) async {
    final human = StreamController<List<int>>();
    final events = StreamController<List<int>>();
    final humanLines = human.stream.transform(utf8.decoder).join();
    final eventLines = events.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .toList();
    final humanSink = IOSink(human.sink);
    final eventSink = IOSink(events.sink);
    final code = await runDeploy(
      stackFrom(),
      DeployRunCommand().argParser.parse(arguments),
      connection: ssh,
      progress: DwDeployProgress.into(human: humanSink, events: eventSink),
      localChecks: const [],
    );
    await humanSink.close();
    await eventSink.close();
    return (
      code: code,
      human: await humanLines,
      events: [
        for (final line in await eventLines)
          jsonDecode(line) as Map<String, Object?>,
      ],
    );
  }

  test('missing host BBR stops before the first deployment step', () async {
    final ssh = RecordingSsh([
      (
        'tcp_allowed_congestion_control',
        const DwSshResult(exitCode: 0, stdout: 'reno cubic\n', stderr: ''),
      ),
    ]);
    final result = await runWith(ssh);
    expect(result.code, 1);
    expect(result.human, contains('BBR congestion control is not allowed'));
    expect(
      result.events.singleWhere((event) => event['event'] == 'run_finished'),
      containsPair('reason', 'bbr-unavailable'),
    );
    expect(ssh.issued, hasLength(1));
  });

  test('an SSH failure is reported as unreachable, not missing BBR', () async {
    final ssh = RecordingSsh([
      (
        'tcp_allowed_congestion_control',
        const DwSshResult(
          exitCode: 255,
          stdout: '',
          stderr: 'ssh: connect to host example.com: Connection refused\n',
        ),
      ),
    ]);
    final result = await runWith(ssh);
    expect(result.code, 1);
    expect(result.human, contains('Connection refused'));
    expect(
      result.human,
      isNot(contains('BBR congestion control is not allowed')),
    );
    expect(
      result.events.singleWhere((event) => event['event'] == 'run_finished'),
      containsPair('reason', 'unreachable'),
    );
  });

  test(
    'a failed step makes deploy run exit non-zero, naming the step',
    () async {
      final events = StreamController<List<int>>();
      final lines = events.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .toList();
      final quiet = IOSink(StreamController<List<int>>()..stream.drain<void>());
      final eventSink = IOSink(events.sink);

      final code = await runDeploy(
        stackFrom(),
        DeployRunCommand().argParser.parse(['--env', 'staging']),
        connection: _ServerWhereEveryStepExits(3),
        progress: DwDeployProgress.into(human: quiet, events: eventSink),
        // The working-copy checks have suites of their own; a project that
        // passes all of them is not what this is about.
        localChecks: const [],
      );
      await eventSink.close();

      expect(code, 1);
      final finished = (await lines)
          .map((line) => jsonDecode(line) as Map<String, Object?>)
          .singleWhere((event) => event['event'] == 'run_finished');
      expect(finished, containsPair('ok', false));
      expect(finished, containsPair('exit_code', 1));
      expect(finished, containsPair('failed_step', 'update-checkout'));
    },
  );

  for (final reason in const [
    'revision-not-found',
    'revision-not-on-branch',
    'superseded',
  ]) {
    test('$reason refusal identifies the checkout step and reason', () async {
      final result = await runWith(
        _RevisionRefusalServer(reason),
        arguments: const ['--env', 'staging', '--revision', 'abcdef1'],
      );
      expect(result.code, 1);
      expect(result.human, contains('revision: abcdef1'));
      expect(
        result.events.singleWhere((event) => event['event'] == 'run_started'),
        containsPair('revision', 'abcdef1'),
      );
      expect(
        result.events.singleWhere((event) => event['event'] == 'run_finished'),
        allOf(
          containsPair('failed_step', 'update-checkout'),
          containsPair('reason', reason),
        ),
      );
    });
  }

  test(
    'invalid revision options exit 64 through the command runner before SSH',
    () async {
      for (final arguments in const [
        ['--env', 'staging', '--revision', 'not-hex'],
        ['--env', 'staging', '--revision', 'abcdef1', '--skip-git-update'],
      ]) {
        final ssh = RecordingSsh();
        final runner = CommandRunner<int>('dartway', 'test')
          ..addCommand(DeployRunCommand(stack: stackFrom(), connection: ssh));
        var code = 0;
        try {
          code = await runner.run(['run', ...arguments]) ?? 0;
        } on UsageException {
          code = 64;
        }
        expect(code, 64);
        expect(ssh.issued, isEmpty);
      }
    },
  );

  test('dry-run plan names the pinned revision', () async {
    final ssh = RecordingSsh();
    final result = await runWith(
      ssh,
      arguments: const [
        '--env',
        'staging',
        '--revision',
        'abcdef1',
        '--dry-run',
      ],
    );
    expect(result.code, 0);
    expect(result.human, contains('Update the checkout to revision abcdef1'));
    expect(ssh.issued, isEmpty);
  });

  test(
    'resume skips a successful checkout after matching server HEAD',
    () async {
      final ssh = _ResumeRevisionServer(
        record: 'update-checkout exited 0\n',
        head: 'abcdef1234567890\nabcdef1 verified\n',
      );
      final result = await runWith(
        ssh,
        arguments: const [
          '--env',
          'staging',
          '--resume',
          '--revision',
          'abcdef1',
        ],
      );
      expect(
        result.events,
        contains(
          allOf(
            containsPair('event', 'step_skipped'),
            containsPair('id', 'update-checkout'),
          ),
        ),
      );
      expect(ssh.detachedCheckoutRuns, 0);
    },
  );

  test('resume refuses a successful checkout at a different HEAD', () async {
    final result = await runWith(
      _ResumeRevisionServer(
        record: 'update-checkout exited 0\n',
        head: '1234567890abcdef\n1234567 other\n',
      ),
      arguments: const [
        '--env',
        'staging',
        '--resume',
        '--revision',
        'abcdef1',
      ],
    );
    expect(result.code, 1);
    expect(
      result.events.singleWhere((event) => event['event'] == 'run_finished'),
      allOf(
        containsPair('failed_step', 'update-checkout'),
        containsPair('reason', 'revision-mismatch'),
      ),
    );
  });

  test(
    'resume retries a recorded checkout failure with the revision',
    () async {
      final ssh = _ResumeRevisionServer(record: 'update-checkout exited 1\n');
      await runWith(
        ssh,
        arguments: const [
          '--env',
          'staging',
          '--resume',
          '--revision',
          'abcdef1',
        ],
      );
      expect(ssh.detachedCheckoutRuns, 1);
      expect(
        ssh.checkoutScript,
        contains("rev-parse --verify 'abcdef1^{commit}'"),
      );
    },
  );

  test('resume with a revision refuses a plan without checkout', () async {
    final ssh = _ResumeRevisionServer(record: 'build-server exited 0\n');
    final result = await runWith(
      ssh,
      arguments: const [
        '--env',
        'staging',
        '--resume',
        '--revision',
        'abcdef1',
      ],
    );
    expect(result.code, 1);
    expect(
      result.events.singleWhere((event) => event['event'] == 'run_finished'),
      containsPair('reason', 'revision-mismatch'),
    );
    expect(ssh.detachedCheckoutRuns, 0);
  });
}

class _ResumeRevisionServer extends _ServerWhereEveryStepExits {
  _ResumeRevisionServer({required this.record, this.head = ''}) : super(0);

  final String record;
  final String head;
  int detachedCheckoutRuns = 0;
  String checkoutScript = '';

  @override
  Future<DwSshResult> runAsWithInput(
    String deployUser,
    String command,
    String input,
  ) {
    if (command.contains('update-checkout')) checkoutScript = input;
    return run(command);
  }

  @override
  Future<DwSshResult> run(String command) async {
    if (command.contains('tcp_allowed_congestion_control')) {
      issued.add(command);
      return const DwSshResult(
        exitCode: 0,
        stdout: 'reno cubic bbr\n',
        stderr: '',
      );
    }
    if (command.contains('while read -r id')) {
      issued.add(command);
      return DwSshResult(exitCode: 0, stdout: record, stderr: '');
    }
    if (command.contains("git log -1 --format='%H%n%h %s'")) {
      issued.add(command);
      return DwSshResult(exitCode: 0, stdout: head, stderr: '');
    }
    if (command.contains('--dw-step-') && command.contains('update-checkout')) {
      detachedCheckoutRuns++;
    }
    return super.run(command);
  }
}

class _RevisionRefusalServer extends _ServerWhereEveryStepExits {
  _RevisionRefusalServer(this.reason) : super(1);

  final String reason;

  @override
  Future<DwSshResult> run(String command) async {
    final result = await super.run(command);
    if (!command.contains('--dw-step-') || result.stdout.isEmpty) return result;
    return DwSshResult(
      exitCode: result.exitCode,
      stdout: result.stdout.replaceFirst(
        'fatal: the step failed',
        '$reason: checkout refused',
      ),
      stderr: result.stderr,
    );
  }
}

/// Answers every detached step the way the server's step runner reports one
/// that exited with [code].
class _ServerWhereEveryStepExits extends RecordingSsh {
  _ServerWhereEveryStepExits(this.code);

  final int code;

  static final _nonce = RegExp(r'--dw-step-[0-9a-f]{8}--');

  @override
  Future<DwSshResult> run(String command) async {
    issued.add(command);
    if (command.contains('tcp_allowed_congestion_control')) {
      return const DwSshResult(
        exitCode: 0,
        stdout: 'reno cubic bbr\n',
        stderr: '',
      );
    }
    final nonce = _nonce.firstMatch(command)?.group(0);
    if (nonce == null) {
      return const DwSshResult(exitCode: 0, stdout: '', stderr: '');
    }
    return DwSshResult(
      exitCode: 0,
      stdout:
          '$nonce exited $code\n\n$nonce stderr\nfatal: the step failed\n\n'
          '$nonce end 0\n',
      stderr: '',
    );
  }
}
