import 'dart:io';

import 'package:yaml/yaml.dart';

import '../checker/dw_check_type.dart';
import 'compose_files.dart';
import 'deploy_check.dart';
import 'deploy_target.dart';
import 'image_registry.dart';
import 'local_secrets_file.dart';
import 'outside_probe.dart';
import 'secret_store.dart';
import 'ssh_runner.dart';
import 'stack.dart';

/// Checks that need the network: DNS, a registry, the server over SSH, and
/// the deployed site over HTTPS.
const List<DwDeployCheck> dwRemoteDeployChecks = [
  DwDeployCheck(
    id: 'dns-public-hosts',
    title: 'Every served domain resolves to the deployment host',
    stage: DwDeployCheckStage.remote,
    severity: DwCheckSeverity.error,
    evaluate: _checkDnsPublicHosts,
  ),
  DwDeployCheck(
    id: 'images-resolve',
    title: 'Every pinned base image resolves from its registry',
    stage: DwDeployCheckStage.remote,
    severity: DwCheckSeverity.error,
    evaluate: _checkImagesResolve,
  ),
  DwDeployCheck(
    id: 'ssh-reachable',
    title: 'The server accepts a key-based SSH connection',
    stage: DwDeployCheckStage.remote,
    severity: DwCheckSeverity.error,
    requiresSsh: true,
    evaluate: _checkSshReachable,
  ),
  DwDeployCheck(
    id: 'deploy-user',
    title: 'The deployment user exists',
    stage: DwDeployCheckStage.remote,
    severity: DwCheckSeverity.error,
    requiresSsh: true,
    evaluate: _checkDeployUser,
  ),
  DwDeployCheck(
    id: 'docker-available',
    title: 'Docker Compose is usable by the deployment user',
    stage: DwDeployCheckStage.remote,
    severity: DwCheckSeverity.error,
    requiresSsh: true,
    evaluate: _checkDockerAvailable,
  ),
  DwDeployCheck(
    id: 'runtime-secrets',
    title: 'Every required secret is in the server store, with a value',
    stage: DwDeployCheckStage.remote,
    severity: DwCheckSeverity.error,
    requiresSsh: true,
    evaluate: _checkRuntimeSecrets,
  ),
  DwDeployCheck(
    id: 'secret-files',
    title: 'Declared secret files reach the server container',
    stage: DwDeployCheckStage.remote,
    severity: DwCheckSeverity.error,
    requiresSsh: true,
    evaluate: _checkSecretFiles,
  ),
  DwDeployCheck(
    id: 'database-reachable',
    title: 'An external database accepts the stored credentials over TLS',
    stage: DwDeployCheckStage.remote,
    severity: DwCheckSeverity.error,
    requiresSsh: true,
    evaluate: _checkDatabaseReachable,
  ),
  DwDeployCheck(
    id: 'secrets-match-local',
    title: 'The server store and the local secrets file hold the same keys',
    stage: DwDeployCheckStage.remote,
    severity: DwCheckSeverity.warning,
    requiresSsh: true,
    evaluate: _checkSecretsMatchLocal,
  ),
  DwDeployCheck(
    id: 'outside',
    title: 'The deployed hosts answer as a browser and an app expect',
    stage: DwDeployCheckStage.remote,
    // An observation, not a reading: these are the answers a browser gets.
    severity: DwCheckSeverity.error,
    // HTTPS, not SSH — and it must still run when the SSH checks have failed.
    evaluate: _checkOutside,
  ),
];

/// Addresses [hostOrAddress] resolves to; empty when it does not resolve.
Future<Set<String>> _resolve(String hostOrAddress) async {
  final literal = InternetAddress.tryParse(hostOrAddress);
  if (literal != null) {
    return {literal.address};
  }
  try {
    final addresses = await InternetAddress.lookup(hostOrAddress);
    return addresses.map((address) => address.address).toSet();
  } on SocketException {
    return const {};
  }
}

