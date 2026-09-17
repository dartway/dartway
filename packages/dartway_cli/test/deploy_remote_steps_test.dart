import 'dart:io';

import 'package:dartway_cli/src/deploy/remote_steps.dart';
import 'package:dartway_cli/src/deploy/ssh_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support/deploy_fixtures.dart';

void main() {
  late Directory temp;
  late String directory;
  final notices = <String>[];

  setUp(() {
    temp = Directory.systemTemp.createTempSync('dw_remote_steps_');
    directory = p.join(temp.path, 'deploy-run');
    notices.clear();
  });
  tearDown(() => temp.deleteSync(recursive: true));

  DwRemoteSteps steps(DwSshRunner ssh, {Duration? tolerance}) => DwRemoteSteps(
    ssh: ssh,
    deployUser: 'deployer',
    directory: directory,
    pollInterval: const Duration(milliseconds: 50),
    contactTolerance: tolerance ?? const Duration(seconds: 10),
    onNotice: notices.add,
  );

  group('a step run detached', () {
    test('answers its exit code and both streams, byte for byte', () async {
      final remote = steps(LocalShell())..beginFresh(['one']);
      final result = await remote.run(
        'one',
        "printf 'out\\n\\nlast'\necho oops >&2\nexit 3\n",
      );
      expect(result.exitCode, 3);
      expect(result.stdout, 'out\n\nlast');
      expect(result.stderr, 'oops\n');
    });

    test('keeps running when the connection that started it breaks', () async {
      final ssh = _BrokenAfterStart(LocalShell());
      final remote = steps(ssh)..beginFresh(['slow']);
      final result = await remote.run('slow', 'sleep 1\necho finished\n');

      expect(ssh.broken, 1, reason: 'the start call must have lost its answer');
      expect(result.exitCode, 0, reason: result.stderr);
      expect(result.stdout, 'finished\n');
    });

    test('gives up waiting after the tolerance and names --resume, while the '
        'step itself runs to its end', () async {
      final ssh = _BrokenAfterStart(LocalShell(), unreachableFor: 1000);
      final remote = steps(ssh, tolerance: Duration.zero)..beginFresh(['slow']);
      final result = await remote.run('slow', 'sleep 1\necho finished\n');
      expect(result.exitCode, 255);
      expect(result.stderr, contains('--resume'));

      final later = await steps(LocalShell()).collect('slow');
      expect(later.stdout, 'finished\n');
      expect(later.exitCode, 0);
    });

    test('a process killed without an exit code is a failure', () async {
      final remote = steps(LocalShell())..beginFresh(['doomed']);
      final killing = remote.run('doomed', 'sleep 30\n');
      final pidFile = File(p.join(directory, 'doomed.pid'));
      while (!pidFile.existsSync() || pidFile.readAsStringSync().isEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      Process.killPid(
        int.parse(pidFile.readAsStringSync().trim()),
        ProcessSignal.sigkill,
      );
      final result = await killing;
      expect(result.exitCode, isNot(0));
      expect(result.stderr, contains('without an exit code'));
    });
  });

  group('the record a resumed deployment reads', () {
    test('is nothing before any deployment', () async {
      expect(await steps(LocalShell()).read(), isNull);
    });

    test('names every planned step with what became of it', () async {
      final remote = steps(LocalShell())..beginFresh(['a', 'b', 'c', 'd']);
      await remote.run('a', 'true\n');
      await remote.run('b', 'exit 2\n');
      await remote.run('c', 'echo fine\n');
      await remote.reject('c');

      final record = await remote.read();
      expect(record!.keys, ['a', 'b', 'c', 'd']);
      expect(record['a']!.succeeded, isTrue);
      expect(record['b']!.state, DwRemoteStepState.exited);
      expect(record['b']!.exitCode, 2);
      expect(record['c']!.state, DwRemoteStepState.rejected);
      expect(record['d']!.state, DwRemoteStepState.pending);
    });

    test('a step run again forgets its rejection', () async {
      final remote = steps(LocalShell())..beginFresh(['a']);
      await remote.run('a', 'true\n');
      await remote.reject('a');
      await remote.run('a', 'true\n');
      expect((await remote.read())!['a']!.succeeded, isTrue);
    });

    test('collect answers a finished step without running it again', () async {
      final remote = steps(LocalShell())..beginFresh(['a']);
      final marker = File(p.join(temp.path, 'ran'));
      await remote.run('a', "echo x >> '${marker.path}'\necho done\n");
      final collected = await remote.collect('a');
      expect(collected.stdout, 'done\n');
      expect(marker.readAsLinesSync(), ['x']);
    });
  });

  group('a new deployment', () {
    test('replaces the record and says where the last one stopped', () async {
      final first = steps(LocalShell())..beginFresh(['a', 'b', 'c']);
      await first.run('a', 'true\n');
      await first.run('b', 'exit 1\n');

      final second = steps(LocalShell())..beginFresh(['a', 'b', 'c']);
      await second.run('a', 'true\n');
      expect(notices, [contains('step "b" exited 1')]);
      final record = await second.read();
      expect(record!['b']!.state, DwRemoteStepState.pending);
    });

    test('says nothing after a deployment that finished', () async {
      final first = steps(LocalShell())..beginFresh(['a']);
      await first.run('a', 'true\n');
      await (steps(LocalShell())..beginFresh(['a'])).run('a', 'true\n');
      expect(notices, isEmpty);
    });

    test('refuses while a step of the last one is still running', () async {
      final first = steps(LocalShell())..beginFresh(['slow']);
      final running = first.run('slow', 'sleep 1\n');
      await Future<void>.delayed(const Duration(milliseconds: 300));

      final second = steps(LocalShell())..beginFresh(['slow']);
      await expectLater(
        second.run('slow', 'true\n'),
        throwsA(isA<DwDeployBusy>()),
      );
      expect((await running).ok, isTrue);
    });
  });
}

/// The first call reaches the server and its answer is lost, as when the
/// invoking machine's connection drops mid-step; the next [unreachableFor]
/// calls do not reach the server at all.
class _BrokenAfterStart extends DwSshRunner {
  _BrokenAfterStart(this.inner, {this.unreachableFor = 2})
    : super(host: 'localhost', user: 'local');

  final DwSshRunner inner;
  final int unreachableFor;
  int broken = 0;
  int _calls = 0;

  static const _lost = DwSshResult(
    exitCode: 255,
    stdout: '',
    stderr: 'Connection to 203.0.113.10 closed by remote host.',
  );

  @override
  Future<DwSshResult> runAsWithInput(
    String deployUser,
    String command,
    String input,
  ) async {
    _calls++;
    if (_calls == 1) {
      broken++;
      await inner.runAsWithInput(deployUser, _detachOnly(command), input);
      return _lost;
    }
    return inner.runAsWithInput(deployUser, command, input);
  }

  @override
  Future<DwSshResult> runAs(String deployUser, String command) async {
    _calls++;
    if (_calls <= 1 + unreachableFor) return _lost;
    return inner.runAs(deployUser, command);
  }

  /// The start script without its wait, so the double returns while the step
  /// is still running.
  static String _detachOnly(String command) =>
      command.substring(0, command.lastIndexOf("\nd='"));
}
