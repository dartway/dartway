import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'yaml_reader.dart';

/// Where uploaded files live for an environment.
enum DwStorageMode {
  /// The server is deployed without file storage.
  none,

  /// A storage container in the stack (RustFS), reached by browsers on its
  /// own domain.
  bundled,

  /// An S3-compatible storage somebody else runs; its coordinates are secrets.
  external,
}

/// The optional marketing or landing site of an environment.
class DwSiteConfig {
  const DwSiteConfig({required this.domain, required this.source});

  final String domain;

  /// The directory of the repository served as static files, or null when the
  /// site is external (`source: none`) and this deployment does not serve it.
  final String? source;

  bool get deployed => source != null;
}

/// A single deployment target declared in `deploy/config.yaml`.
///
/// The file is the whole description of an environment: the machine, the
/// domains and the optional parts of the stack. Nothing about the server's
/// runtime is written here in the server's terms — the server is configured by
/// its environment, which the deploy derives from this file and from the
/// secret store.
class DwDeployTarget {
  DwDeployTarget({
    required this.environment,
    required this.host,
    required this.sshUser,
    required this.deployUser,
    required this.os,
    required this.repo,
    required this.branch,
    required this.sslEmail,
    required this.apiDomain,
    required this.appDomain,
    this.site,
    this.storage = DwStorageMode.none,
    this.storageDomain,
    this.registryMirror,
    this.firewallPorts = const [],
    this.requiredSecrets = const [],
    this.requiredSecretFiles = const [],
  });

  /// Environment name — the top-level key in `deploy/config.yaml`.
  final String environment;

  final String host;
  final String sshUser;
  final String deployUser;
  final String os;
  final String repo;
  final String branch;
  final String sslEmail;

  /// The server for mobile apps and webhooks: everything is proxied to it.
  final String apiDomain;

  /// The Flutter web app. `/dw/` and `/health` on this host reach the server,
  /// so the app talks to its own origin and needs no CORS.
  final String appDomain;

  final DwSiteConfig? site;

  final DwStorageMode storage;

  /// The public host of the bundled storage container. Browsers upload to it
  /// directly, so it cannot hide behind the app's origin: a presigned URL
  /// signs its host.
  final String? storageDomain;

  /// Registry to pull the stack's base images through, e.g. `mirror.gcr.io`.
  final String? registryMirror;

  /// Extra TCP ports to open beyond SSH, 80 and 443.
  final List<int> firewallPorts;

  /// Secrets that cannot be generated and must be delivered by a human.
  final List<String> requiredSecrets;

  /// Secret files (service account JSON and similar) mounted into the server.
  final List<String> requiredSecretFiles;

  static const configRelativePath = 'deploy/config.yaml';

  /// Project name derived from the repository URL. Names the checkout and the
  /// runtime configuration directory on the server.
  String get projectName {
    final lastSegment = repo.split('/').last;
    return lastSegment.endsWith('.git')
        ? lastSegment.substring(0, lastSegment.length - 4)
        : lastSegment;
  }

  /// Where the deployment keeps the repository checkout.
  String get appDir => '/home/$deployUser/$projectName';

  /// Where runtime secrets live — outside Git and outside the checkout, so
  /// that `git reset --hard` on deploy can never touch them.
  String get runtimeConfigDir => '/home/$deployUser/.config/$projectName';

  /// Every host this deployment answers on, in a stable order. One
  /// certificate covers all of them, named after the first.
  List<String> get servedDomains => [
    apiDomain,
    appDomain,
    if (site case final site? when site.deployed) site.domain,
    if (storageDomain case final domain?) domain,
  ];

  /// Reads one environment from `<projectRoot>/deploy/config.yaml`.
  static DwDeployTarget load({
    required Directory projectRoot,
    required String environment,
  }) {
    final file = File(p.join(projectRoot.path, 'deploy', 'config.yaml'));
    if (!file.existsSync()) {
      throw StateError(
        'No $configRelativePath in ${projectRoot.path}.\n'
        'Every DartWay project has one — it holds the "$localSection" '
        'environment as well as the deployments. Run this from a project '
        'root, or write the file.',
      );
    }
    return parse(file.readAsStringSync(), environment: environment);
  }