Future<DwDeployVerdict> _checkDnsPublicHosts(DwDeployContext context) async {
  final expected = await _resolve(context.target.host);
  if (expected.isEmpty) {
    return DwDeployVerdict.fail(
      'host ${context.target.host} does not resolve',
      fix: 'deploy/config.yaml must name a reachable address.',
    );
  }

  final domains = context.target.servedDomains;
  final unresolved = <String>[];
  final mismatched = <String>[];
  for (final domain in domains) {
    final addresses = await _resolve(domain);
    if (addresses.isEmpty) {
      unresolved.add(domain);
      continue;
    }
    if (!addresses.any(expected.contains)) {
      mismatched.add('$domain -> ${addresses.join(', ')}');
    }
  }

  if (unresolved.isEmpty && mismatched.isEmpty) {
    return DwDeployVerdict.pass(
      '${domains.length} domains point at ${expected.join(', ')}',
    );
  }
  return DwDeployVerdict.fail(
    [
      if (unresolved.isNotEmpty) 'no DNS record: ${unresolved.join(', ')}',
      if (mismatched.isNotEmpty) 'points elsewhere: ${mismatched.join('; ')}',
    ].join(' | '),
    fix:
        'Certificate issuance fails for a domain that does not reach this '
        "host, and repeated failures hit the Let's Encrypt rate limit. "
        'Resolved through the local resolver, so a record changed minutes '
        'ago may still be cached here.',
  );
}

/// Every base image the stack pulls (Postgres, nginx, certbot, and the
/// bundled storage and its init image), resolved against its own registry
/// before `deploy run` builds anything — the failure this used to be found at
/// only once the run reached the step that starts that image (#331).
Future<DwDeployVerdict> _checkImagesResolve(DwDeployContext context) =>
    evaluateImagesResolve(context.stack.pinnedImages, DwImageRegistry());

/// The logic of the `images-resolve` check, apart from where its inputs come
/// from: [DwDeployContext.stack] and a real [DwImageRegistry] in production,
/// a fixed image list and a [DwImageRegistry] pointed at a fake server in
/// `deploy_remote_checks_test.dart` — a check that always answered pass
/// regardless of what [registry] says would be invisible to a test that only
/// ever went through [DwDeployContext], since building one needs no registry
/// at all.
///
/// A transient answer ([DwImageResolution.transient]) never fails the
/// deploy on its own — the network hiccup was this machine's, not a fact
/// about the image — but it is never silent either: it turns pass into skip,
/// naming what could not be checked.
Future<DwDeployVerdict> evaluateImagesResolve(
  List<(String, String)> images,
  DwImageRegistry registry,
) async {
  final failed = <String>[];
  final unchecked = <String>[];
  for (final (label, image) in images) {
    final result = await registry.resolve(image);
    if (result.ok) continue;
    if (result.transient) {
      unchecked.add('$label ($image): ${result.detail}');
    } else {
      failed.add('$label ($image): ${result.detail}');
    }
  }
  if (failed.isNotEmpty) {
    return DwDeployVerdict.fail(
      [
        ...failed,
        if (unchecked.isNotEmpty) 'also could not ask: ${unchecked.join(' | ')}',
      ].join(' | '),
      fix:
          'A pinned tag that no longer resolves has to be repinned in the '
          'framework itself (packages/dartway_cli/lib/src/deploy/stack.dart) — '
          'file it there. This is exactly the failure #331 fixed once already, '
          'for a different image whose registries had all stopped serving it.',
    );
  }
  if (unchecked.isNotEmpty) {
    return DwDeployVerdict.skip(
      'could not ask: ${unchecked.join(' | ')}',
    );
  }
  return DwDeployVerdict.pass(
    '${images.length} pinned image(s): ${images.map((e) => e.$2).join(', ')}',
  );
}

Future<DwDeployVerdict> _checkSshReachable(DwDeployContext context) async {
  final result = await context.ssh!.run('id -un');
  if (result.ok) {
    return DwDeployVerdict.pass(
      'connected to ${context.ssh!.target} as ${result.firstLine}',
    );
  }
  return DwDeployVerdict.fail(
    result.firstLine.isEmpty ? 'connection failed' : result.firstLine,
    fix:
        'Key-based access is required — the check never prompts for a '
        'password. Add your public key to the server, or pass --identity.',
  );
}

