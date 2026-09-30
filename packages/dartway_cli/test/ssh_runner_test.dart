import 'dart:io';

import 'package:dartway_cli/src/deploy/ssh_runner.dart';
import 'package:test/test.dart';

void main() {
  test('every connection notices a peer that went quiet (#286)', () {
    // A step is watched through a session that is silent for as long as a
    // web build runs; without keepalives a dropped one waits forever.
    final options = DwSshRunner(
      host: 'example.com',
      user: 'deploy',
    ).connectionOptions.join(' ');
    expect(options, contains('-o ServerAliveInterval=30'));
    expect(options, contains('-o ServerAliveCountMax=4'));
    expect(options, contains('-o BatchMode=yes'));
  });

  test('a command that exits without reading its input is answered by its '
      'exit code, not a broken pipe', () async {
    // More than a pipe holds, so the write outlives the process for certain:
    // `ssh` that could not connect, a script stopped by `set -e` early.
    final process = await Process.start('sh', [
      '-c',
      'echo refused >&2; exit 3',
    ]);
    final result = await DwSshRunner.feedInput(process, 'x' * (1 << 20));
    expect(result.exitCode, 3);
    expect(result.stderr, contains('refused'));
  });

  test('a command that echoes its input gets all of it back — the output '
      'is drained while the input is written', () async {
    // More than both pipes hold: writing everything before reading anything
    // deadlocks here, `cat` blocked on a full stdout and the write on a full
    // stdin.
    final input = 'x' * (1 << 20);
    final process = await Process.start('cat', const []);
    final result = await DwSshRunner.feedInput(process, input);
    expect(result.exitCode, 0);
    expect(result.stdout.length, input.length);
  }, timeout: const Timeout(Duration(seconds: 20)));
}
