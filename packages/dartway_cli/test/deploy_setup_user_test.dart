import 'package:dartway_cli/src/commands/deploy_command.dart';
import 'package:dartway_cli/src/commands/deploy_setup.dart';
import 'package:test/test.dart';

import 'support/deploy_fixtures.dart';

/// The shape of the "Deployment user" step's script (#328): a cloud image can
/// already carry a system group named like `deploy_user` — DigitalOcean's
/// Ubuntu 24.04 image ships an empty `admin` group — and plain `adduser`
/// refuses to create a same-named group over it. What the script has to do
/// instead is checked here; the actual behaviour, against a real `adduser`
/// and a real `/etc/sudoers`, is proven in an `ubuntu:24.04` container (see
/// the PR that introduced this test).
void main() {
  final args = DeploySetupCommand().argParser.parse(['--env', 'staging']);

  test(
    'the deployment-user script is idempotent, reuses a colliding group that '
    'is not granted sudo, and guards against one that is',
    () async {
      final ssh = RecordingSsh();
      final exitCode = await runSetup(
        stackVariants()['minimal']!,
        args,
        connection: ssh,
      );
      expect(exitCode, 0);

      // `usermod -aG docker` appears nowhere else in the setup flow.
      final userStep = ssh.issued.singleWhere(
        (c) => c.contains('usermod -aG docker'),
      );

      // Idempotent: an existing user short-circuits everything else.
      expect(userStep, contains('id -u'));
      // A colliding group is reused rather than failing like plain `adduser`.
      expect(userStep, contains('getent group'));
      expect(userStep, contains('--ingroup'));
      // But not blindly: a group a sudoers rule already names is refused,
      // never silently joined.
      expect(userStep, contains('grep -Eq'));
      expect(userStep, contains('/etc/sudoers'));
      expect(userStep, contains('already exists and is granted sudo'));
      // The no-collision path is unchanged.
      expect(
        userStep,
        contains('adduser --disabled-password --gecos ""'),
      );
    },
  );
}