Future<DwDeployVerdict> _checkDeployUser(DwDeployContext context) async {
  final user = context.target.deployUser;
  final result = await context.ssh!.run("id -un '$user'");
  if (result.ok) {
    return DwDeployVerdict.pass('$user exists');
  }
  return DwDeployVerdict.fail(
    'no user "$user" on the server',
    fix:
        'Run "dartway deploy setup" first — it creates the unprivileged user '
        'the deployment runs as.',
  );
}

Future<DwDeployVerdict> _checkDockerAvailable(DwDeployContext context) async {
  final result = await context.ssh!.runAs(
    context.target.deployUser,
    'docker compose version',
  );
  if (result.ok) {
    return DwDeployVerdict.pass(result.firstLine);
  }
  return DwDeployVerdict.fail(
    result.firstLine.isEmpty ? 'docker compose unavailable' : result.firstLine,
    fix:
        'Docker must be installed and the deployment user must belong to the '
        'docker group.',
  );
}

Future<DwDeployVerdict> _checkRuntimeSecrets(DwDeployContext context) async {
  final store = DwSecretStore(ssh: context.ssh!, target: context.target);
  final present = await store.readKeyNames();
  if (!present.ok) {
    return DwDeployVerdict.fail(
      'no readable ${store.file}',
      fix:
          'Create the store with "dartway deploy secret init --env '
          '${context.target.environment}" — secrets are generated on the '
          'server and never live in Git.',
    );
  }
  final filled = await store.readNonEmptyKeyNames();

  final required = context.stack.requiredSecretKeys;
  final missing = required
      .where((key) => !present.names.contains(key))
      .toList();
  final empty = required
      .where((key) => present.names.contains(key))
      .where((key) => !filled.names.contains(key))
      .toList();
  final reserved =
      present.names.where(context.stack.reservedSecretKeys.contains).toList()
        ..sort();

  if (missing.isEmpty && empty.isEmpty && reserved.isEmpty) {
    return DwDeployVerdict.pass(
      '${required.length} required of ${present.names.length} stored, '
      'every one set',
    );
  }
  return DwDeployVerdict.fail(
    [
      if (missing.isNotEmpty) 'missing: ${missing.join(', ')}',
      if (empty.isNotEmpty) 'empty: ${empty.join(', ')}',
      if (reserved.isNotEmpty)
        'set by the compose file, must not be stored: ${reserved.join(', ')}',
    ].join(' | '),
    fix:
        'Generated keys come from "dartway deploy secret init"; the rest are '
        'yours to deliver with "dartway deploy secret set <KEY>". The deploy '
        'refuses to render the environment until this passes.',
  );
}

