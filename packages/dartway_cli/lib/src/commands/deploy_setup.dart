import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';

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
          : 'Would upload deploy/compose.override.yml.',
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

  // Base packages and Docker. Both are no-ops on a server that already has
  // them, which is the common case when setup is re-run for a template change.
  if (!await step(
    'Base packages and Docker',
    () => ssh.run('''
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
    () => ssh.run('''
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

  final override = renderer.composeOverride;
  if (override != null) {
    if (!await step(
      'Compose override',
      // Written under the name Compose loads on its own next to
      // docker-compose.yml, so every later `docker compose` call picks it up
      // without a -f flag to remember.
      () => ssh.runAsWithInput(
        target.deployUser,
        "cat > '${target.appDir}/docker-compose.override.yml'",
        override.readAsStringSync(),
      ),
    )) {
      return 1;
    }
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
    () => ssh.run('''
set -e
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
if docker compose run --rm -T --entrypoint sh certbot -c \\
  "test -f /etc/letsencrypt/live/$certName/fullchain.pem" </dev/null; then
  exit 0
fi
docker compose run --rm -T --entrypoint sh certbot -c "
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
