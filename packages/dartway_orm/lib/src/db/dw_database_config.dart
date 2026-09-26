/// Where and how to connect to Postgres.
final class DwDatabaseConfig {
  const DwDatabaseConfig({
    required this.host,
    this.port = 5432,
    required this.name,
    required this.user,
    required this.password,
    this.ssl = true,
    this.caFile,
    this.maxConnections = 10,
    this.applicationName = 'dartway',
    this.connectTimeout = const Duration(seconds: 15),
    this.queryTimeout = const Duration(minutes: 5),
    this.statementCacheSize = 256,
  }) : assert(maxConnections > 0),
       assert(statementCacheSize > 0),
       assert(
         caFile == null || ssl,
         'caFile needs ssl: true — a CA has nothing to verify without TLS',
       );

  /// Reads `HOST`, `PORT`, `NAME`, `USER`, `PASSWORD`, `SSL`, `CA_FILE` and
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

    String? optional(String key) {
      final value = environment['$prefix$key'];
      return value == null || value.isEmpty ? null : value;
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
    final caFile = optional('CA_FILE');
    final maxConnections = integer('MAX_CONNECTIONS');
    if (caFile != null && ssl == false) {
      problems.add(
        '${prefix}CA_FILE is set but ${prefix}SSL is "false": a CA file only '
        'means something over an encrypted connection. Drop ${prefix}CA_FILE '
        'or remove ${prefix}SSL=false.',
      );
    }
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
      caFile: caFile,
      maxConnections: maxConnections ?? 10,
    );
  }

  final String host;
  final int port;
  final String name;
  final String user;
  final String password;

  /// Encrypted unless disabled. The driver's `require` mode: the channel is
  /// encrypted, the certificate is not verified — unless [caFile] is set, in
  /// which case the connection verifies the server's certificate against that
  /// CA instead (the driver's `verify-full`).
  final bool ssl;

  /// A CA certificate file the server's certificate is verified against
  /// (`SslMode.verifyFull`), instead of the encrypted-but-unverified default.
  /// A path, not the certificate text — the driver reads it from disk. Unset
  /// unless `DW_DATABASE_CA_FILE` names one; the contradiction with
  /// `ssl: false` is rejected both by [fromEnvironment] (a proper
  /// `ArgumentError`, naming both keys) and by an assertion on the
  /// constructor itself, so a value built by hand — `copyWith`, a test,
  /// the migration CLI — cannot silently combine them either.
  final String? caFile;

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
        caFile: caFile,
        maxConnections: maxConnections ?? this.maxConnections,
        applicationName: applicationName,
        connectTimeout: connectTimeout,
        queryTimeout: queryTimeout,
        statementCacheSize: statementCacheSize,
      );

  /// The password is never part of the text.
  @override
  String toString() =>
      'DwDatabaseConfig($user@$host:$port/$name, ssl: $ssl, '
      '${caFile == null ? 'unverified' : 'verify-full: $caFile'}, '
      'maxConnections: $maxConnections)';
}