/// Whether a declared file is where the application will look for it.
///
/// "Is it on the server?" is not the question the deploy dies on: a file can
/// be delivered and still be invisible from inside the container. So the
/// answer comes from the configuration Compose itself will run — the rendered
/// file merged with the project's override — with the file's own path in it.
Future<DwDeployVerdict> _checkSecretFiles(DwDeployContext context) async {
  final declared = context.target.requiredSecretFiles;
  if (declared.isEmpty) {
    return const DwDeployVerdict.pass('none declared');
  }

  final store = DwSecretStore(ssh: context.ssh!, target: context.target);
  final listing = await store.listFiles();
  if (!listing.ok) {
    return DwDeployVerdict.fail(
      'cannot list ${store.directory}',
      fix: 'Run "dartway deploy setup", which creates the store.',
    );
  }
  final undelivered = declared
      .where((name) => !listing.names.contains(name))
      .toList();
  if (undelivered.isNotEmpty) {
    return DwDeployVerdict.fail(
      'missing in ${store.directory}: ${undelivered.join(', ')}',
      fix: 'Deliver them with "dartway deploy secret put-file".',
    );
  }

  final configuration = await context.ssh!.runAs(
    context.target.deployUser,
    DwComposeFiles.commandIn(context.target.appDir, 'config --no-interpolate'),
  );
  if (!configuration.ok) {
    return DwDeployVerdict.fail(
      'cannot read the compose configuration in ${context.target.appDir}: '
      '${configuration.firstLine}',
      fix:
          'The deploy runs whatever this command prints, so until it answers, '
          'nothing can be said about what the container will see. A server '
          'with no rendered ${DwComposeFiles.rendered} needs "dartway deploy '
          'setup --env ${context.target.environment}"; otherwise the fault is '
          'in ${DwComposeFiles.projectOverride}.',
    );
  }

  final Map<String, String> mounts;
  try {
    mounts = dwServiceMounts(configuration.stdout, DwStack.serverService);
  } on YamlException catch (error) {
    return DwDeployVerdict.fail(
      'the compose configuration is unreadable: ${error.message}',
    );
  }

  final unmounted = declared
      .where((name) => !mounts.containsKey('${store.directory}/$name'))
      .toList();
  if (unmounted.isEmpty) {
    final where = declared
        .map((name) => '$name -> ${mounts['${store.directory}/$name']}')
        .join(', ');
    return DwDeployVerdict.pass('${declared.length} file(s) mounted: $where');
  }
  return DwDeployVerdict.fail(
    'delivered but not mounted into ${DwStack.serverService}: '
    '${unmounted.join(', ')}',
    fix:
        'The rendered ${DwComposeFiles.rendered} on the server predates the '
        'declaration. Re-render it with "dartway deploy setup --env '
        '${context.target.environment}", which is idempotent and safe on a '
        'live server; each declared file is then mounted read-only at '
        '${DwStack.secretFilesDir}/<name>.',
  );
}

/// Bind-mount sources of [service], mapped to where they land inside the
/// container, as Compose itself resolves them. Both spellings are accepted:
/// `docker compose config` normalises volumes to the long form, and a short
/// `source:target:ro` string must not read as "nothing is mounted".
Map<String, String> dwServiceMounts(String configuration, String service) {
  final document = loadYaml(configuration);
  final services = document is YamlMap ? document['services'] : null;
  final definition = services is YamlMap ? services[service] : null;
  final volumes = definition is YamlMap ? definition['volumes'] : null;
  final mounts = <String, String>{};
  if (volumes is! YamlList) {
    return mounts;
  }
  for (final entry in volumes) {
    if (entry is YamlMap) {
      final source = entry['source'];
      final target = entry['target'];
      if (source != null && target != null) {
        mounts[source.toString()] = target.toString();
      }
    } else if (entry is String) {
      final parts = entry.split(':');
      if (parts.length >= 2) {
        mounts[parts[0]] = parts[1];
      }
    }
  }
  return mounts;
}

/// Whether a real connection to `database: external`'s Postgres succeeds, and
/// why not when it does not.
///
/// A managed provider's firewall is usually "trusted sources" — the droplet's
/// own address, not this machine's — so the attempt runs *on the deployment
/// host* over SSH, exactly where the deployed server will connect from. A bare
/// TCP probe would miss the two failures that matter most for a managed
/// database: wrong credentials and a server that does not actually speak TLS,
/// so this asks a real one-off Postgres client (the pinned [DwStack
/// .postgresImage], never built or run otherwise in `database: external`) to
/// authenticate and run a query with `sslmode=require`.
Future<DwDeployVerdict> _checkDatabaseReachable(DwDeployContext context) async {
  if (context.target.database != DwDatabaseMode.external) {
    return const DwDeployVerdict.skip(
      'database: bundled — nothing external to reach',
    );
  }
  final store = DwSecretStore(ssh: context.ssh!, target: context.target);
  final image = context.stack.resolvedImage(DwStack.postgresImage);
  final result = await context.ssh!.runAs(
    context.target.deployUser,
    dwDatabaseReachabilityScript(
      storeFile: store.file,
      image: image,
      environment: context.target.environment,
    ),
  );
  final verdict = dwJudgeDatabaseReachable(result);
  if (verdict.ok) {
    return DwDeployVerdict.pass(verdict.detail);
  }
  return DwDeployVerdict.fail(
    verdict.detail,
    fix:
        'Deliver DW_DATABASE_HOST, _PORT, _NAME, _USER and _PASSWORD with '
        '"dartway secret set <KEY> --env ${context.target.environment}" — the '
        'exact values a managed provider hands out. Then check its firewall '
        "admits this host (trusted sources / the droplet's address) and that "
        'it requires TLS: this check always connects with sslmode=require, '
        'and does not yet verify the server\'s certificate '
        '(dartway/dartway, "verify-full with a CA file" is a separate issue).',
  );
}