  /// Reads one environment out of the text of a `deploy/config.yaml`.
  ///
  /// Every problem is reported at once, and an unknown key is one of them: a
  /// key the deploy does not read is a setting somebody believes is in force —
  /// `web_app_domain` from an older config, a typo — and silence about it is
  /// the one answer that cannot be right.
  static DwDeployTarget parse(String text, {required String environment}) {
    final document = loadYaml(text);
    if (document is! YamlMap) {
      throw StateError('$configRelativePath must be a map of environments.');
    }
    if (environment == localSection) {
      throw StateError(
        '"$localSection" is not a deployment. It is the environment this '
        'machine starts a server with — $configRelativePath > $localSection '
        'for what the team shares, deploy/secrets.yaml > $localSection for '
        'what is yours. Read it with "dartway secret list --env '
        '$localSection".',
      );
    }
    final section = document[environment];
    if (section == null) {
      final known = deployableIn(document).join(', ');
      throw StateError(
        'No "$environment" environment in $configRelativePath. '
        'Declared: ${known.isEmpty ? '<none>' : known}.',
      );
    }
    if (section is! YamlMap) {
      throw StateError('"$environment" in $configRelativePath must be a map.');
    }

    final source = '$configRelativePath > $environment';
    final reader = DwYamlReader(section, source: source);
    final problems = <String>[];

    T? guarded<T>(T Function() read) {
      try {
        return read();
      } on StateError catch (error) {
        problems.add(error.message);
        return null;
      }
    }

    _unknownKeys(section, _knownKeys, source, problems);

    final host = guarded(() => reader.requiredString('host'));
    final sshUser = guarded(() => reader.requiredString('ssh_user'));
    final deployUser = guarded(() => reader.requiredString('deploy_user'));
    final os = guarded(() => reader.requiredString('os'));
    final repo = guarded(() => reader.requiredString('repo'));
    final branch = guarded(() => reader.requiredString('branch'));
    final sslEmail = guarded(() => reader.requiredString('ssl_email'));
    final apiDomain = guarded(() => reader.requiredString('api_domain'));
    final appDomain = guarded(() => reader.requiredString('app_domain'));

    DwSiteConfig? site;
    final siteMap = guarded(() => reader.optionalMap('site'));
    if (siteMap != null) {
      final siteSource = '$source > site';
      _unknownKeys(siteMap, const {'domain', 'source'}, siteSource, problems);
      final siteReader = DwYamlReader(siteMap, source: siteSource);
      final domain = guarded(() => siteReader.requiredString('domain'));
      final dir = guarded(() => siteReader.requiredString('source'));
      var dirProblem = false;
      if (dir != null && dir != 'none') {
        final normalized = p.posix.normalize(dir);
        if (p.posix.isAbsolute(dir) ||
            normalized == '.' ||
            normalized.startsWith('..')) {
          dirProblem = true;
          problems.add(
            '$siteSource: "source" must be a directory inside the repository '
            '(e.g. app_site/build) or "none", got "$dir"',
          );
        }
      }
      if (domain != null && dir != null && !dirProblem) {
        site = DwSiteConfig(
          domain: domain,
          source: dir == 'none' ? null : p.posix.normalize(dir),
        );
      }
    }

    var storage = DwStorageMode.none;
    final storageText = guarded(() => reader.optionalString('storage'));
    if (storageText != null) {
      final mode = DwStorageMode.values
          .where((mode) => mode != DwStorageMode.none)
          .where((mode) => mode.name == storageText)
          .firstOrNull;
      if (mode == null) {
        problems.add(
          '$source: "storage" is bundled or external, got "$storageText"',
        );
      } else {
        storage = mode;
      }
    }
    final storageDomain = guarded(
      () => reader.optionalString('storage_domain'),
    );
    if (storage == DwStorageMode.bundled && storageDomain == null) {
      problems.add(
        '$source: "storage: bundled" needs "storage_domain" — browsers '
        'upload to it directly, on a host of its own',
      );
    }
    if (storage != DwStorageMode.bundled && storageDomain != null) {
      problems.add(
        '$source: "storage_domain" is only read with "storage: bundled"; an '
        'external storage is addressed by DW_STORAGE_ENDPOINT in the secret '
        'store',
      );
    }

    // What the project requires is a property of the project, not of one of
    // its machines: it is declared once at the top of the file, and an
    // environment adds what only it needs. Before this was hoisted, every
    // environment repeated the same list and they drifted apart in the one
    // direction nobody notices — the environment that was forgotten is the one
    // whose deploy stops.
    final projectRequires = _requiresOf(
      document,
      source: configRelativePath,
      problems: problems,
      guarded: guarded,
    );
    final environmentRequires = _requiresOf(
      section,
      source: source,
      problems: problems,
      guarded: guarded,
    );
    final requiredSecrets = {
      ...projectRequires.secrets,
      ...environmentRequires.secrets,
    }.toList();
    final requiredSecretFiles = {
      ...projectRequires.files,
      ...environmentRequires.files,
    }.toList();
    final firewallPorts =
        guarded(() => reader.optionalIntList('firewall_ports')) ??
        const <int>[];
    final registryMirror = guarded(
      () => reader.optionalString('registry_mirror'),
    );

    if (problems.isEmpty) {
      final target = DwDeployTarget(
        environment: environment,
        host: host!,
        sshUser: sshUser!,
        deployUser: deployUser!,
        os: os!,
        repo: repo!,
        branch: branch!,
        sslEmail: sslEmail!,
        apiDomain: apiDomain!,
        appDomain: appDomain!,
        site: site,
        storage: storage,
        storageDomain: storageDomain,
        registryMirror: registryMirror,
        firewallPorts: firewallPorts,
        requiredSecrets: requiredSecrets,
        requiredSecretFiles: requiredSecretFiles,
      );
      problems.addAll(target._domainProblems(source));
      if (problems.isEmpty) return target;
    }
    throw StateError(
      '$configRelativePath is not deployable:\n'
      '${problems.map((problem) => '  - $problem').join('\n')}',
    );
  }

