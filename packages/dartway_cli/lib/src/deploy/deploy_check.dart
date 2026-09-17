import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../build_context.dart';
import '../checker/dw_check_type.dart';
import 'deploy_target.dart';
import 'local_secrets_file.dart';
import 'nginx_upstreams.dart';
import 'renderer.dart';
import 'secret_store.dart';
import 'ssh_runner.dart';
import 'stack.dart';
import 'web_cache.dart';

/// Where a check can run.
///
/// Local checks need nothing but the working copy, so they run offline and in
/// CI. Remote checks need the network — DNS, the server over SSH, or the
/// deployed site over HTTPS.
enum DwDeployCheckStage { local, remote }

/// Everything a check is allowed to look at.
class DwDeployContext {
  DwDeployContext({required this.projectRoot, required this.stack, this.ssh});

  final Directory projectRoot;
  final DwStack stack;

  /// Absent when the run is offline; checks that need it declare
  /// [DwDeployCheck.requiresSsh] and are skipped instead of failing.
  final DwSshRunner? ssh;

  DwDeployTarget get target => stack.target;
  String get serverPackage => stack.serverPackage;
  String get flutterPackage => stack.flutterPackage;

  File dockerfileOf(String package) =>
      File(p.join(projectRoot.path, package, 'Dockerfile'));
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
/// flow.
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
  /// Some checks describe the maintainer's secret workflow rather than a
  /// precondition for deploying. Running those before every deploy puts a
  /// warning in every CI log — which is how people learn to stop reading
  /// warnings. `dartway deploy check` still reports them.
  final bool partOfDeploy;

  final Future<DwDeployVerdict> Function(DwDeployContext context) evaluate;
}

