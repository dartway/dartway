import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../checker/dw_check_type.dart';
import 'deploy_target.dart';
import 'serverpod_config.dart';
import 'ssh_runner.dart';

/// Where a check can run.
///
/// Local checks need nothing but the working copy, so they run offline and in
/// CI. Remote checks need the network — DNS, or the server itself over SSH.
enum DwDeployCheckStage { local, remote }

/// Everything a check is allowed to look at.
class DwDeployContext {
  DwDeployContext({
    required this.projectRoot,
    required this.serverPackage,
    required this.flutterPackage,
    required this.target,
    required this.serverpod,
    this.ssh,
  });

  final Directory projectRoot;
  final String serverPackage;
  final String flutterPackage;
  final DwDeployTarget target;
  final DwServerpodConfig serverpod;

  /// Absent when the run is offline; checks that need it declare
  /// [DwDeployCheck.requiresSsh] and are skipped instead of failing.
  final DwSshRunner? ssh;

  File get passwordsFile =>
      File(p.join(projectRoot.path, serverPackage, 'config', 'passwords.yaml'));

  File get passwordsExampleFile => File(
    p.join(projectRoot.path, serverPackage, 'config', 'passwords.yaml.example'),
  );

  /// Top-level sections of a local passwords file, or null when absent.
  List<String>? passwordSectionsOf(File file) {
    if (!file.existsSync()) {
      return null;
    }
    final document = loadYaml(file.readAsStringSync());
    if (document is! YamlMap) {
      return const [];
    }
    return document.keys.map((key) => key.toString()).toList();
  }
}

/// Result of a single check.
class DwDeployVerdict {
  const DwDeployVerdict.pass(this.detail)
    : passed = true,
      skipped = false,
      fix = null;

  const DwDeployVerdict.fail(this.detail, {this.fix})
    : passed = false,
      skipped = false;

  /// Could not be evaluated — a missing precondition, not a finding.
  const DwDeployVerdict.skip(this.detail)
    : passed = false,
      skipped = true,
      fix = null;

  final bool passed;
  final bool skipped;

  /// What was actually found. Always stated, including on success, so the
  /// output doubles as a description of the environment.
  final String detail;

  /// What to do about it. Only meaningful on failure.
  final String? fix;
}

/// A check declared as data: identity and severity are fields, not control
/// flow. One declaration feeds the human report, machine-readable output and
/// the exported instruction list.
class DwDeployCheck {
  const DwDeployCheck({
    required this.id,
    required this.title,
    required this.stage,
    required this.severity,
    required this.evaluate,
    this.requiresSsh = false,
    this.partOfDeploy = true,
  });

  /// Stable identifier, safe to reference from scripts and issues.
  final String id;

  final String title;
  final DwDeployCheckStage stage;

  /// Severity applied when the check fails.
  final DwCheckSeverity severity;

  /// Skipped rather than failed when the server is unreachable.
  final bool requiresSsh;

  /// Whether a deployment evaluates this check.
  ///
  /// Some checks describe the secret-management workflow rather than a
  /// precondition for deploying. Running those before every deploy puts a
  /// warning in every CI log — which is how people learn to stop reading
  /// warnings. `dartway deploy check` still reports them.
  final bool partOfDeploy;

  final Future<DwDeployVerdict> Function(DwDeployContext context) evaluate;
}

