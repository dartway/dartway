import 'dart:io';

import '../checker/dw_check_type.dart';
import 'deploy_check.dart';
import 'master_passwords_file.dart';
import 'secret_store.dart';

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
    title: 'Declared secret files are delivered',
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

Future<DwDeployVerdict> _checkSecretFiles(DwDeployContext context) async {
  final patterns = context.target.requiredSecretFiles;
  if (patterns.isEmpty) {
    return const DwDeployVerdict.pass('none declared');
  }

  final directory = context.target.runtimeConfigDir;
  final result = await context.ssh!.runAs(
    context.target.deployUser,
    "ls -1 '$directory' 2>/dev/null || true",
  );
  final entries = result.stdout
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();

  final missing = patterns.where((pattern) {
    final expression = RegExp(
      '^${pattern.split('*').map(RegExp.escape).join('.*')}\$',
    );
    return !entries.any(expression.hasMatch);
  }).toList();

  if (missing.isEmpty) {
    return DwDeployVerdict.pass('${patterns.length} file(s) present');
  }
  return DwDeployVerdict.fail(
    'missing in $directory: ${missing.join(', ')}',
    fix: 'Deliver them with "dartway deploy secret put-file".',
  );
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
