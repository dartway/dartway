import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'yaml_reader.dart';

/// Where uploaded files live for an environment.
enum DwStorageMode {
  /// The server is deployed without file storage.
  none,

  /// A MinIO container in the stack, reached by browsers on its own domain.
  minio,

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

  /// The public host of the MinIO container. Browsers upload to it directly,
  /// so it cannot hide behind the app's origin: a presigned URL signs its host.
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
        'Copy deploy/config.yaml.example over it and fill it in, or run this '
        'command from a DartWay project root.',
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
    final section = document[environment];
    if (section == null) {
      final known = document.keys.join(', ');
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
          '$source: "storage" is minio or external, got "$storageText"',
        );
      } else {
        storage = mode;
      }
    }
    final storageDomain = guarded(
      () => reader.optionalString('storage_domain'),
    );
    if (storage == DwStorageMode.minio && storageDomain == null) {
      problems.add(
        '$source: "storage: minio" needs "storage_domain" — browsers upload '
        'to MinIO directly, on a host of its own',
      );
    }
    if (storage != DwStorageMode.minio && storageDomain != null) {
      problems.add(
        '$source: "storage_domain" is only read with "storage: minio"; an '
        'external storage is addressed by DW_STORAGE_ENDPOINT in the secret '
        'store',
      );
    }

    final requires = guarded(() => reader.optionalMap('requires'));
    DwYamlReader? requiresReader;
    if (requires != null) {
      _unknownKeys(
        requires,
        const {'secrets', 'files'},
        '$source > requires',
        problems,
      );
      requiresReader = DwYamlReader(requires, source: '$source > requires');
    }
    final requiredSecrets =
        guarded(() => requiresReader?.optionalStringList('secrets')) ??
        const <String>[];
    final requiredSecretFiles =
        guarded(() => requiresReader?.optionalStringList('files')) ??
        const <String>[];
    for (final key in requiredSecrets) {
      if (!dwIsSecretKeyName(key)) {
        problems.add(
          '$source > requires > secrets: "$key" is not a secret name — an '
          'environment variable in upper case letters, digits and '
          'underscores, not starting with a digit or COMPOSE_',
        );
      }
    }
    for (final name in requiredSecretFiles) {
      if (!dwIsSecretFileName(name)) {
        problems.add(
          '$source > requires > files: "$name" is not a file name. Each entry '
          'names one file in the secret store, mounted into the server under '
          'the same name; a pattern or a path cannot be mounted',
        );
      }
    }

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
    return document.keys.map((key) => key.toString()).toList();
  }
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