/// Checks that need only the working copy.
///
/// The configuration itself is not among them: `deploy/config.yaml` is
/// validated as it is read, every problem at once, so no command gets as far
/// as a check with a configuration that is not deployable.
const List<DwDeployCheck> dwLocalDeployChecks = [
  DwDeployCheck(
    id: 'secret-names',
    title: 'Required secrets are names the server can receive',
    stage: DwDeployCheckStage.local,
    severity: DwCheckSeverity.error,
    evaluate: _checkSecretNames,
  ),
  DwDeployCheck(
    id: 'stack-names',
    title: 'The project prefix makes a database and bucket names',
    stage: DwDeployCheckStage.local,
    severity: DwCheckSeverity.error,
    evaluate: _checkStackNames,
  ),
  DwDeployCheck(
    id: 'site-source',
    title: 'The site directory is in the repository the server checks out',
    stage: DwDeployCheckStage.local,
    severity: DwCheckSeverity.error,
    evaluate: _checkSiteSource,
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
    // Error, and not a warning like "docker-context" beside it: that one
    // judges how much is sent to the daemon, this one whether the build can
    // succeed at all.
    severity: DwCheckSeverity.error,
    evaluate: _checkBuildContextPackages,
  ),
  DwDeployCheck(
    id: 'dependencies-inside-context',
    title: 'No image resolves a package from a path outside the project',
    stage: DwDeployCheckStage.local,
    severity: DwCheckSeverity.error,
    evaluate: _checkDependenciesInsideContext,
  ),
  DwDeployCheck(
    id: 'server-signals',
    title: 'The server image receives SIGTERM itself',
    stage: DwDeployCheckStage.local,
    severity: DwCheckSeverity.error,
    evaluate: _checkServerSignals,
  ),
  DwDeployCheck(
    id: 'web-backend-url',
    title: 'The web image takes the address it calls as a build argument',
    stage: DwDeployCheckStage.local,
    severity: DwCheckSeverity.error,
    evaluate: _checkWebBackendUrl,
  ),
  DwDeployCheck(
    id: 'web-cache-policy',
    title: 'The web image revalidates the files a build overwrites',
    stage: DwDeployCheckStage.local,
    // A reading of configuration text, and text can hide things from it. What
    // was actually served is answered over the wire by "outside", which errors.
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
  DwDeployCheck(
    id: 'local-secrets-untracked',
    title: 'The local secrets file is outside Git',
    stage: DwDeployCheckStage.local,
    severity: DwCheckSeverity.error,
    evaluate: _checkLocalSecretsUntracked,
  ),
  DwDeployCheck(
    id: 'local-secrets-cover-environment',
    title: 'The local secrets file holds every required secret',
    stage: DwDeployCheckStage.local,
    severity: DwCheckSeverity.warning,
    // A deployment never reads the local file — the server holds its own
    // store. On CI, where the file is absent by design, this would warn on
    // every run.
    partOfDeploy: false,
    evaluate: _checkLocalSecretsCoverEnvironment,
  ),
];

Future<DwDeployVerdict> _checkSecretNames(DwDeployContext context) async {
  final reserved = context.stack.reservedSecretKeys;
  final clashing = context.target.requiredSecrets
      .where(reserved.contains)
      .toList();
  if (clashing.isEmpty) {
    return DwDeployVerdict.pass(
      '${context.stack.requiredSecretKeys.length} required: '
      '${context.stack.requiredSecretKeys.join(', ')}',
    );
  }
  return DwDeployVerdict.fail(
    'requires.secrets names ${clashing.join(', ')}, which the compose file '
    'sets itself',
    fix:
        'The deploy derives these from deploy/config.yaml and renders them into '
        'the compose file, where they override anything of the same name in '
        'the secret store — a value delivered there would never reach the '
        'server. Remove them from requires.secrets.',
  );
}

Future<DwDeployVerdict> _checkStackNames(DwDeployContext context) async {
  final stack = context.stack;
  final problems = [
    if (!RegExp(r'^[a-z_][a-z0-9_]{0,62}$').hasMatch(stack.databaseName))
      'database name "${stack.databaseName}"',
    if (context.target.storage == DwStorageMode.minio)
      for (final bucket in [stack.publicBucketName, stack.privateBucketName])
        if (!RegExp(r'^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$').hasMatch(bucket))
          'bucket name "$bucket"',
  ];
  if (problems.isEmpty) {
    return DwDeployVerdict.pass(
      'database ${stack.databaseName}'
      '${context.target.storage == DwStorageMode.minio ? ', buckets ${stack.publicBucketName} and ${stack.privateBucketName}' : ''}',
    );
  }
  return DwDeployVerdict.fail(
    'invalid ${problems.join(' and ')}, derived from ${stack.serverPackage}',
    fix:
        'Both are the server package name without _server. Rename the '
        'packages so the prefix is a lower-case identifier of at least three '
        'characters.',
  );
}

Future<DwDeployVerdict> _checkSiteSource(DwDeployContext context) async {
  final site = context.target.site;
  if (site == null) return const DwDeployVerdict.skip('no site declared');
  if (!site.deployed) {
    return DwDeployVerdict.pass(
      '${site.domain} is external; this deployment does not serve it',
    );
  }
  final source = site.source!;
  final index = File(p.join(context.projectRoot.path, source, 'index.html'));
  if (!index.existsSync()) {
    return DwDeployVerdict.fail(
      'no $source/index.html',
      fix:
          'The site is served from the checkout as static files, so the '
          'directory has to hold a built site. Build it into $source, or set '
          'site.source to none when the site lives elsewhere.',
    );
  }
  final ProcessResult tracked;
  try {
    tracked = Process.runSync('git', [
      'ls-files',
      '--error-unmatch',
      '$source/index.html',
    ], workingDirectory: context.projectRoot.path);
  } on ProcessException {
    return const DwDeployVerdict.skip('git unavailable');
  }
  if (tracked.exitCode == 0) {
    return DwDeployVerdict.pass('$source/index.html is committed');
  }
  return DwDeployVerdict.fail(
    '$source/index.html exists here and is not in Git',
    fix:
        'The server serves the checkout it fetched, and a file Git does not '
        'track never reaches it: the site would answer 404 while it looks '
        'fine on this machine. Commit the built site, or stop ignoring '
        '$source.',
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

/// The compose file names two Dockerfiles by convention rather than by
/// configuration, so a project that never wrote one fails at build time on the
/// server — after the checkout has already moved.
Future<DwDeployVerdict> _checkDockerfiles(DwDeployContext context) async {
  final missing = [
    for (final package in [context.serverPackage, context.flutterPackage])
      if (!context.dockerfileOf(package).existsSync()) '$package/Dockerfile',
  ];
  if (missing.isEmpty) {
    return const DwDeployVerdict.pass('server and web images both build');
  }
  return DwDeployVerdict.fail(
    'missing: ${missing.join(', ')}',
    fix:
        'The rendered compose file builds both images from the project root. '
        'Copy the canonical pair from the DartWay template.',
  );
}

/// The package graph, as the Dockerfiles and the ignore file each restate it.
///
/// A package a Dockerfile never copies fails as `pub get` exit code 66, three
/// layers down; a package the ignore file never admits fails at the `COPY`.
/// Neither is visible in a checkout, where every path resolves.
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
        'needs, and make sure `.dockerignore` admits it.',
  );
}

/// A path dependency that leaves the project cannot enter the build context,
/// which is the project root. The checkout resolves it and the image does not.
Future<DwDeployVerdict> _checkDependenciesInsideContext(
  DwDeployContext context,
) async {
  final problems = outsideContextProblems(
    projectRoot: context.projectRoot,
    packages: [context.serverPackage, context.flutterPackage],
  );
  if (problems.isEmpty) {
    return const DwDeployVerdict.pass(
      'every path dependency is inside the project',
    );
  }
  return DwDeployVerdict.fail(
    problems.join('; '),
    fix:
        'Images build from the project root and see nothing above it, so '
        '`dart pub get` in the image cannot find these packages — the '
        'overrides `dartway create --framework-path` writes are exactly '
        'this. Depend on '
        'them by version, or — for a framework that is not published yet — '
        'by git with a pinned ref (`git: {url, ref, path}`, the ref in '
        'quotes), and keep a local checkout in `pubspec_overrides.yaml` with '
        '`**/pubspec_overrides.yaml` in `.dockerignore`.',
  );
}

/// The server stops gracefully on SIGTERM — calls answered, sockets closed,
/// jobs finished — and only if the signal reaches it. A shell-form
/// `ENTRYPOINT` or `CMD` runs the binary under `/bin/sh -c`, which does not
/// forward it: every deploy then waits out the grace period and kills the
/// server mid-call.
Future<DwDeployVerdict> _checkServerSignals(DwDeployContext context) async {
  final file = context.dockerfileOf(context.serverPackage);
  if (!file.existsSync()) {
    return const DwDeployVerdict.skip('no server Dockerfile');
  }
  final lines = file
      .readAsLinesSync()
      .map((line) => line.trim())
      .where((line) => line.startsWith('ENTRYPOINT') || line.startsWith('CMD'))
      .toList();
  // The last one of each kind is the one in force.
  final entrypoint = lines.where((l) => l.startsWith('ENTRYPOINT')).lastOrNull;
  final command = lines.where((l) => l.startsWith('CMD')).lastOrNull;
  final process = entrypoint ?? command;
  if (process == null) {
    return const DwDeployVerdict.fail(
      'neither ENTRYPOINT nor CMD',
      fix: 'End the server Dockerfile with ENTRYPOINT ["/app/server"].',
    );
  }
  final keyword = process.startsWith('ENTRYPOINT') ? 'ENTRYPOINT' : 'CMD';
  final execForm = process.substring(keyword.length).trimLeft().startsWith('[');
  if (execForm) {
    return DwDeployVerdict.pass('exec form: $process');
  }
  return DwDeployVerdict.fail(
    'shell form: $process',
    fix:
        'Write it in exec form — ENTRYPOINT ["/app/server"] — so the binary is '
        'PID 1 and receives the SIGTERM a deploy sends. Under /bin/sh -c the '
        'signal stops at the shell and the server is killed when the grace '
        'period runs out.',
  );
}

Future<DwDeployVerdict> _checkWebBackendUrl(DwDeployContext context) async {
  final file = context.dockerfileOf(context.flutterPackage);
  if (!file.existsSync()) {
    return const DwDeployVerdict.skip('no web Dockerfile');
  }
  final declares = file.readAsLinesSync().any(
    (line) => RegExp(r'^\s*ARG\s+DW_BACKEND_URL(\s|=|$)').hasMatch(line),
  );
  if (declares) {
    return DwDeployVerdict.pass(
      'ARG DW_BACKEND_URL, given ${context.stack.appOrigin}',
    );
  }
  return DwDeployVerdict.fail(
    '${context.flutterPackage}/Dockerfile declares no ARG DW_BACKEND_URL',
    fix:
        'The deploy passes the app its own origin as the build argument '
        'DW_BACKEND_URL; Docker drops an argument the Dockerfile does not '
        'declare, without a word, and the app compiles against whatever '
        'default it has. Declare it and pass it to flutter build web as a '
        '--dart-define.',
  );
}

/// A redeploy that does not reach the browser, caught while it is still a line
/// of configuration. A Flutter web build hashes nothing, so an immutable rule
/// lands on precisely the files that change on every deploy.
Future<DwDeployVerdict> _checkWebCachePolicy(DwDeployContext context) async {
  final dockerfile = context.dockerfileOf(context.flutterPackage);
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
      fix: dwWebCacheFix(context.flutterPackage),
    );
  }

  final policies = dwEntryPointPolicies(configuration);
  final freely = policies.entries
      .where((entry) => entry.value == DwCacheReuse.freely)
      .map((entry) => entry.key)
      .toList();
  if (freely.isNotEmpty) {
    final breaking = freely.where(dwStaleCopyBreaksApp).toList();
    final cosmetic = freely.where((path) => !dwStaleCopyBreaksApp(path));
    return DwDeployVerdict.fail(
      [
        if (breaking.isNotEmpty)
          'browsers will go on running the previous build — its page, code or '
              'icon font is reused without asking: ${breaking.join(', ')}',
        if (cosmetic.isNotEmpty)
          'images stay stale after a deploy: ${cosmetic.join(', ')}',
      ].join('; '),
      fix: dwWebCacheFix(context.flutterPackage),
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
          'back to a heuristic based on Last-Modified. Nobody decided it, '
          'though, and the first person to "add caching" reaches for the '
          'immutable rule. ${dwWebCacheFix(context.flutterPackage)}',
    );
  }

  return DwDeployVerdict.pass(
    '${policies.length} entry points revalidate before reuse',
  );
}