/// Checks that need only the working copy.
const List<DwDeployCheck> dwLocalDeployChecks = [
  DwDeployCheck(
    id: 'serverpod-public-scheme',
    title: 'Serverpod endpoints are published over HTTPS',
    stage: DwDeployCheckStage.local,
    severity: DwCheckSeverity.error,
    evaluate: _checkPublicScheme,
  ),
  DwDeployCheck(
    id: 'serverpod-public-port',
    title: 'Serverpod endpoints declare the public TLS port',
    stage: DwDeployCheckStage.local,
    severity: DwCheckSeverity.error,
    evaluate: _checkPublicPort,
  ),
  DwDeployCheck(
    id: 'serverpod-public-host',
    title: 'Every Serverpod endpoint has a public host',
    stage: DwDeployCheckStage.local,
    severity: DwCheckSeverity.error,
    evaluate: _checkPublicHost,
  ),
  DwDeployCheck(
    id: 'domain-collision',
    title: 'The web app domain is distinct from the Serverpod domains',
    stage: DwDeployCheckStage.local,
    severity: DwCheckSeverity.error,
    evaluate: _checkDomainCollision,
  ),
  DwDeployCheck(
    id: 'database-ownership',
    title: 'The database host resolves to a known deployment role',
    stage: DwDeployCheckStage.local,
    severity: DwCheckSeverity.error,
    evaluate: _checkDatabaseOwnership,
  ),
  DwDeployCheck(
    id: 'redis-ownership',
    title: 'Redis configuration matches what the deployment can provide',
    stage: DwDeployCheckStage.local,
    severity: DwCheckSeverity.warning,
    evaluate: _checkRedisOwnership,
  ),
  DwDeployCheck(
    id: 'passwords-example',
    title: 'passwords.yaml.example documents every required key',
    stage: DwDeployCheckStage.local,
    severity: DwCheckSeverity.warning,
    evaluate: _checkPasswordsExample,
  ),
  DwDeployCheck(
    id: 'passwords-untracked',
    title: 'The local passwords file is outside Git',
    stage: DwDeployCheckStage.local,
    severity: DwCheckSeverity.error,
    evaluate: _checkPasswordsUntracked,
  ),
  DwDeployCheck(
    id: 'passwords-covers-environment',
    title: 'The local passwords file covers this environment',
    stage: DwDeployCheckStage.local,
    severity: DwCheckSeverity.warning,
    // A deployment never reads the master file — the server already holds its
    // own slice. On CI, where the file is absent by design, this would warn on
    // every single run.
    partOfDeploy: false,
    evaluate: _checkPasswordsCoverEnvironment,
  ),
  DwDeployCheck(
    id: 'docker-context',
    title: 'The Docker build context is filtered',
    stage: DwDeployCheckStage.local,
    severity: DwCheckSeverity.warning,
    evaluate: _checkDockerContext,
  ),
  DwDeployCheck(
    id: 'dockerfiles-present',
    title: 'Both images the compose file builds have a Dockerfile',
    stage: DwDeployCheckStage.local,
    severity: DwCheckSeverity.error,
    evaluate: _checkDockerfiles,
  ),
  DwDeployCheck(
    id: 'dockerfile-entrypoint-form',
    title: 'The server image can be handed migration arguments',
    stage: DwDeployCheckStage.local,
    severity: DwCheckSeverity.error,
    evaluate: _checkEntrypointForm,
  ),
];

Future<DwDeployVerdict> _checkPublicScheme(DwDeployContext context) async {
  final wrong = context.serverpod.endpoints
      .where((endpoint) => endpoint.publicScheme != 'https')
      .toList();
  if (wrong.isEmpty) {
    return const DwDeployVerdict.pass('all endpoints use https');
  }
  final names = wrong
      .map(
        (endpoint) => '${endpoint.name}: ${endpoint.publicScheme ?? '<unset>'}',
      )
      .join(', ');
  return DwDeployVerdict.fail(
    names,
    fix:
        'This deployment terminates TLS at nginx. '
        'Set publicScheme: https in ${context.serverpod.relativePath}.',
  );
}

Future<DwDeployVerdict> _checkPublicPort(DwDeployContext context) async {
  final wrong = context.serverpod.endpoints
      .where((endpoint) => endpoint.publicPort != 443)
      .toList();
  if (wrong.isEmpty) {
    return const DwDeployVerdict.pass('all endpoints publish port 443');
  }
  final names = wrong
      .map(
        (endpoint) => '${endpoint.name}: ${endpoint.publicPort ?? '<unset>'}',
      )
      .join(', ');
  return DwDeployVerdict.fail(
    names,
    fix:
        'Public traffic arrives on 443 through nginx. '
        'Set publicPort: 443 in ${context.serverpod.relativePath}.',
  );
}