  /// One `requires:` block, validated where it was written.
  static _DwRequires _requiresOf(
    YamlMap map, {
    required String source,
    required List<String> problems,
    required T? Function<T>(T Function()) guarded,
  }) {
    final requires = guarded(
      () => DwYamlReader(map, source: source).optionalMap('requires'),
    );
    if (requires == null) return const _DwRequires([], []);

    _unknownKeys(
      requires,
      const {'secrets', 'files'},
      '$source > requires',
      problems,
    );
    final reader = DwYamlReader(requires, source: '$source > requires');
    final secrets =
        guarded(() => reader.optionalStringList('secrets')) ?? const <String>[];
    final files =
        guarded(() => reader.optionalStringList('files')) ?? const <String>[];

    for (final key in secrets) {
      if (!dwIsSecretKeyName(key)) {
        problems.add(
          '$source > requires > secrets: "$key" is not a secret name — an '
          'environment variable in upper case letters, digits and '
          'underscores, not starting with a digit or COMPOSE_',
        );
      }
    }
    for (final name in files) {
      if (!dwIsSecretFileName(name)) {
        problems.add(
          '$source > requires > files: "$name" is not a file name. Each entry '
          'names one file in the secret store, mounted into the server under '
          'the same name; a pattern or a path cannot be mounted',
        );
      }
    }
    return _DwRequires(secrets, files);
  }

