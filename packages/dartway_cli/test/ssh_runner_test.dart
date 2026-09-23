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
}
