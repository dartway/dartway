import 'package:dartway_cli/src/deploy/ssh_runner.dart';
import 'package:test/test.dart';

void main() {
  group('privilegedCommand', () {
    // The wrapper is one shell string with the payload inside single quotes,
    // so a quote in the payload is the one thing that can break it — and it
    // breaks silently: the shell runs a truncated command instead of failing.
    test('escapes single quotes so the payload survives the wrapper', () {
      final wrapped = DwSshRunner.privilegedCommand(
        "adduser 'deploy-user' && echo 'done'",
      );

      expect(wrapped, contains(r"adduser '\''deploy-user'\''"));
      expect(wrapped, contains(r"echo '\''done'\''"));
      expect(wrapped, isNot(contains("adduser 'deploy-user'")));
    });

    // Both branches carry the payload: a session that is already root must not
    // depend on sudo being installed, and a session that is not root must not
    // wait for a password.
    test('runs as is under root and through sudo -n otherwise', () {
      final wrapped = DwSshRunner.privilegedCommand('apt-get update');

      expect(wrapped, startsWith(r'if [ "$(id -u)" = 0 ]; then'));
      expect(wrapped, contains("sh -c 'apt-get update'; else"));
      expect(wrapped, contains("sudo -n sh -c 'apt-get update'; fi"));
    });

    test('keeps a multi-line script in one piece', () {
      final wrapped = DwSshRunner.privilegedCommand(
        'set -e\nufw --force enable',
      );

      expect(wrapped, contains("sh -c 'set -e\nufw --force enable'"));
    });
  });
}
