@Tags(['docker'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:dartway_cli/src/commands/deploy_run.dart';
import 'package:dartway_cli/src/deploy/deploy_progress.dart';
import 'package:dartway_cli/src/deploy/deploy_runner.dart';
import 'package:dartway_cli/src/deploy/remote_steps.dart';
import 'package:dartway_cli/src/deploy/ssh_runner.dart';
import 'package:test/test.dart';

void main() {
  test(
    'a full step filesystem reports diskFull in prose, record and JSON',
    () async {
      final name = 'dw-disk-full-${DateTime.now().microsecondsSinceEpoch}';
      final started = await Process.run('docker', [
        'run',
        '-d',
        '--name',
        name,
        '--tmpfs',
        '/disk:rw,size=1m',
        'ubuntu:24.04',
        'sh',
        '-c',
        'mkdir -p /var/lib/docker; exec sleep infinity',
      ]);
      expect(started.exitCode, 0, reason: '${started.stderr}');
      addTearDown(() async {
        await Process.run('docker', ['rm', '-f', name]);
      });
      final temp = Directory.systemTemp.createTempSync('dw_disk_full_');
      addTearDown(() => temp.deleteSync(recursive: true));
      final humanFile = File('${temp.path}/human');
      final eventsFile = File('${temp.path}/events');
      final human = humanFile.openWrite();
      final events = eventsFile.openWrite();
      final remote = DwRemoteSteps(
        ssh: _ContainerShell(name),
        deployUser: 'root',
        directory: '/disk/steps',
        contactTolerance: const Duration(seconds: 5),
        pollInterval: const Duration(milliseconds: 50),
      );
      final failed = await executeDeploySteps(
        [
          DwDeployStep(
            id: 'build',
            title: 'Fill the step filesystem',
            run: () => remote.run(
              'build',
              'dd if=/dev/zero of=/disk/fill bs=4096 count=512 >/dev/null 2>&1',
            ),
          ),
        ],
        remote: remote,
        progress: DwDeployProgress.into(human: human, events: events),
      );
      await human.close();
      await events.close();
      expect(failed, 'build');
      expect(
        humanFile.readAsStringSync(),
        contains('the disk is full — /disk/steps:'),
      );
      expect(humanFile.readAsStringSync(), contains('0 KiB free of 1.0 MiB'));
      final event = eventsFile
          .readAsLinesSync()
          .map((line) => jsonDecode(line) as Map<String, dynamic>)
          .singleWhere((event) => event['event'] == 'step_failed');
      expect(event['state'], 'diskFull');
      expect(event['stderr'], contains('/disk/steps'));
      expect((await remote.read())!['build']!.state.name, 'diskFull');
      final files = await Process.run('docker', [
        'exec',
        name,
        'sh',
        '-c',
        'test ! -f /disk/steps/build.exit && test -f /disk/steps/build.exit.tmp && test ! -s /disk/steps/build.exit.tmp',
      ]);
      expect(files.exitCode, 0, reason: 'the exit code write must have failed');
    },
  );
}

class _ContainerShell extends DwSshRunner {
  _ContainerShell(this.name) : super(host: 'container', user: 'root');
  final String name;

  @override
  Future<DwSshResult> runAs(String deployUser, String command) async {
    final result = await Process.run('docker', [
      'exec',
      name,
      'sh',
      '-c',
      command,
    ]);
    return DwSshResult(
      exitCode: result.exitCode,
      stdout: result.stdout as String,
      stderr: result.stderr as String,
    );
  }

  @override
  Future<DwSshResult> runAsWithInput(
    String deployUser,
    String command,
    String input,
  ) async {
    final process = await Process.start('docker', [
      'exec',
      '-i',
      name,
      'sh',
      '-c',
      command,
    ]);
    return DwSshRunner.feedInput(process, input);
  }
}
