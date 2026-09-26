@Tags(['docker'])
library;

import 'dart:io';

import 'package:dartway_cli/src/commands/deploy_command.dart';
import 'package:dartway_cli/src/commands/deploy_setup.dart';
import 'package:dartway_cli/src/deploy/deploy_target.dart';
import 'package:dartway_cli/src/deploy/stack.dart';
import 'package:test/test.dart';

import 'support/deploy_fixtures.dart';

/// The "Deployment user" step's real behaviour (#328), against a real
/// `adduser` and a real `/etc/sudoers` — `deploy_setup_user_test.dart` proves
/// the script's shape through a recorder, which cannot tell a working guard
/// from an inverted one (a mutant that joins every colliding group instead
/// of refusing a sudo-granting one still "contains '--ingroup'"). This test
/// runs the exact command the code sends over SSH, unmodified, as root in a
/// throwaway `ubuntu:24.04` container.
///
/// Checked by hand that this is not vacuous: inverting the guard in
/// `deploy_setup.dart` (`if grep …` → `if ! grep …`) turns the third test
/// red — see the PR this test was added in for the transcript.
void main() {
  late String container;

  Future<ProcessResult> exec(String command) =>
      Process.run('docker', ['exec', container, 'sh', '-c', command]);

  setUpAll(() async {
    final run = await Process.run('docker', [
      'run',
      '-d',
      'ubuntu:24.04',
      'sleep',
      'infinity',
    ]);
    expect(run.exitCode, 0, reason: '${run.stderr}');
    container = (run.stdout as String).trim();

    // The one thing every scenario needs: `adduser`/`usermod` (not on the
    // base image), `sudo` (so a real /etc/sudoers exists to guard against),
    // and the `docker` group the step's last line always joins.
    final setup = await exec(
      'apt-get update -qq && apt-get install -y -qq adduser sudo && '
      'groupadd docker',
    );
    expect(setup.exitCode, 0, reason: '${setup.stderr}');
  });

  tearDownAll(() => Process.run('docker', ['rm', '-f', container]));

  /// The exact command `runSetup`'s "Deployment user" step sends over SSH
  /// for [deployUser] — read off a real run through `RecordingSsh`, so this
  /// proves the code's own script rather than a hand-copied stand-in for it.
  Future<String> deploymentUserCommand(String deployUser) async {
    final target = DwDeployTarget.parse(
      '''
staging:
  host: 203.0.113.10
  ssh_user: root
  deploy_user: $deployUser
  os: ubuntu
  repo: git@github.com:acme/shop.git
  branch: master
  ssl_email: ops@example.com
  api_domain: api.example.com
  app_domain: app.example.com
''',
      environment: 'staging',
    );
    final stack = DwStack(
      target: target,
      serverPackage: 'shop_server',
      flutterPackage: 'shop_flutter',
    );
    final ssh = RecordingSsh();
    final args = DeploySetupCommand().argParser.parse(['--env', 'staging']);
    await runSetup(stack, args, connection: ssh);
    return ssh.issued.singleWhere((c) => c.contains('usermod -aG docker'));
  }

  test('no colliding group: the user and its own group are created', () async {
    final command = await deploymentUserCommand('freshuser');

    final result = await exec(command);
    expect(result.exitCode, 0, reason: '${result.stderr}');

    final id = await exec('id freshuser');
    expect(id.exitCode, 0);
    expect('${id.stdout}', contains('(freshuser)'));
    expect('${id.stdout}', contains('(docker)'));
  });

  test('a plain colliding group is reused via its existing gid', () async {
    final group = await exec('groupadd --gid 3000 opsuser');
    expect(group.exitCode, 0, reason: '${group.stderr}');
    final command = await deploymentUserCommand('opsuser');

    final result = await exec(command);
    expect(result.exitCode, 0, reason: '${result.stderr}');

    final id = await exec('id opsuser');
    expect('${id.stdout}', contains('gid=3000(opsuser)'));
    expect('${id.stdout}', contains('(docker)'));
  });

  test(
    'a group already granted privileges by sudoers is refused, never joined',
    () async {
      // Mirrors #328 exactly: DigitalOcean's Ubuntu 24.04 image ships an
      // empty `admin` group, and Ubuntu's stock /etc/sudoers grants it root
      // through `%admin ALL=(ALL) ALL`.
      final group = await exec('groupadd --gid 110 admin');
      expect(group.exitCode, 0, reason: '${group.stderr}');
      final command = await deploymentUserCommand('admin');

      final result = await exec(command);
      expect(result.exitCode, 1);
      expect(
        '${result.stderr}',
        contains('already exists and is granted privileges by sudoers'),
      );
      expect('${result.stderr}', contains('%admin'));

      // Refused, not silently joined: the user was never created.
      final id = await exec('id admin');
      expect(id.exitCode, isNot(0));
    },
  );

  test('re-running on an already-provisioned user is a no-op', () async {
    final command = await deploymentUserCommand('twiceuser');

    final first = await exec(command);
    expect(first.exitCode, 0, reason: '${first.stderr}');

    final second = await exec(command);
    expect(second.exitCode, 0, reason: '${second.stderr}');
  });
}