/// The advice for a web cache policy that lets a browser keep a build.
String dwWebCacheFix(String flutterPackage) =>
    'Serve the build so that everything a Flutter build emits revalidates '
    '("Cache-Control: no-cache" plus an ETag, which makes it a 304 rather than '
    'a download) and reserve the long-lived, immutable rule for names that '
    'genuinely carry a content hash. The canonical configuration ships with '
    'the DartWay template as $flutterPackage/nginx.conf, copied into the image '
    'by the Dockerfile beside it. '
    'Fixing it does not un-poison a browser that already holds a copy: a '
    'response taken under a long max-age stays fresh there for the rest of '
    'that window. Tell the people you can reach to hard-reload (Ctrl+Shift+R, '
    'or clear site data); for the rest, wait the window out or move the app to '
    'a URL that was never poisoned.';

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
  final renderer = DwStackRenderer(
    stack: context.stack,
    projectRoot: context.projectRoot,
  );
  final snippets = renderer.nginxSnippets;
  final services = {
    ..._servicesIn(renderer.composeFile),
    if (renderer.composeOverride case final override?)
      ..._servicesIn(override.readAsStringSync()),
  };

  final missing = DwNginxUpstreams.missing(
    snippets: {
      'nginx.conf': renderer.nginxFile,
      for (final entry in snippets.entries)
        'nginx.d/${entry.key}': entry.value.readAsStringSync(),
    },
    services: services,
  );
  if (missing.isEmpty) {
    return DwDeployVerdict.pass(
      'nginx.conf and ${snippets.length} snippet(s) against '
      '${services.length} service(s)',
    );
  }
  return DwDeployVerdict.fail(
    missing.join(', '),
    fix:
        'Nginx resolves an upstream once, when it starts, so a name no service '
        'answers to fails at whatever restarts the proxy next — which is the '
        "deploy's own last step. Declare the service in "
        'deploy/compose.override.yml, or drop the snippet that names it.',
  );
}

