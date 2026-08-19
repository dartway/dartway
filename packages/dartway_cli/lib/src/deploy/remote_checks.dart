import 'dart:io';

import 'package:yaml/yaml.dart';

import '../checker/dw_check_type.dart';
import 'compose_files.dart';
import 'deploy_check.dart';
import 'master_passwords_file.dart';
import 'secret_store.dart';
import 'templates.dart';

/// Checks that need the network: DNS, and the server itself over SSH.
const List<DwDeployCheck> dwRemoteDeployChecks = [
  DwDeployCheck(
    id: 'dns-public-hosts',
    title: 'Every public domain resolves to the deployment host',
    stage: DwDeployCheckStage.remote,
    severity: DwCheckSeverity.error,
    evaluate: _checkDnsPublicHosts,
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
    title: 'Runtime secrets are present on the server',
    stage: DwDeployCheckStage.remote,
    severity: DwCheckSeverity.error,
    requiresSsh: true,
    evaluate: _checkRuntimeSecrets,
  ),
  DwDeployCheck(
    id: 'secret-files',
    title: 'Declared secret files reach the application',
    stage: DwDeployCheckStage.remote,
    severity: DwCheckSeverity.error,
    requiresSsh: true,
    evaluate: _checkSecretFiles,
  ),
  DwDeployCheck(
    id: 'secrets-match-master',
    title: 'The server and the local master file hold the same keys',
    stage: DwDeployCheckStage.remote,
    severity: DwCheckSeverity.warning,
    requiresSsh: true,
    evaluate: _checkSecretsMatchMaster,
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

  final domains = <String>[
    ...context.serverpod.endpoints
        .map((endpoint) => endpoint.publicHost)
        .whereType<String>(),
    context.target.webAppDomain,
  ];

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
        'host, and repeated failures hit the Let\'s Encrypt rate limit. '
        'Resolved through the local resolver, so a record changed minutes '
        'ago may still be cached here.',
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
        'Run the server bootstrap first — it creates the unprivileged user '
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
        'Docker must be installed and the deployment user must belong to '
        'the docker group.',
  );
}

Future<DwDeployVerdict> _checkRuntimeSecrets(DwDeployContext context) async {
  final store = DwSecretStore(ssh: context.ssh!, target: context.target);
  final environment = context.target.environment;
  final file = store.passwordsFile;

  // Serverpod merges "shared" under the run mode section, so a key present in
  // either one is resolvable at startup.
  final result = await store.readKeyNames(sections: ['shared', environment]);
  if (!result.ok) {
    return DwDeployVerdict.fail(
      'no readable $file',
      fix:
          'Create the store with "dartway deploy secret init" — runtime '
          'secrets are generated on the server and never live in Git.',
    );
  }

  final required = <String>{
    ...context.serverpod.requiredPasswordKeys,
    ...context.target.requiredSecrets,
  };
  final missing = required.difference(result.names).toList()..sort();

  if (missing.isEmpty) {
    return DwDeployVerdict.pass(
      '${result.names.length} keys across shared and "$environment"',
    );
  }
  return DwDeployVerdict.fail(
    'missing: ${missing.join(', ')}',
    fix:
        'Deliver them with "dartway deploy secret set". Generated keys come '
        'from "secret init"; the rest are yours to provide. A key supplied '
        'through a SERVERPOD_PASSWORD_ environment variable is invisible to '
        'this check.',
  );
}

