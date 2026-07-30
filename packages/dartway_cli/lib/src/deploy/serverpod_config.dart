import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'yaml_reader.dart';

/// One of the three servers Serverpod can expose.
class DwServerEndpoint {
  DwServerEndpoint({
    required this.name,
    required this.port,
    required this.publicHost,
    required this.publicPort,
    required this.publicScheme,
  });

  /// Key in the Serverpod config: `apiServer`, `insightsServer`, `webServer`.
  final String name;

  final int? port;
  final String? publicHost;
  final int? publicPort;
  final String? publicScheme;
}

/// The Serverpod runtime configuration for one run mode.
///
/// This is the source of truth for domains, ports and the database. The
/// deployment reads it and never writes it.
class DwServerpodConfig {
  DwServerpodConfig({
    required this.environment,
    required this.relativePath,
    required this.apiServer,
    required this.insightsServer,
    required this.webServer,
    required this.databaseHost,
    required this.databasePort,
    required this.databaseName,
    required this.databaseUser,
    required this.redisEnabled,
    required this.redisHost,
  });

  final String environment;

  /// Path relative to the project root, used in messages.
  final String relativePath;

  final DwServerEndpoint apiServer;
  final DwServerEndpoint? insightsServer;
  final DwServerEndpoint? webServer;

  final String? databaseHost;
  final int? databasePort;
  final String? databaseName;
  final String? databaseUser;

  final bool redisEnabled;
  final String? redisHost;

  /// Service name of the Postgres container this deployment manages. Any other
  /// `database.host` means an external database that must not be created here.
  static const managedDatabaseHost = 'postgres';

  /// Service name of the Redis container this deployment manages.
  static const managedRedisHost = 'redis';

  /// True when the database runs as a container owned by this deployment.
  bool get managesDatabase => databaseHost == managedDatabaseHost;

  /// True when Redis runs as a container owned by this deployment.
  bool get managesRedis => redisEnabled && redisHost == managedRedisHost;

  /// Every endpoint declared in the config, in a stable order.
  List<DwServerEndpoint> get endpoints => [
    apiServer,
    if (insightsServer != null) insightsServer!,
    if (webServer != null) webServer!,
  ];

  /// Secret keys the server reads at startup and cannot be launched without.
  List<String> get requiredPasswordKeys => [
    'database',
    'serviceSecret',
    'dwAuthKeySalt',
    'dwVerificationCodeSalt',
    if (redisEnabled) 'redis',
  ];

  static DwServerpodConfig load({
    required Directory projectRoot,
    required String serverPackage,
    required String environment,
  }) {
    final relativePath = p.join(serverPackage, 'config', '$environment.yaml');
    final file = File(p.join(projectRoot.path, relativePath));
    if (!file.existsSync()) {
      throw StateError(
        'No $relativePath.\n'
        'The deployment reads domains, ports and the database from the '
        'Serverpod configuration; create it before deploying.',
      );
    }

    final document = loadYaml(file.readAsStringSync());
    if (document is! YamlMap) {
      throw StateError('$relativePath must be a map.');
    }
    final reader = DwYamlReader(document, source: relativePath);

    DwServerEndpoint? endpoint(String key) {
      final section = reader.optionalMap(key);
      if (section == null) {
        return null;
      }
      final sectionReader = DwYamlReader(
        section,
        source: '$relativePath > $key',
      );
      return DwServerEndpoint(
        name: key,
        port: sectionReader.optionalInt('port'),
        publicHost: sectionReader.optionalString('publicHost'),
        publicPort: sectionReader.optionalInt('publicPort'),
        publicScheme: sectionReader.optionalString('publicScheme'),
      );
    }

    final api = endpoint('apiServer');
    if (api == null) {
      throw StateError('$relativePath: missing required section "apiServer".');
    }

    final database = reader.optionalMap('database');
    final databaseReader = database == null
        ? null
        : DwYamlReader(database, source: '$relativePath > database');

    final redis = reader.optionalMap('redis');
    final redisReader = redis == null
        ? null
        : DwYamlReader(redis, source: '$relativePath > redis');

    return DwServerpodConfig(
      environment: environment,
      relativePath: relativePath,
      apiServer: api,
      insightsServer: endpoint('insightsServer'),
      webServer: endpoint('webServer'),
      databaseHost: databaseReader?.optionalString('host'),
      databasePort: databaseReader?.optionalInt('port'),
      databaseName: databaseReader?.optionalString('name'),
      databaseUser: databaseReader?.optionalString('user'),
      redisEnabled: redisReader?.optionalBool('enabled') ?? false,
      redisHost: redisReader?.optionalString('host'),
    );
  }
}