/// The script [_checkDatabaseReachable] runs on the deployment host: a
/// throwaway Postgres client container attempts a real, encrypted connection
/// with whatever `DW_DATABASE_*` the secret store holds.
///
/// The credentials never leave the server and never appear on a command line
/// `ps` could show: they are read out of the store *there*, written to a
/// `chmod 600` temporary file in Docker's `--env-file` form (`PG*`, which
/// `psql` reads on its own), handed to `docker run --env-file`, and removed.
/// [network] is read by nothing this ships — it exists so a test can attach
/// the throwaway client to the same Docker network as a fake database instead
/// of reaching across the loopback interface, which a container cannot do.
String dwDatabaseReachabilityScript({
  required String storeFile,
  required String image,
  String environment = '<env>',
  String? network,
}) {
  const pgNameOf = {
    'HOST': 'PGHOST',
    'PORT': 'PGPORT',
    'NAME': 'PGDATABASE',
    'USER': 'PGUSER',
    'PASSWORD': 'PGPASSWORD',
  };
  final gets = pgNameOf.entries
      .map((entry) => 'dw_get DW_DATABASE_${entry.key} ${entry.value}')
      .join('\n');
  final networkFlag = network == null ? '' : "--network '$network' ";
  return '''
set -e
umask 077
store='$storeFile'
if [ ! -s "\$store" ]; then
  echo "ERROR: no secret store at \$store. Run: dartway secret init --env $environment" >&2
  exit 1
fi
dw_env=\$(mktemp)
trap 'rm -f "\$dw_env"' EXIT
dw_missing=""
dw_get() {
  key=\$1
  target=\$2
  line=\$(grep -E "^\${key}='" "\$store" || true)
  if [ -z "\$line" ]; then dw_missing="\$dw_missing \$key"; return; fi
  value=\$(printf '%s' "\$line" | sed -e "s/^\${key}='//" -e "s/'\\\$//")
  printf '%s\\n' "\$target=\$value" >> "\$dw_env"
}
$gets
if [ -n "\$dw_missing" ]; then
  echo "ERROR: missing in the secret store:\$dw_missing" >&2
  exit 1
fi
{
  echo "PGSSLMODE=require"
  echo "PGCONNECT_TIMEOUT=10"
} >> "\$dw_env"
chmod 600 "\$dw_env"
docker run --rm ${networkFlag}--env-file "\$dw_env" '$image' psql -tAc 'select 1' 2>&1
''';
}

/// One verdict of [dwDatabaseReachabilityScript]'s output: connected, or a
/// named reason — never a bare exit code, which a managed provider's own
/// wording does not sort into by itself.
class DwDatabaseReachability {
  const DwDatabaseReachability.ok(this.detail) : ok = true;
  const DwDatabaseReachability.fail(this.detail) : ok = false;

  final bool ok;
  final String detail;
}

