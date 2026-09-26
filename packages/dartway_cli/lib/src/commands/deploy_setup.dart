import 'dart:io';

import 'package:args/args.dart';

import '../deploy/compose_files.dart';
import '../deploy/data_volumes.dart';
import '../deploy/renderer.dart';
import '../deploy/secret_store.dart';
import '../deploy/ssh_runner.dart';
import '../deploy/stack.dart';

/// Provisions a server and renders the infrastructure it runs on.
///
/// Idempotent throughout: every step either finds what it needs or creates it,
/// and none replaces a value that already exists. Running it against a live
/// server is the supported way to pick up a change to the rendered files.
///
/// [connection] is a real connection to [stack.target.host] unless given —
/// tests pass a fake so the whole function runs against recorded answers,
/// never a real `ssh` binary.
Future<int> runSetup(
  DwStack stack,
  ArgResults results, {
  DwSshRunner? connection,
}) async {
  final projectRoot = Directory.current;
  final target = stack.target;
  final environment = target.environment;

  final ssh =
      connection ??
      DwSshRunner(
        host: target.host,
        user: results.option('as') ?? target.sshUser,
        identityFile: results.option('identity'),
      );
  final store = DwSecretStore(ssh: ssh, target: target);
  final renderer = DwStackRenderer(stack: stack, projectRoot: projectRoot);

  stdout
    ..writeln('Setup [$environment]')
    ..writeln('  server:  ${ssh.target}, runs as ${target.deployUser}')
    ..writeln('  dir:     ${target.appDir}')
    ..writeln('  store:   ${store.file}')
    ..writeln('  serves:  ${target.servedDomains.join(', ')}');

  if (results.flag('dry-run')) {
    stdout
      ..writeln('\n--- docker-compose.yml ---')
      ..writeln(renderer.composeFile)
      ..writeln('--- nginx.conf ---')
      ..writeln(renderer.nginxFile);
    final override = renderer.composeOverride;
    stdout.writeln(
      override == null
          ? 'No deploy/compose.override.yml.'
          : 'deploy/compose.override.yml is merged straight from the checkout '
                '— every Compose call names it, so nothing is uploaded and a '
                'committed change to it takes effect on the next run.',
    );
    final snippets = renderer.nginxSnippets;
    stdout
      ..writeln(
        snippets.isEmpty
            ? 'No deploy/nginx.d snippets.'
            : 'Would upload ${snippets.length} nginx snippet(s): '
                  '${snippets.keys.join(', ')}',
      )
      ..writeln(
        'Would generate, where absent: '
        '${stack.generatedSecrets.keys.join(', ')}',
      )
      ..writeln('\nDry run — nothing sent.');
    return 0;
  }

  /// Runs one provisioning step. [report] prints what the step said on
  /// success — for the steps whose output is their result, not for a package
  /// manager's progress.
  Future<bool> step(
    String title,
    Future<DwSshResult> Function() run, {
    bool report = false,
  }) async {
    stdout.writeln('\n$title');
    final result = await run();
    if (!result.ok) {
      stderr.writeln('  failed: ${result.firstLine}');
      final rest = result.stderr.trim();
      if (rest.isNotEmpty && rest != result.firstLine) {
        for (final line in rest.split('\n')) {
          stderr.writeln('    $line');
        }
      }
      return false;
    }
    final said = result.stdout.trim();
    stdout.writeln(
      !report || said.isEmpty
          ? '  ok'
          : '  ok — ${said.split('\n').join('; ')}',
    );
    return true;
  }

  // Provisioning is root's work, and the session is not always root: cloud
  // images create an ordinary user with passwordless sudo and refuse a root
  // login over SSH. Ask once, here, rather than let `apt-get` answer with
  // "Permission denied" two steps down.
  if (!await step('Root privileges', () async {
    // The marker separates "connected, and the user has no root" from "never
    // connected at all", so an unreachable host is not reported as a
    // privilege problem.
    const denied = 'dw-no-root';
    final result = await ssh.run(
      'if [ "\$(id -u)" = 0 ]; then echo root; '
      'elif sudo -n true 2>/dev/null; then echo sudo; '
      'else echo $denied; exit 1; fi',
    );
    if (result.ok || !result.stdout.contains(denied)) {
      return result;
    }
    return DwSshResult(
      exitCode: result.exitCode,
      stdout: '',
      stderr:
          '${ssh.target} is neither root nor allowed passwordless sudo. '
          'Provisioning installs packages and creates the deployment user, so '
          'it needs one of the two.',
    );
  })) {
    return 1;
  }

  // Both are no-ops on a server that already has them, which is the common
  // case when setup is re-run for a change to the rendered files.
  if (!await step(
    'Base packages and Docker',
    () => ssh.runPrivileged('''
set -e
if ! command -v docker >/dev/null 2>&1; then
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq
  apt-get install -y -qq ca-certificates curl gnupg git openssl
  curl -fsSL https://get.docker.com | sh
fi
systemctl enable --now docker >/dev/null 2>&1 || true
docker compose version >/dev/null
'''),
  )) {
    return 1;
  }

  // A cloud image can already ship a system group named like the deploy
  // user — DigitalOcean's Ubuntu 24.04 image has an empty `admin` group —
  // and plain `adduser` refuses to create a same-named group over it (#328).
  // `deploy_user`'s own default (`dw_admin`) collides with nothing stock, so
  // this only bites an operator's explicit choice. Reusing the group with
  // `--ingroup` fixes the ordinary case, but not blindly: a sudoers rule can
  // already grant that group privileges (`%admin` on Ubuntu's stock sudoers;
  // `%sudo` on both Debian's and Ubuntu's), and joining it would silently
  // hand the "unprivileged" deploy user a path to root. Refuse instead and
  // let the operator pick a name that does not collide.
  if (!await step(
    'Deployment user',
    () => ssh.runPrivileged('''
set -e
if id -u '${target.deployUser}' >/dev/null 2>&1; then
  : # already provisioned — idempotent re-run
elif getent group '${target.deployUser}' >/dev/null 2>&1; then
  if grep -Eq '^[[:space:]]*%${target.deployUser}[[:space:]]' \\
      /etc/sudoers /etc/sudoers.d/* 2>/dev/null; then
    echo "fatal: group '${target.deployUser}' already exists and is granted privileges by sudoers (/etc/sudoers or /etc/sudoers.d) (%${target.deployUser}) - pick a deploy_user in deploy/config.yaml that does not collide with it" >&2
    exit 1
  fi
  adduser --disabled-password --gecos "" --ingroup '${target.deployUser}' '${target.deployUser}'
else
  adduser --disabled-password --gecos "" '${target.deployUser}'
fi
usermod -aG docker '${target.deployUser}'
'''),
  )) {
    return 1;
  }

  if (!await step('Secret store', () async {
    final created = await store.ensureDirectory();
    if (!created.ok) {
      return created;
    }
    final generated = await store.generateMissing(stack.generatedSecrets);
    if (!generated.ok) return generated;
    final names = generated.stdout
        .trim()
        .split('\n')
        .where((l) => l.isNotEmpty);
    return DwSshResult(
      exitCode: 0,
      stdout: names.isEmpty
          ? 'every generated secret already present'
          : 'generated ${names.join(', ')}',
      stderr: '',
    );
  }, report: true)) {
    return 1;
  }

  // A private repository over SSH needs a key the server owns, generated here
  // so the private half never exists anywhere but the server.
  if (target.repo.startsWith('git@')) {
    final key = await ssh.runAs(target.deployUser, '''
set -e
umask 077
install -d -m 700 "\$HOME/.ssh"
if [ ! -f "\$HOME/.ssh/id_ed25519_github" ]; then
  ssh-keygen -t ed25519 -N "" -q -C "${target.deployUser}@${target.host}" \\
    -f "\$HOME/.ssh/id_ed25519_github"
fi
if ! grep -q "id_ed25519_github" "\$HOME/.ssh/config" 2>/dev/null; then
  printf 'Host github.com\\n  IdentityFile ~/.ssh/id_ed25519_github\\n  IdentitiesOnly yes\\n' \\
    >> "\$HOME/.ssh/config"
  chmod 600 "\$HOME/.ssh/config"
fi
cat "\$HOME/.ssh/id_ed25519_github.pub"
''');
    if (!key.ok) {
      stderr.writeln('\nCannot prepare the repository key: ${key.firstLine}');
      return 1;
    }

    final reachable = await ssh.runAs(
      target.deployUser,
      'ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new '
      '-T git@github.com 2>&1 | grep -q "successfully authenticated"',
    );
    if (!reachable.ok) {
      final publicKey = key.stdout
          .split('\n')
          .firstWhere(
            (line) => line.startsWith('ssh-'),
            orElse: () => key.stdout.trim(),
          );
      stderr
        ..writeln('\nThe server cannot reach ${target.repo} yet.')
        ..writeln(
          'Register this key as a read-only deploy key on the repository, '
          'then run setup again:',
        )
        ..writeln('\n$publicKey\n')
        ..writeln(
          'Read-only is deliberate: the server only ever fetches, and a '
          'writable key turns access to the box into access to the repository.',
        );
      return 1;
    }
    stdout.writeln('\nRepository key\n  ok');
  }

  if (!await step(
    'Repository checkout',
    () => ssh.runAs(target.deployUser, '''
set -e
if [ ! -d '${target.appDir}/.git' ]; then
  git clone '${target.repo}' '${target.appDir}'
fi
cd '${target.appDir}'
git fetch origin '${target.branch}' --prune
git checkout -B '${target.branch}' 'origin/${target.branch}'
'''),
  )) {
    return 1;
  }

  // Only the generated secrets are demanded here: they are the ones the
  // compose file itself interpolates, and every Compose call below needs them.
  // A project secret still to be delivered does not stop provisioning — it
  // stops `deploy run`, which renders this file again with the whole list.
  if (!await step(
    'Environment file (generated secrets)',
    () => store.renderEnvironment(
      appDir: target.appDir,
      required: stack.generatedSecrets.keys.toList(),
      reserved: stack.reservedSecretKeys,
    ),
    report: true,
  )) {
    return 1;
  }

  // A rendered compose file names its data volumes. If an expected one does
  // not exist while another data volume of this project does, starting the
  // stack would silently create it empty beside the real data and serve it —
  // the same guard `deploy run` runs again right before it starts anything,
  // because a server is not always `setup` again after a config change.
  final volumes = await ssh.runAs(
    target.deployUser,
    "docker volume ls --format '{{.Name}}'",
  );
  if (!volumes.ok) {
    stderr.writeln(
      '\nCannot list Docker volumes as ${target.deployUser}: '
      '${volumes.firstLine}',
    );
    return 1;
  }
  final volumeVerdict = judgeDataVolumes(
    volumeListing: volumes.stdout,
    projectPrefix: target.projectName,
    expectedDataVolumes: stack.dataVolumeNames,
  );
  if (!volumeVerdict.ok) {
    stderr.writeln('\nRefusing to continue: ${volumeVerdict.detail}');
    return 1;
  }

  if (!await step(
    'Compose configuration',
    () => ssh.runAsWithInput(
      target.deployUser,
      "cat > '${target.appDir}/${DwComposeFiles.rendered}'",
      renderer.composeFile,
    ),
  )) {
    return 1;
  }

  if (!await step(
    'Nginx configuration',
    () => ssh.runAsWithInput(
      target.deployUser,
      "install -d '${target.appDir}/nginx.d/http' '${target.appDir}/nginx.d/api' "
      "'${target.appDir}/nginx.d/app' && "
      "cat > '${target.appDir}/nginx.conf'",
      renderer.nginxFile,
    ),
  )) {
    return 1;
  }

  // The project's override is never copied; what is written here names it.
  if (!await step(
    'Bridge a bare docker compose to the project override',
    () => ssh.runAs(target.deployUser, DwComposeFiles.bridgeIn(target.appDir)),
  )) {
    return 1;
  }

  for (final entry in renderer.nginxSnippets.entries) {
    if (!await step(
      'Nginx snippet ${entry.key}',
      () => ssh.runAsWithInput(
        target.deployUser,
        "install -d \"\$(dirname '${target.appDir}/nginx.d/${entry.key}')\" && "
        "cat > '${target.appDir}/nginx.d/${entry.key}'",
        entry.value.readAsStringSync(),
      ),
    )) {
      return 1;
    }
  }

  if (!await step(
    'Compose accepts the rendered stack',
    () => ssh.runAs(
      target.deployUser,
      DwComposeFiles.commandIn(target.appDir, 'config --quiet'),
    ),
  )) {
    return 1;
  }

  if (!await step(
    'Firewall',
    () => ssh.runPrivileged('''
set -e
# Installed rather than skipped: minimal Debian and several cloud images ship
# without ufw, and a silently skipped firewall looks exactly like a configured
# one.
if ! command -v ufw >/dev/null 2>&1; then
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq
  apt-get install -y -qq ufw
fi
ufw allow OpenSSH >/dev/null
ufw allow 80/tcp >/dev/null
ufw allow 443/tcp >/dev/null
${target.firewallPorts.map((p) => 'ufw allow $p/tcp >/dev/null').join('\n')}
ufw --force enable >/dev/null
ufw status | grep -q "Status: active"
'''),
  )) {
    return 1;
  }

  // Nginx will not start without a certificate file, and certbot cannot issue
  // one until Nginx answers the challenge. A one-day self-signed certificate
  // breaks the circle; `deploy run` replaces it with the real one.
  final certName = target.apiDomain;
  if (!await step(
    'TLS bootstrap certificate',
    () => ssh.runAs(target.deployUser, '''
set -e
cd '${target.appDir}'
${DwComposeFiles.selectFiles}
if ${DwComposeFiles.invoke} run --rm -T --entrypoint sh ${DwStack.certbotService} -c \\
  "test -f /etc/letsencrypt/live/$certName/fullchain.pem" </dev/null; then
  echo "a certificate for $certName is already in place"
  exit 0
fi
${DwComposeFiles.invoke} run --rm -T --entrypoint sh ${DwStack.certbotService} -c "
  mkdir -p /etc/letsencrypt/live/$certName
  openssl req -x509 -nodes -newkey rsa:2048 -days 1 \\
    -keyout /etc/letsencrypt/live/$certName/privkey.pem \\
    -out /etc/letsencrypt/live/$certName/fullchain.pem \\
    -subj '/CN=$certName'
" </dev/null
echo "wrote a one-day self-signed certificate for $certName"
'''),
    report: true,
  )) {
    return 1;
  }

  final outstanding = stack.requiredSecretKeys
      .where((key) => !stack.generatedSecrets.containsKey(key))
      .toList();
  stdout.writeln('\nServer is ready.');
  if (outstanding.isNotEmpty) {
    stdout.writeln(
      'Before the first run, deliver: ${outstanding.join(', ')} '
      '(dartway deploy secret set <KEY> --env $environment)',
    );
  }
  stdout.writeln('Next: dartway deploy run --env $environment');
  return 0;
}
