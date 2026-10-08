import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
    RecordingSsh ssh,
  ) async {
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
      DeployRunCommand().argParser.parse(['--env', 'staging']),
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
        'tcp_available_congestion_control',
        const DwSshResult(exitCode: 0, stdout: 'reno cubic\n', stderr: ''),
      ),
    ]);
    final result = await runWith(ssh);
    expect(result.code, 1);
    expect(result.human, contains('BBR congestion control is not available'));
    expect(
      result.events.singleWhere((event) => event['event'] == 'run_finished'),
      containsPair('reason', 'bbr-unavailable'),
    );
    expect(ssh.issued, hasLength(1));
  });

  test('an SSH failure is reported as unreachable, not missing BBR', () async {
    final ssh = RecordingSsh([
      (
        'tcp_available_congestion_control',
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
      isNot(contains('BBR congestion control is not available')),
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