/// Classifies [result] of running [dwDatabaseReachabilityScript]: connected
/// and queried, or one of the reasons a managed database is unreachable —
/// DNS, refused, authentication, or TLS not being offered though required.
/// Falls back to the raw output rather than guessing when the message does
/// not match a known shape, so a failure is never silently reported as one it
/// is not.
DwDatabaseReachability dwJudgeDatabaseReachable(DwSshResult result) {
  final output = '${result.stdout}\n${result.stderr}';
  final lastLine = output
      .trim()
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .lastOrNull;
  if (result.ok && lastLine == '1') {
    return const DwDatabaseReachability.ok(
      'connected and authenticated with sslmode=require',
    );
  }
  final lower = output.toLowerCase();
  final String reason;
  if (lower.contains('missing in the secret store') ||
      lower.contains('no secret store at')) {
    reason = 'not configured';
  } else if (lower.contains('could not translate host name') ||
      lower.contains('name or service not known') ||
      lower.contains('nodename nor servname provided') ||
      lower.contains('temporary failure in name resolution')) {
    reason = 'DNS — the configured host does not resolve';
  } else if (lower.contains('connection refused')) {
    reason = 'refused — nothing is listening at the configured host and port';
  } else if (lower.contains('timed out') ||
      lower.contains('timeout') ||
      lower.contains('no route to host')) {
    reason =
        'timeout — no answer from the configured host and port (a firewall '
        'not admitting this host is the usual cause)';
  } else if (lower.contains('password authentication failed') ||
      lower.contains('no pg_hba.conf entry') ||
      (lower.contains('role') && lower.contains('does not exist'))) {
    reason = 'auth — the server rejected the credentials';
  } else if (lower.contains('server does not support ssl') ||
      lower.contains('ssl is not enabled') ||
      lower.contains('ssl connection has been closed unexpectedly') ||
      lower.contains('ssl error')) {
    reason = 'TLS — the server did not offer TLS for sslmode=require';
  } else {
    reason = 'unrecognised failure';
  }
  return DwDatabaseReachability.fail('$reason: ${output.trim()}');
}

/// Compares key names only. A routine check has no business moving secret
/// values across the network just to notice a drift.
Future<DwDeployVerdict> _checkSecretsMatchLocal(DwDeployContext context) async {
  final local = DwLocalSecretsFile.of(context.projectRoot);
  if (!local.exists) {
    return const DwDeployVerdict.skip('no local secrets file');
  }
  final Set<String> localKeys;
  try {
    localKeys = (local.read()![context.target.environment] ?? const {}).keys
        .toSet();
  } on StateError catch (error) {
    return DwDeployVerdict.fail(error.message);
  }

  final store = DwSecretStore(ssh: context.ssh!, target: context.target);
  final remote = await store.readKeyNames();
  if (!remote.ok) {
    return const DwDeployVerdict.skip('no readable store on the server');
  }

  final onlyServer = remote.names.difference(localKeys).toList()..sort();
  final onlyLocal = localKeys.difference(remote.names).toList()..sort();

  if (onlyServer.isEmpty && onlyLocal.isEmpty) {
    return DwDeployVerdict.pass('${localKeys.length} keys on both sides');
  }
  return DwDeployVerdict.fail(
    [
      if (onlyServer.isNotEmpty) 'only on the server: ${onlyServer.join(', ')}',
      if (onlyLocal.isNotEmpty) 'only local: ${onlyLocal.join(', ')}',
    ].join(' | '),
    fix:
        'Adopt what the server has with "dartway deploy secret pull", or make '
        'the server match with "dartway deploy secret push". A push would '
        'drop the server-only keys.',
  );
}

/// The questions `deploy run` asks at its end, asked of whatever is deployed
/// now: health on both hosts, the app page and its cache policy, the live
/// socket through both hosts, and — where they exist — the site and the
/// storage CORS rule.
Future<DwDeployVerdict> _checkOutside(DwDeployContext context) async {
  final results = [
    for (final probe in dwOutsideProbes(context.stack, DwOutsideProbe()))
      await probe(),
  ];
  final failed = results.where((result) => !result.passed).toList();
  if (failed.isEmpty) {
    return DwDeployVerdict.pass('${results.length} answers as expected');
  }
  return DwDeployVerdict.fail(
    failed.map((result) => '${result.title}: ${result.detail}').join(' | '),
    fix:
        'Nothing has been deployed yet, or the stack is not serving what it '
        'should. "dartway deploy run" asks the same questions at its end and '
        'reports each one.',
  );
}
