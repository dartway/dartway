import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../build_context.dart';
import '../checker/dw_check_type.dart';
import 'deploy_target.dart';
import 'nginx_upstreams.dart';
import 'renderer.dart';
import 'serverpod_config.dart';
import 'ssh_runner.dart';
import 'web_cache.dart';

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
    id: 'docker-context-packages',
    title: 'Each image copies every package it depends on',
    stage: DwDeployCheckStage.local,
    // Error, and not a warning like "docker-context" next to it: that one
    // judges how much is sent to the daemon, this one whether the build can
    // succeed at all. A package missing from the context is not a deploy that
    // ships too much — it is a deploy that cannot happen, discovered on the
    // server.
    severity: DwCheckSeverity.error,
    evaluate: _checkBuildContextPackages,
  ),
  DwDeployCheck(
    id: 'dockerfile-entrypoint-form',
    title: 'The server image can be handed migration arguments',
    stage: DwDeployCheckStage.local,
    severity: DwCheckSeverity.error,
    evaluate: _checkEntrypointForm,
  ),
  DwDeployCheck(
    id: 'web-cache-policy',
    title: 'The web image revalidates the files a build overwrites',
    stage: DwDeployCheckStage.local,
    // A reading of configuration text, and text can hide things from it — an
    // `include` outside the build context, a header set by an entrypoint
    // script. What was actually served is answered over the wire by
    // "web-cache-headers", which is the one that errors.
    severity: DwCheckSeverity.warning,
    evaluate: _checkWebCachePolicy,
  ),
  DwDeployCheck(
    id: 'nginx-upstreams',
    title: 'Every Nginx upstream is a service the stack declares',
    stage: DwDeployCheckStage.local,
    severity: DwCheckSeverity.error,
    evaluate: _checkNginxUpstreams,
  ),
  DwDeployCheck(
    id: 'override-web-build',
    title: 'The compose override leaves the web image to the deploy',
    stage: DwDeployCheckStage.local,
    severity: DwCheckSeverity.warning,
    evaluate: _checkOverrideWebBuild,
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

/// The package graph, as the Dockerfiles and the ignore file each restate it.
///
/// Two comparisons, because the graph is written down three times and the pairs
/// fail differently. A package a Dockerfile never copies fails as `pub get`
/// exit code 66, three layers down. A package the ignore file never admits
/// fails at the `COPY` itself — louder, but still only on the machine that
/// builds the image, which is the server.
///
/// **Neither is visible in a checkout**, which is why this is a deploy check
/// and not something the repository's own tests could ever catch: they compile
/// inside the working copy, where every path resolves. The two facts meet the
/// first time somebody deploys, and by then the change is several merges back.
Future<DwDeployVerdict> _checkBuildContextPackages(
  DwDeployContext context,
) async {
  final problems = buildContextProblems(
    projectRoot: context.projectRoot,
    packages: [context.serverPackage, context.flutterPackage],
  );
  if (problems.isEmpty) {
    return const DwDeployVerdict.pass('every package reaches the image');
  }
  return DwDeployVerdict.fail(
    problems.join('; '),
    fix:
        'Add a `COPY <package>/ <package>/` line for each package the image '
        'needs, and — if the project has a `.dockerignore` that denies by '
        'default — the matching `!<package>/` and `!<package>/**` lines. '
        'Without both, `pub get` inside the image fails as exit code 66, or '
        'the COPY fails outright, and neither happens until a deploy.',
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

/// Compose service names declared by a Compose document.
Set<String> _servicesIn(String yaml) {
  final Object? document;
  try {
    document = loadYaml(yaml);
  } on YamlException {
    return const {};
  }
  final services = document is YamlMap ? document['services'] : null;
  if (services is! YamlMap) {
    return const {};
  }
  return services.keys.map((key) => key.toString()).toSet();
}

Future<DwDeployVerdict> _checkNginxUpstreams(DwDeployContext context) async {
  final renderer = DwInfraRenderer(
    projectRoot: context.projectRoot,
    target: context.target,
    serverpod: context.serverpod,
    serverPackage: context.serverPackage,
    flutterPackage: context.flutterPackage,
  );
  final snippets = renderer.nginxSnippets;
  if (snippets.isEmpty) {
    return const DwDeployVerdict.skip('no deploy/nginx.d snippets');
  }

  final services = {
    ..._servicesIn(renderer.composeFile),
    if (renderer.composeOverride case final override?)
      ..._servicesIn(override.readAsStringSync()),
  };

  final missing = DwNginxUpstreams.missing(
    snippets: {
      for (final entry in snippets.entries)
        entry.key: entry.value.readAsStringSync(),
    },
    services: services,
  );
  if (missing.isEmpty) {
    return DwDeployVerdict.pass(
      '${snippets.length} snippet(s) against ${services.length} service(s)',
    );
  }
  return DwDeployVerdict.fail(
    missing.join(', '),
    fix:
        'Nginx resolves an upstream once, when it starts, so a name no service '
        'answers to does not fail at the deploy that introduced it — it fails '
        'at whatever restarts the proxy next, which is the deploy\'s own last '
        'step and may be days later. Declare the service in '
        'deploy/compose.override.yml, or drop the snippet that names it.',
  );
}

/// The deploy renders the `web` service itself, build argument included: the
/// API address comes from `publicHost`, which is what keeps the domain written
/// down once. An override that builds `web` states it a second time, and
/// nothing compares the two copies — the image keeps building successfully
/// against yesterday's API, which is a failure with no error message.
///
/// A warning rather than an error: overriding `web` for something that is not
/// the build (a label, a limit, a volume) is legitimate, and only the build
/// block reintroduces the second copy.
Future<DwDeployVerdict> _checkOverrideWebBuild(DwDeployContext context) async {
  final file = File(
    p.join(context.projectRoot.path, 'deploy', 'compose.override.yml'),
  );
  if (!file.existsSync()) {
    return const DwDeployVerdict.skip('no deploy/compose.override.yml');
  }

  final Object? document;
  try {
    document = loadYaml(file.readAsStringSync());
  } on YamlException catch (error) {
    return DwDeployVerdict.fail(
      'deploy/compose.override.yml is not valid YAML: ${error.message}',
      fix:
          'Compose merges this file over the rendered one on the server, so a '
          'file it cannot parse stops the deployment there rather than here.',
    );
  }

  final services = document is YamlMap ? document['services'] : null;
  final web = services is YamlMap ? services['web'] : null;
  if (web is! YamlMap) {
    return const DwDeployVerdict.pass('the web image is the deploy\'s alone');
  }
  if (!web.containsKey('build')) {
    return const DwDeployVerdict.pass(
      'the override touches web without rebuilding it',
    );
  }
  return const DwDeployVerdict.fail(
    'deploy/compose.override.yml rebuilds the web service',
    fix:
        'The deploy already builds web and passes it DW_BACKEND_URL from '
        'publicHost in the Serverpod configuration. A build block here names '
        'the API address a second time and nothing compares the copies, so a '
        'changed domain silently ships an app talking to the old one. Drop the '
        'build block; change the Dockerfile instead when the image itself has '
        'to differ.',
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

/// A redeploy that does not reach the browser, caught while it is still a line
/// of configuration.
///
/// A Flutter web build hashes nothing: `main.dart.js`, `flutter_bootstrap.js`,
/// `flutter.js` and everything under `assets/` are named identically in every
/// build. So "fingerprinted assets are immutable, cache them for a year" — a
/// correct rule elsewhere — lands here on precisely the files that change on
/// every deploy, and a browser that took one under a long `max-age` never asks
/// again. The deploy succeeds, the server serves the new bundle, the browser
/// runs the old one, and every check anyone thinks to run says the right thing.
Future<DwDeployVerdict> _checkWebCachePolicy(DwDeployContext context) async {
  final dockerfile = File(
    p.join(context.projectRoot.path, context.flutterPackage, 'Dockerfile'),
  );
  if (!dockerfile.existsSync()) {
    return const DwDeployVerdict.skip('no web Dockerfile');
  }

  final configuration = dwWebServingConfiguration(
    projectRoot: context.projectRoot,
    dockerfile: dockerfile,
  );
  if (configuration == null) {
    return DwDeployVerdict.fail(
      'the web image ships no serving configuration',
      fix: _webCacheFix(context),
    );
  }

  final policies = dwEntryPointPolicies(configuration);
  final freely = policies.entries
      .where((entry) => entry.value == DwCacheReuse.freely)
      .map((entry) => entry.key)
      .toList();
  if (freely.isNotEmpty) {
    return DwDeployVerdict.fail(
      'cached without revalidation: ${freely.join(', ')}',
      fix: _webCacheFix(context),
    );
  }

  final unstated = policies.entries
      .where((entry) => entry.value == DwCacheReuse.unstated)
      .map((entry) => entry.key)
      .toList();
  if (unstated.isNotEmpty) {
    return DwDeployVerdict.fail(
      'no cache policy stated for: ${unstated.join(', ')}',
      fix:
          'Nothing here is wrong yet — with no Cache-Control the browser falls '
          'back to a heuristic based on Last-Modified, which is short for a '
          'file that has just been deployed. Nobody decided it, though, and '
          'the first person to "add caching" reaches for the immutable '
          'rule. ${_webCacheFix(context)}',
    );
  }

  return DwDeployVerdict.pass(
    '${policies.length} entry points revalidate before reuse',
  );
}

String _webCacheFix(DwDeployContext context) =>
    'Serve the build so that everything a Flutter build emits revalidates '
    '("Cache-Control: no-cache" plus an ETag, which makes it a 304 rather than '
    'a download) and reserve the long-lived, immutable rule for names that '
    'genuinely carry a content hash. The canonical configuration ships with '
    'the DartWay template as '
    '${context.flutterPackage}/nginx.conf, copied into the image by the '
    'Dockerfile beside it. '
    'Fixing it does not un-poison a browser that already holds a copy: a '
    'response taken under "max-age=2592000" stays fresh in that browser for the '
    'rest of the thirty days and it will not ask. Tell the people you can reach '
    'to hard-reload (Ctrl+Shift+R, or clear site data); for the ones you '
    'cannot, either wait the window out or move the app to a URL that was never '
    'poisoned — a URL the browser has not seen is the only thing that reaches '
    'it.';
