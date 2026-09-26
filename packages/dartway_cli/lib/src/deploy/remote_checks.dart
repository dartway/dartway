import 'dart:io';

import 'package:yaml/yaml.dart';

import '../checker/dw_check_type.dart';
import 'compose_files.dart';
import 'deploy_check.dart';
import 'image_registry.dart';
import 'local_secrets_file.dart';
import 'outside_probe.dart';
import 'secret_store.dart';
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
Future<DwDeployVerdict> _checkImagesResolve(DwDeployContext context) async {
  final images = context.stack.pinnedImages;
  final registry = DwImageRegistry();
  final problems = <String>[];
  for (final (label, image) in images) {
    final result = await registry.resolve(image);
    if (!result.ok) problems.add('$label ($image): ${result.detail}');
  }
  if (problems.isEmpty) {
    return DwDeployVerdict.pass(
      '${images.length} pinned image(s): ${images.map((e) => e.$2).join(', ')}',
    );
  }
  return DwDeployVerdict.fail(
    problems.join(' | '),
    fix:
        'A pinned tag that no longer resolves has to be repinned in the '
        'framework itself (packages/dartway_cli/lib/src/deploy/stack.dart) — '
        'file it there. This is exactly the failure #331 fixed once already, '
        'for a different image whose registries had all stopped serving it.',
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
