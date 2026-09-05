import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';

import '../deploy/compose_files.dart';
import '../deploy/deploy_target.dart';
import '../deploy/renderer.dart';
import '../deploy/secret_store.dart';
import '../deploy/serverpod_config.dart';
import '../deploy/ssh_runner.dart';
import '../project_layout.dart';

/// Provisions a server and renders the infrastructure it runs on.
///
/// Idempotent throughout: every step either finds what it needs or creates it,
/// and none replaces a value that already exists. Running it against a live
/// server is a supported way to pick up a template change.
Future<int> runSetup(Command<int> command, ArgResults results) async {
  final projectRoot = Directory.current;
  final environment = results.option('env');
  if (environment == null) {
    final known = DwDeployTarget.environmentsIn(projectRoot);
    command.usageException(
      'Specify --env.'
      '${known.isEmpty ? '' : ' Declared: ${known.join(', ')}.'}',
    );
  }

  final layout = ProjectLayout.detect(projectRoot);
  final target = DwDeployTarget.load(
    projectRoot: projectRoot,
    environment: environment,
  );
  final serverpod = DwServerpodConfig.load(
    projectRoot: projectRoot,
    serverPackage: layout.serverPackage,
    environment: environment,
  );

  final ssh = DwSshRunner(
    host: target.host,
    user: results.option('as') ?? target.sshUser,
    identityFile: results.option('identity'),
  );
  final store = DwSecretStore(ssh: ssh, target: target);
  final renderer = DwInfraRenderer(
    projectRoot: projectRoot,
    target: target,
    serverpod: serverpod,
    serverPackage: layout.serverPackage,
    flutterPackage: layout.flutterPackage,
  );

  final dryRun = results.flag('dry-run');

  stdout
    ..writeln('Setup [$environment]')
    ..writeln('  server:  ${ssh.target}, runs as ${target.deployUser}')
    ..writeln('  dir:     ${target.appDir}')
    ..writeln('  store:   ${target.runtimeConfigDir}');

  if (dryRun) {
    stdout
      ..writeln('\n--- docker-compose.yml ---')
      ..writeln(renderer.composeFile)
      ..writeln('--- nginx.conf ---')
      ..writeln(renderer.nginxFile);
    final override = renderer.composeOverride;
    stdout.writeln(
      override == null
          ? 'No deploy/compose.override.yml.'
          : 'deploy/compose.override.yml is merged straight from the '
                'checkout — every Compose call names it, so nothing is '
                'uploaded and a committed change to it takes effect on the '
                'next run.',
    );
    final snippets = renderer.nginxSnippets;
    stdout.writeln(
      snippets.isEmpty
          ? 'No deploy/nginx.d snippets.'
          : 'Would upload ${snippets.length} nginx snippet(s): '
                '${snippets.keys.join(', ')}',
    );
    stdout.writeln('\nDry run — nothing sent.');
    return 0;
  }

  Future<bool> step(String title, Future<DwSshResult> Function() run) async {
    stdout.writeln('\n$title');
    final result = await run();
    if (!result.ok) {
      stderr.writeln('  failed: ${result.firstLine}');
      return false;
    }
    stdout.writeln('  ok');
    return true;
  }

  // Provisioning is root's work, and the session is not always root: cloud
  // images create an ordinary user with passwordless sudo and refuse a root
  // login over SSH. Ask once, here, rather than let `apt-get` answer with
  // "Permission denied" two steps down and leave the reader guessing.
  if (!await step(
    'Root privileges',
    () async {
      // The marker is what separates "connected, and the user has no root"
      // from "never connected at all". Without it an unreachable host, a
      // rejected key or a wrong --identity would all be reported as a
      // privilege problem, and the real reason — which ssh did print — would
      // be thrown away.
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
            'Provisioning installs packages and creates the deployment user, '
            'so it needs one of the two.',
      );
    },
  )) {
    return 1;
  }

  // Base packages and Docker. Both are no-ops on a server that already has
  // them, which is the common case when setup is re-run for a template change.
  if (!await step(
    'Base packages and Docker',
    () => ssh.runPrivileged('''
set -e
if ! command -v docker >/dev/null 2>&1; then
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq
  apt-get install -y -qq ca-certificates curl gnupg git gettext-base
  curl -fsSL https://get.docker.com | sh
fi
systemctl enable --now docker >/dev/null 2>&1 || true
'''),
  )) {
    return 1;
  }

  if (!await step(
    'Deployment user',
    () => ssh.runPrivileged('''
set -e
id -u '${target.deployUser}' >/dev/null 2>&1 || \\
  adduser --disabled-password --gecos "" '${target.deployUser}'
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
    return store.generateMissing(
      section: environment,
      keys: [
        ...DwSecretStore.generatedKeys,
        if (serverpod.managesRedis) 'redis',
      ],
    );
  })) {
    return 1;
  }

  // A private repository over SSH needs a key the server owns. It is generated
  // here rather than sent from this machine so the private half never exists
  // anywhere but the server it belongs to.
  if (target.repo.startsWith('git@')) {
    final key = await ssh.runAs(target.deployUser, '''
set -e
umask 077
install -d -m 700 "\$HOME/.ssh"
if [ ! -f "\$HOME/.ssh/id_ed25519_github" ]; then
  ssh-keygen -t ed25519 -N "" -q -C "${target.deployUser}@${target.host}" \\
    -f "\$HOME/.ssh/id_ed25519_github"
  echo CREATED
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

  // The environment file is assembled on the server so the database password
  // never has to make a round trip through this machine just to be written
  // back where it came from.
  if (!await step(
    'Compose environment file',
    () => ssh.runAs(target.deployUser, '''
set -e
umask 077
store='${target.runtimeConfigDir}/passwords.yaml'
value() {
  awk -v s='$environment' -v k="\$1" '
    /^[^[:space:]#]/ { inside = (\$0 ~ ("^" s ":[[:space:]]*\$")) }
    inside && \$0 ~ ("^[[:space:]]+" k ":") {
      v = \$0; sub(/^[[:space:]]*[A-Za-z0-9_]+:[[:space:]]*/, "", v)
      gsub(/^['"'"'"]|['"'"'"]\$/, "", v); print v; exit
    }
  ' "\$store"
}
{
  echo '# Rendered by "dartway deploy setup". Contains secrets; mode 0600.'
  echo "DB_PASSWORD=\$(value database)"
  echo "REDIS_PASSWORD=\$(value redis)"
} > '${target.appDir}/.env'
chmod 600 '${target.appDir}/.env'
'''),
  )) {
    return 1;
  }

  // A rendered compose file names the database volume. If the server already
  // carries a differently named one, starting the stack would silently create
  // an empty database beside the real data and serve it — the application
  // comes up, answers, and shows nothing. Refuse instead.
  final volumes = await ssh.runAs(
    target.deployUser,
    "docker volume ls --format '{{.Name}}' 2>/dev/null || true",
  );
  final project = target.projectName;
  final existing = volumes.stdout
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.startsWith('${project}_'))
      .toList();
  final expected = '${project}_postgres_data';
  final strangers = existing
      .where((name) => name != expected && name.contains('data'))
      .where((name) => !name.contains('certbot'))
      .toList();
  if (!existing.contains(expected) && strangers.isNotEmpty) {
    stderr.writeln(
      '\nRefusing to continue: this server already has the volume(s) '
      '${strangers.join(', ')}, and the rendered configuration would use '
      '"$expected" instead — a fresh, empty database.\n'
      'Point the existing volume at the postgres service in '
      'deploy/compose.override.yml, then run setup again.',
    );
    return 1;
  }

  if (!await step(
    'Compose and Nginx configuration',
    () => ssh.runAsWithInput(
      target.deployUser,
      "cat > '${target.appDir}/docker-compose.yml'",
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

  // The project's override is never copied. What is written here names it —
  // two lines that Compose loads on its own, so a bare `docker compose` in the
  // checkout applies the same stack the deploy does. A copy taken here would
  // freeze the file as it was on the day setup last ran, and Compose would
  // prefer the frozen one.
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
    'Firewall',
    () => ssh.runPrivileged('''
set -e
# Installed rather than skipped: Ubuntu images ship ufw, minimal Debian and
# several cloud images do not, and a silently skipped firewall looks exactly
# like a configured one.
if ! command -v ufw >/dev/null 2>&1; then
  export DEBIAN_FRONTEND=noninteractive
  # The index is refreshed here rather than trusted: the only other
  # `apt-get update` in this run sits behind "Docker is absent", so on a host
  # that came with Docker there may have been none at all.
  apt-get update -qq
  apt-get install -y -qq ufw
fi
if command -v ufw >/dev/null 2>&1; then
  ufw allow OpenSSH >/dev/null
  ufw allow 80/tcp >/dev/null
  ufw allow 443/tcp >/dev/null
${target.firewallPorts.map((p) => '  ufw allow $p/tcp >/dev/null').join('\n')}
  ufw --force enable >/dev/null
fi
'''),
  )) {
    return 1;
  }

  // Nginx will not start without a certificate file, and certbot cannot issue
  // one until Nginx answers the challenge. A one-day self-signed certificate
  // breaks the circle; the real one replaces it on the first deploy.
  final certName = serverpod.apiServer.publicHost;
  if (!await step(
    'TLS bootstrap certificate',
    () => ssh.runAs(target.deployUser, '''
set -e
cd '${target.appDir}'
${DwComposeFiles.selectFiles}
if ${DwComposeFiles.invoke} run --rm -T --entrypoint sh certbot -c \\
  "test -f /etc/letsencrypt/live/$certName/fullchain.pem" </dev/null; then
  exit 0
fi
${DwComposeFiles.invoke} run --rm -T --entrypoint sh certbot -c "
  mkdir -p /etc/letsencrypt/live/$certName
  openssl req -x509 -nodes -newkey rsa:2048 -days 1 \\
    -keyout /etc/letsencrypt/live/$certName/privkey.pem \\
    -out /etc/letsencrypt/live/$certName/fullchain.pem \\
    -subj '/CN=$certName'
" </dev/null
'''),
  )) {
    return 1;
  }

  stdout
    ..writeln('\nServer is ready.')
    ..writeln('Next: dartway deploy run --env $environment');
  return 0;
}