/// The deploy renders the `web` service itself, build argument included: the
/// app's origin comes from `app_domain`, which is what keeps it written down
/// once. An override that builds `web` states it a second time, and nothing
/// compares the two copies.
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
  final web = services is YamlMap ? services[DwStack.webService] : null;
  if (web is! YamlMap) {
    return const DwDeployVerdict.pass("the web image is the deploy's alone");
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
        'app_domain in deploy/config.yaml. A build block here names the '
        'address a second time and nothing compares the copies, so a changed '
        'domain silently ships an app talking to the old one. Drop the build '
        'block; change the Dockerfile instead when the image itself has to '
        'differ.',
  );
}

/// The local secrets file holds every environment's secrets, so the one thing
/// that must never happen is it being committed.
Future<DwDeployVerdict> _checkLocalSecretsUntracked(
  DwDeployContext context,
) async {
  final local = DwLocalSecretsFile.of(context.projectRoot);
  if (!local.exists) {
    return const DwDeployVerdict.pass('no local secrets file');
  }

  final ProcessResult result;
  try {
    result = Process.runSync('git', [
      'ls-files',
      '--error-unmatch',
      DwLocalSecretsFile.relativePath,
    ], workingDirectory: context.projectRoot.path);
  } on ProcessException {
    return const DwDeployVerdict.skip('git unavailable');
  }

  if (result.exitCode != 0) {
    return const DwDeployVerdict.pass(
      '${DwLocalSecretsFile.relativePath} is not tracked',
    );
  }
  return const DwDeployVerdict.fail(
    '${DwLocalSecretsFile.relativePath} is tracked by Git',
    fix:
        'This file holds the secrets of every environment. Remove it from the '
        'index with "git rm --cached ${DwLocalSecretsFile.relativePath}" and '
        'add it to deploy/.gitignore. Anything already pushed has to be '
        'treated as disclosed and rotated.',
  );
}