Future<DwDeployVerdict> _checkPublicHost(DwDeployContext context) async {
  final missing = context.serverpod.endpoints
      .where((endpoint) => endpoint.publicHost == null)
      .map((endpoint) => endpoint.name)
      .toList();
  if (missing.isEmpty) {
    final hosts = context.serverpod.endpoints
        .map((endpoint) => endpoint.publicHost)
        .join(', ');
    return DwDeployVerdict.pass(hosts);
  }
  return DwDeployVerdict.fail(
    'missing publicHost: ${missing.join(', ')}',
    fix:
        'Each endpoint needs the domain it is served on — '
        'nginx and the TLS certificate are derived from it.',
  );
}

Future<DwDeployVerdict> _checkDomainCollision(DwDeployContext context) async {
  final webApp = context.target.webAppDomain;
  final clash = context.serverpod.endpoints
      .where((endpoint) => endpoint.publicHost == webApp)
      .map((endpoint) => endpoint.name)
      .toList();
  if (clash.isEmpty) {
    return DwDeployVerdict.pass('web app on $webApp');
  }
  return DwDeployVerdict.fail(
    'web_app_domain $webApp is also ${clash.join(', ')}',
    fix:
        'The Flutter build and the Serverpod endpoints need separate '
        'domains; nginx routes by server_name.',
  );
}

Future<DwDeployVerdict> _checkDatabaseOwnership(DwDeployContext context) async {
  final host = context.serverpod.databaseHost;
  if (host == null) {
    return const DwDeployVerdict.fail(
      'no database.host',
      fix: 'Declare the database section in the Serverpod configuration.',
    );
  }
  if (context.serverpod.managesDatabase) {
    return DwDeployVerdict.pass(
      'managed container "$host", database ${context.serverpod.databaseName}',
    );
  }
  return DwDeployVerdict.pass(
    'external database at "$host" — no Postgres container will be created',
  );
}

Future<DwDeployVerdict> _checkRedisOwnership(DwDeployContext context) async {
  if (!context.serverpod.redisEnabled) {
    return const DwDeployVerdict.pass('disabled');
  }
  if (context.serverpod.managesRedis) {
    return const DwDeployVerdict.pass('managed container "redis"');
  }
  return DwDeployVerdict.fail(
    'enabled with host "${context.serverpod.redisHost ?? '<unset>'}"',
    fix:
        'Use host: ${DwServerpodConfig.managedRedisHost} to let the '
        'deployment run Redis, or point it at a reachable external instance.',
  );
}

Future<DwDeployVerdict> _checkPasswordsExample(DwDeployContext context) async {
  final sections = context.passwordSectionsOf(context.passwordsExampleFile);
  if (sections == null) {
    return DwDeployVerdict.fail(
      'no ${context.serverPackage}/config/passwords.yaml.example',
      fix:
          'Commit an example listing every key without values — it is the '
          'only record of what a new environment needs.',
    );
  }
  final required = [
    ...context.serverpod.requiredPasswordKeys,
    ...context.target.requiredSecrets,
  ];
  final text = context.passwordsExampleFile.readAsStringSync();
  final undocumented = required.where((key) => !text.contains(key)).toList();
  if (undocumented.isEmpty) {
    return DwDeployVerdict.pass('${required.length} keys documented');
  }
  return DwDeployVerdict.fail(
    'undocumented: ${undocumented.join(', ')}',
    fix: 'Add these keys to passwords.yaml.example.',
  );
}