/// Whether a declared file is where the application will look for it.
///
/// "Is it on the server?" is the question this check used to ask, and it is
/// not the one the deploy dies on. A file can be delivered to the runtime
/// store, reported present, and still be invisible from inside the container —
/// which is a green check standing directly in front of a red deploy, and
/// worse than no check at all, because people read it.
///
/// So the answer comes from the configuration Compose itself will run: the
/// rendered file on the server merged with the project's override, asked for
/// on the server, with the file's own path in it. A bind mount of a file that
/// exists is visibility; there is nothing further to establish.
///
/// It stops short of running a container. `docker compose run` builds the
/// image when it is absent, which would turn a check into a ten-minute build,
/// and probing the container that happens to be up answers about the *previous*
/// deploy rather than the one about to happen.
Future<DwDeployVerdict> _checkSecretFiles(DwDeployContext context) async {
  final declared = context.target.requiredSecretFiles;
  if (declared.isEmpty) {
    return const DwDeployVerdict.pass('none declared');
  }

  final store = DwSecretStore(ssh: context.ssh!, target: context.target);

  // A mount names one path on each side, and the store is flat. An entry that
  // is a pattern or a path can be delivered but never mounted, so it is a
  // failure here rather than a surprise on the server.
  final unmountable = declared
      .where(
        (name) =>
            name.contains('*') || name.contains('?') || name.contains('/'),
      )
      .toList();
  if (unmountable.isNotEmpty) {
    return DwDeployVerdict.fail(
      'not file names: ${unmountable.join(', ')}',
      fix:
          'Each requires.files entry names one file in the runtime store, and '
          'that file is mounted into the container under the same name. '
          'Name it exactly, the way "dartway deploy secret put-file" stored it.',
    );
  }

  final delivered = (await store.listFiles()).toSet();
  final undelivered = declared
      .where((name) => !delivered.contains(name))
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
          'with no rendered ${DwComposeFiles.rendered} needs '
          '"dartway deploy setup --env ${context.target.environment}"; '
          'otherwise the fault is in ${DwComposeFiles.projectOverride}, which '
          'Compose merges over it.',
    );
  }

  final Map<String, String> mounts;
  try {
    mounts = _backendMounts(configuration.stdout);
  } on YamlException catch (error) {
    return DwDeployVerdict.fail(
      'the compose configuration is unreadable: ${error.message}',
      fix:
          'Report this: "docker compose config" produced something unexpected.',
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
    'delivered but not mounted into the backend: ${unmounted.join(', ')}',
    fix:
        'The file is on the server and the container cannot see it, which is '
        'the shape of a deploy that passes every check and then dies applying '
        'migrations. The rendered ${DwComposeFiles.rendered} on the server '
        'predates the mount — re-render it with "dartway deploy setup --env '
        '${context.target.environment}", which is idempotent and safe on a '
        'live server. Each declared file is then mounted read-only at '
        '$dwContainerConfigDir/<name>.',
  );
}

/// Bind-mount sources of the backend service, mapped to where they land inside
/// the container, as Compose itself resolves them.
///
/// Both spellings are accepted: `docker compose config` normalises volumes to
/// the long form, but a short `source:target:ro` string from an older Compose
/// must not read as "nothing is mounted".
Map<String, String> _backendMounts(String configuration) {
  final document = loadYaml(configuration);
  final services = document is YamlMap ? document['services'] : null;
  final backend = services is YamlMap ? services['backend'] : null;
  final volumes = backend is YamlMap ? backend['volumes'] : null;
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
/// values across the network just to notice a drift; whether the values agree
/// is answered by `secret pull`, which transfers them anyway.
Future<DwDeployVerdict> _checkSecretsMatchMaster(
  DwDeployContext context,
) async {
  final master = DwMasterPasswordsFile(context.passwordsFile);
  if (!master.exists) {
    return const DwDeployVerdict.skip('no local master file');
  }

  final local = DwMasterPasswordsFile.effective(
    master.read()!,
    context.target.environment,
  ).keys.toSet();

  final store = DwSecretStore(ssh: context.ssh!, target: context.target);
  final remote = await store.readKeyNames(
    sections: ['shared', context.target.environment],
  );
  if (!remote.ok) {
    return const DwDeployVerdict.skip('no readable store on the server');
  }

  final onlyServer = remote.names.difference(local).toList()..sort();
  final onlyLocal = local.difference(remote.names).toList()..sort();

  if (onlyServer.isEmpty && onlyLocal.isEmpty) {
    return DwDeployVerdict.pass('${local.length} keys on both sides');
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