Future<DwDeployVerdict> _checkLocalSecretsCoverEnvironment(
  DwDeployContext context,
) async {
  final local = DwLocalSecretsFile.of(context.projectRoot);
  final environment = context.target.environment;
  final Map<String, Map<String, String>>? sections;
  try {
    sections = local.read();
  } on StateError catch (error) {
    return DwDeployVerdict.fail(error.message);
  }
  if (sections == null) {
    return const DwDeployVerdict.fail(
      'no local secrets file',
      fix:
          'Secrets can live on the server alone ("dartway deploy secret init" '
          'and "secret set"), but then this machine holds no copy of them. '
          '"dartway deploy secret pull" starts one.',
    );
  }
  final section = sections[environment];
  if (section == null) {
    return DwDeployVerdict.fail(
      'no "$environment" section (has: ${sections.keys.join(', ')})',
      fix:
          'Take the server\'s values with "dartway deploy secret pull --env '
          '$environment".',
    );
  }
  final missing = context.stack.requiredSecretKeys
      .where((key) => (section[key] ?? '').isEmpty)
      .toList();
  final unencodable = <String>[];
  for (final entry in section.entries) {
    try {
      DwSecretStore.encodeLine(entry.key, entry.value);
    } on DwSecretFormatException {
      unencodable.add(entry.key);
    }
  }
  if (missing.isEmpty && unencodable.isEmpty) {
    return DwDeployVerdict.pass(
      '"$environment" holds ${section.length} key(s), every required one set',
    );
  }
  return DwDeployVerdict.fail(
    [
      if (missing.isNotEmpty) 'missing or empty: ${missing.join(', ')}',
      if (unencodable.isNotEmpty)
        'not storable (name or value): ${unencodable.join(', ')}',
    ].join(' | '),
    fix:
        'Fill them in, or take the server\'s values with "dartway deploy '
        'secret pull --env $environment". A value cannot hold a single quote '
        'or a line break; a name is upper case.',
  );
}
