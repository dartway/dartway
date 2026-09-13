/// Where and how to connect to Postgres.
final class DwDatabaseConfig {
  const DwDatabaseConfig({
    required this.host,
    this.port = 5432,
    required this.name,
    required this.user,
    required this.password,
    this.ssl = true,
    this.maxConnections = 10,
    this.applicationName = 'dartway',
    this.connectTimeout = const Duration(seconds: 15),
    this.queryTimeout = const Duration(minutes: 5),
    this.statementCacheSize = 256,
  }) : assert(maxConnections > 0),
       assert(statementCacheSize > 0);

  /// Reads `HOST`, `PORT`, `NAME`, `USER`, `PASSWORD`, `SSL` and
  /// `MAX_CONNECTIONS` under [prefix].
  ///
  /// Every missing required key and every malformed value is reported at
  /// once, so a misconfigured deploy fails with the whole list instead of one
  /// line per restart.
  factory DwDatabaseConfig.fromEnvironment(
    Map<String, String> environment, {
    String prefix = 'DW_DATABASE_',
  }) {
    final problems = <String>[];

    String? required(String key) {
      final value = environment['$prefix$key'];
      if (value == null || value.isEmpty) {
        problems.add('$prefix$key is not set');
      }
      return value;
    }

    int? integer(String key) {
      final raw = environment['$prefix$key'];
      if (raw == null || raw.isEmpty) return null;
      final value = int.tryParse(raw);
      if (value == null || value <= 0) {
        problems.add('$prefix$key must be a positive integer, got "$raw"');
      }
      return value;
    }

    bool? flag(String key) {
      final raw = environment['$prefix$key'];
      if (raw == null || raw.isEmpty) return null;
      switch (raw.toLowerCase()) {
        case 'true':
          return true;
        case 'false':
          return false;
      }
      problems.add('$prefix$key must be "true" or "false", got "$raw"');
      return null;
    }

    final host = required('HOST');
    final name = required('NAME');
    final user = required('USER');
    final password = required('PASSWORD');
    final port = integer('PORT');
    final ssl = flag('SSL');
    final maxConnections = integer('MAX_CONNECTIONS');
    if (problems.isNotEmpty) {
      throw ArgumentError('database configuration: ${problems.join('; ')}');
    }
    return DwDatabaseConfig(
      host: host!,
      port: port ?? 5432,
      name: name!,
      user: user!,
      password: password!,
      ssl: ssl ?? true,
      maxConnections: maxConnections ?? 10,
    );
  }

  final String host;
  final int port;
  final String name;
  final String user;
  final String password;

  /// Encrypted unless disabled. The driver's `require` mode: the channel is
  /// encrypted, the certificate is not verified.
  final bool ssl;

  /// The driver's own pool defaults to a single connection; this is the real
  /// ceiling of concurrent statements.
  final int maxConnections;
  final String applicationName;

  /// Also how long a caller waits for a free pooled connection.
  final Duration connectTimeout;
  final Duration queryTimeout;

  /// Prepared statements kept per connection.
  final int statementCacheSize;

  DwDatabaseConfig copyWith({String? name, int? maxConnections}) =>
      DwDatabaseConfig(
        host: host,
        port: port,
        name: name ?? this.name,
        user: user,
        password: password,
        ssl: ssl,
        maxConnections: maxConnections ?? this.maxConnections,
        applicationName: applicationName,
        connectTimeout: connectTimeout,
        queryTimeout: queryTimeout,
        statementCacheSize: statementCacheSize,
      );

  /// The password is never part of the text.
  @override
  String toString() =>
      'DwDatabaseConfig($user@$host:$port/$name, ssl: $ssl, maxConnections: $maxConnections)';
}