/// The local passwords file is the master copy of every environment's secrets,
/// so the one thing that must never happen is it being committed.
Future<DwDeployVerdict> _checkPasswordsUntracked(
  DwDeployContext context,
) async {
  if (!context.passwordsFile.existsSync()) {
    return const DwDeployVerdict.pass('no local passwords file');
  }

  final relative = p
      .relative(context.passwordsFile.path, from: context.projectRoot.path)
      .replaceAll(r'\', '/');

  final ProcessResult result;
  try {
    result = Process.runSync('git', [
      'ls-files',
      '--error-unmatch',
      relative,
    ], workingDirectory: context.projectRoot.path);
  } on ProcessException {
    return const DwDeployVerdict.skip('git unavailable');
  }

  if (result.exitCode != 0) {
    return DwDeployVerdict.pass('$relative is not tracked');
  }
  return DwDeployVerdict.fail(
    '$relative is tracked by Git',
    fix:
        'This file holds the secrets of every environment. Remove it from the '
        'index with "git rm --cached $relative" and add it to .gitignore. '
        'Anything already pushed has to be treated as disclosed and rotated.',
  );
}

/// Whether the master file has anything to send for this environment.
Future<DwDeployVerdict> _checkPasswordsCoverEnvironment(
  DwDeployContext context,
) async {
  final sections = context.passwordSectionsOf(context.passwordsFile);
  final environment = context.target.environment;

  if (sections == null) {
    return DwDeployVerdict.fail(
      'no local passwords file',
      fix:
          'Secrets can also be created directly on the server with '
          '"dartway deploy secret init", but then this machine holds no '
          'copy of them.',
    );
  }
  if (sections.contains(environment)) {
    return DwDeployVerdict.pass(
      'has "$environment" (sections: ${sections.join(', ')})',
    );
  }
  return DwDeployVerdict.fail(
    'no "$environment" section (has: ${sections.join(', ')})',
    fix:
        'Add the section and push it with "dartway deploy secret push --env '
        '$environment", or create the values on the server with '
        '"dartway deploy secret init".',
  );
}

/// The compose file names two Dockerfiles by convention rather than by
/// configuration, so a project that never wrote one fails at build time on the
/// server — after the checkout has already moved.
Future<DwDeployVerdict> _checkDockerfiles(DwDeployContext context) async {
  final missing = [
    for (final package in [context.serverPackage, context.flutterPackage])
      if (!File(
        p.join(context.projectRoot.path, package, 'Dockerfile'),
      ).existsSync())
        '$package/Dockerfile',
  ];
  if (missing.isEmpty) {
    return const DwDeployVerdict.pass('server and web images both build');
  }
  return DwDeployVerdict.fail(
    'missing: ${missing.join(', ')}',
    fix:
        'The rendered compose file builds both images from the project root. '
        'Copy the canonical pair from the DartWay template — the web one also '
        'has to accept the DW_BACKEND_URL build argument the deploy passes.',
  );
}

/// Migrations run as `docker compose run backend --apply-migrations`, and
/// Compose appends those arguments to the image's entrypoint. Shell-form
/// `ENTRYPOINT` drops them, so the container starts an ordinary server, exits
/// nothing, and the deploy reports a successful migration that never happened.
Future<DwDeployVerdict> _checkEntrypointForm(DwDeployContext context) async {
  final file = File(
    p.join(context.projectRoot.path, context.serverPackage, 'Dockerfile'),
  );
  if (!file.existsSync()) {
    return const DwDeployVerdict.skip('no server Dockerfile');
  }
  if (context.target.serverEntrypoint != null) {
    return DwDeployVerdict.pass(
      'overridden by server_entrypoint: ${context.target.serverEntrypoint}',
    );
  }

  final entrypoints = file
      .readAsLinesSync()
      .map((line) => line.trim())
      .where((line) => line.startsWith('ENTRYPOINT'))
      .toList();
  if (entrypoints.isEmpty) {
    return const DwDeployVerdict.pass('no ENTRYPOINT; arguments reach CMD');
  }
  final shellForm = entrypoints
      .where(
        (line) =>
            !line.substring('ENTRYPOINT'.length).trimLeft().startsWith('['),
      )
      .toList();
  if (shellForm.isEmpty) {
    return const DwDeployVerdict.pass('exec form');
  }
  return DwDeployVerdict.fail(
    'shell form: ${shellForm.last}',
    fix:
        'Rewrite it as exec form — ENTRYPOINT ["/app/server"] with the ordinary '
        'flags in CMD — or name the binary in server_entrypoint, which makes '
        'the deploy override the entrypoint for the migration run only.',
  );
}

Future<DwDeployVerdict> _checkDockerContext(DwDeployContext context) async {
  final file = File(p.join(context.projectRoot.path, '.dockerignore'));
  if (file.existsSync()) {
    return const DwDeployVerdict.pass('.dockerignore present');
  }
  return const DwDeployVerdict.fail(
    'no .dockerignore at the build context root',
    fix:
        'Without it the whole working copy — .git, build output, local '
        'secrets — is sent to the Docker daemon on every build.',
  );
}
