import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../deploy/local_environment.dart';
import 'dw_check_type.dart';
import 'dw_check_tally.dart';

/// Reports what the `local` environment is missing, and where it has drifted
/// from the containers it describes.
///
/// `deploy/config.yaml > local` is what the project's entry points start a
/// server with, and the development containers it points at are declared a
/// second time in the server package's `docker-compose.yaml` — one file read
/// by Compose, the other by the server, with nothing making them agree. This
/// is what makes them agree.
class DwLocalEnvironmentInspector {
  DwLocalEnvironmentInspector({
    required this.projectRoot,
    this.serverPackageDir,
    DwCheckType? filterType,
    DwCheckSeverity? filterSeverity,
  }) : _types = {
         for (final type in const [
           DwCheckType.localSecretMissing,
           DwCheckType.devComposeDrifted,
         ])
           if ((filterType == null || filterType == type) &&
               (filterSeverity == null || filterSeverity == type.severity))
             type,
       };

  final Directory projectRoot;
  final Directory? serverPackageDir;
  final Set<DwCheckType> _types;

  /// Findings by check, in the order they are reported.
  final _findings = <DwCheckType, List<String>>{};

  List<String> findingsOf(DwCheckType type) =>
      List.unmodifiable(_findings[type] ?? const []);

  int run({DwCheckTally? tally}) {
    if (_types.isEmpty) return 0;

    final environment = DwLocalEnvironment(projectRoot);
    final Map<String, String> committed;
    final Map<String, String> mine;
    try {
      committed = environment.committed;
      mine = environment.mine;
    } on StateError catch (error) {
      // A file that cannot be read is the server's problem before it is this
      // check's, and it says so in the same words.
      print('\n🔑 Local environment:\n');
      print(
        '  ${DwCheckType.localSecretMissing.reportLabel}: ${error.message}',
      );
      return 0;
    }

    if (_types.contains(DwCheckType.localSecretMissing)) {
      _collectMissing(environment, committed, mine);
    }
    if (_types.contains(DwCheckType.devComposeDrifted)) {
      _collectComposeDrift(committed);
    }
    if (_findings.isEmpty) return 0;

    print('\n🔑 Local environment:\n');
    var errors = 0;
    for (final MapEntry(key: type, value: findings) in _findings.entries) {
      for (final finding in findings) {
        print('  ${type.reportLabel}: $finding');
      }
      tally?.add(type, findings.length);
      if (type.severity == DwCheckSeverity.error) errors += findings.length;
    }
    return errors;
  }

  void _collectMissing(
    DwLocalEnvironment environment,
    Map<String, String> committed,
    Map<String, String> mine,
  ) {
    final missing = environment.requiredSecrets
        .where((key) => (mine[key] ?? committed[key] ?? '').isEmpty)
        .toList();
    if (missing.isEmpty) return;
    _add(
      DwCheckType.localSecretMissing,
      '${missing.join(', ')} — declared under "requires" in '
      '${DwLocalEnvironment.configPath}, with no value for '
      '"${DwLocalEnvironment.section}". Deliver each with '
      '"dartway secret set <KEY> --env ${DwLocalEnvironment.section}", or '
      'drop it from "requires" if nothing needs it.',
    );
  }

  /// The credentials Compose creates the containers with, against the ones the
  /// server is told to reach them by.
  ///
  /// Only the values that exist on both sides are compared, and only for the
  /// two services the skeleton ships. A project that renames a service or
  /// points `local` at a database of its own is not drifting — it is doing
  /// something this check has nothing to say about.
  void _collectComposeDrift(Map<String, String> committed) {
    final dir = serverPackageDir;
    if (dir == null) return;
    final file = [
      File(p.join(dir.path, 'docker-compose.yaml')),
      File(p.join(dir.path, 'docker-compose.yml')),
    ].where((candidate) => candidate.existsSync()).firstOrNull;
    if (file == null) return;

    final Object? document;
    try {
      document = loadYaml(file.readAsStringSync());
    } on YamlException {
      return;
    }
    if (document is! YamlMap) return;
    final services = document['services'];
    if (services is! YamlMap) return;

    final name = p.join(p.basename(dir.path), p.basename(file.path));
    _compareService(
      services['postgres'],
      source: '$name > postgres',
      committed: committed,
      pairs: const {
        'POSTGRES_DB': 'DW_DATABASE_NAME',
        'POSTGRES_USER': 'DW_DATABASE_USER',
        'POSTGRES_PASSWORD': 'DW_DATABASE_PASSWORD',
      },
      portKey: 'DW_DATABASE_PORT',
    );
    final storage = services['storage'];
    if (storage == null && services['minio'] != null) {
      // Not silence: a project whose local compose still calls the service
      // `minio` is exactly the state the RustFS migration (#331) leaves a
      // project in until it edits this file by hand — nothing regenerates
      // it. Reported once, by name, rather than the drift check simply
      // finding nothing to compare and saying nothing about why.
      _add(
        DwCheckType.devComposeDrifted,
        '$name still declares a service named "minio" — rename it to '
        '"storage" and its environment to RUSTFS_ACCESS_KEY / '
        'RUSTFS_SECRET_KEY (docs/migrations/2026-09-26-storage-minio-to-rustfs.md '
        'covers the local docker-compose.yaml too), or this check has '
        'nothing to compare it against.',
      );
    } else {
      _compareService(
        storage,
        source: '$name > storage',
        committed: committed,
        pairs: const {
          'RUSTFS_ACCESS_KEY': 'DW_STORAGE_ACCESS_KEY',
          'RUSTFS_SECRET_KEY': 'DW_STORAGE_SECRET_KEY',
        },
        portKey: null,
      );
    }
  }

  void _compareService(
    Object? service, {
    required String source,
    required Map<String, String> committed,
    required Map<String, String> pairs,
    required String? portKey,
  }) {
    if (service is! YamlMap) return;
    final environment = service['environment'];
    if (environment is YamlMap) {
      for (final MapEntry(key: composeKey, value: localKey) in pairs.entries) {
        final inCompose = environment[composeKey]?.toString();
        final inLocal = committed[localKey];
        if (inCompose == null || inLocal == null) continue;
        if (inCompose == inLocal) continue;
        _add(
          DwCheckType.devComposeDrifted,
          '$source sets $composeKey and ${DwLocalEnvironment.configPath} > '
          '${DwLocalEnvironment.section} sets $localKey to something else. '
          'The container is created with one and the server is started with '
          'the other.',
        );
      }
    }

    if (portKey == null) return;
    final published = _publishedPort(service['ports']);
    final declared = committed[portKey];
    if (published == null || declared == null || published == declared) return;
    _add(
      DwCheckType.devComposeDrifted,
      '$source publishes port $published and ${DwLocalEnvironment.configPath} '
      '> ${DwLocalEnvironment.section} sets $portKey to $declared.',
    );
  }

  /// The host port of the first `ports` entry — `127.0.0.1:8090:5432` is
  /// 8090, `8090:5432` is 8090.
  String? _publishedPort(Object? ports) {
    if (ports is! YamlList || ports.isEmpty) return null;
    final parts = ports.first.toString().split(':');
    if (parts.length < 2) return null;
    return parts[parts.length - 2];
  }

  void _add(DwCheckType type, String finding) =>
      _findings.putIfAbsent(type, () => []).add(finding);
}