  /// Hosts that are not host names, and hosts that are declared twice.
  ///
  /// Nginx routes by `server_name`, so two roles on one host means one of them
  /// is silently never reached.
  List<String> _domainProblems(String source) {
    final roles = <String, String>{
      'api_domain': apiDomain,
      'app_domain': appDomain,
      if (site != null) 'site > domain': site!.domain,
      if (storageDomain != null) 'storage_domain': storageDomain!,
    };
    final problems = <String>[];
    final seen = <String, String>{};
    for (final MapEntry(key: role, value: domain) in roles.entries) {
      if (!_hostName.hasMatch(domain)) {
        problems.add('$source: $role "$domain" is not a host name');
      }
      final lower = domain.toLowerCase();
      if (seen[lower] case final other?) {
        problems.add(
          '$source: $other and $role are both "$domain"; each role needs a '
          'host of its own, because nginx routes by server_name',
        );
      } else {
        seen[lower] = role;
      }
    }
    return problems;
  }

  static final RegExp _hostName = RegExp(
    r'^(?=.{1,253}$)([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+'
    r'[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$',
  );

  static const _knownKeys = {
    'host',
    'ssh_user',
    'deploy_user',
    'os',
    'repo',
    'branch',
    'ssl_email',
    'api_domain',
    'app_domain',
    'site',
    'storage',
    'storage_domain',
    'registry_mirror',
    'firewall_ports',
    'requires',
  };

  static void _unknownKeys(
    YamlMap map,
    Set<String> known,
    String source,
    List<String> problems,
  ) {
    for (final key in map.keys.map((key) => key.toString())) {
      if (!known.contains(key)) {
        final names = (known.toList()..sort()).join(', ');
        problems.add('$source: unknown key "$key" (known: $names)');
      }
    }
  }

  /// Environment names declared in `deploy/config.yaml`, in file order.
  static List<String> environmentsIn(Directory projectRoot) {
    final file = File(p.join(projectRoot.path, 'deploy', 'config.yaml'));
    if (!file.existsSync()) {
      return const [];
    }
    final document = loadYaml(file.readAsStringSync());
    if (document is! YamlMap) {
      return const [];
    }
    return deployableIn(document);
  }

  /// The environments of [document] that describe a machine to deploy to.
  ///
  /// The file also holds what belongs to the project rather than to one of its
  /// machines: the hoisted `requires:`, and `local` — the environment a
  /// developer's own machine starts a server with, which has no host to reach
  /// and nothing to provision.
  static List<String> deployableIn(YamlMap document) => [
    for (final key in document.keys)
      if (!_projectKeys.contains(key.toString())) key.toString(),
  ];

  /// Top-level keys of `deploy/config.yaml` that are not deployments.
  static const _projectKeys = {'requires', localSection};

  /// The section holding the environment a developer's machine starts a server
  /// with, in this file and in `deploy/secrets.yaml`.
  ///
  /// Read by the project's own entry point through `DwLocalEnvironment`, never
  /// by a deploy.
  static const String localSection = 'local';
}

/// Whether [key] can be a key of the secret store: an environment variable
/// name as a shell and Compose read one.
///
/// Upper case only. The store becomes the server's environment, where a
/// lower-case name is legal and also the first thing a reader mistakes for a
/// typo. `COMPOSE_*` is refused because Compose reads those names out of the
/// rendered `.env` as its own settings — `COMPOSE_PROJECT_NAME` there would
/// quietly deploy a second stack beside the first.
bool dwIsSecretKeyName(String key) =>
    RegExp(r'^[A-Z_][A-Z0-9_]*$').hasMatch(key) && !key.startsWith('COMPOSE_');

/// Whether [name] can be mounted: one file of the flat store, by name, and not
/// the store's own key file.
bool dwIsSecretFileName(String name) =>
    RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(name) &&
    name != '.' &&
    name != '..' &&
    name != 'secrets.env';

/// One `requires:` block: what a server needs delivered before it starts.
class _DwRequires {
  const _DwRequires(this.secrets, this.files);

  final List<String> secrets;
  final List<String> files;
}
