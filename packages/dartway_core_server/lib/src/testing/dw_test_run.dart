import 'dart:io';

import 'package:dartway_orm/dartway_orm.dart';

/// Run-owned names override per-file prefixes so the CLI can recover resources
/// after the test process has stopped, even when its teardown never ran.
String? testRunId([Map<String, String>? environment]) {
  final id = (environment ?? Platform.environment)['DW_TEST_RUN_ID'];
  if (id == null) return null;
  if (!RegExp(r'^[a-z0-9]{16}$').hasMatch(id)) {
    throw ArgumentError(
      'DW_TEST_RUN_ID must be 16 lower-case letters or digits',
    );
  }
  return id;
}

/// An explicit local URL can omit a password for a trust-authenticated server.
/// Keep the normal environment validation, including rejecting a missing key.
DwDatabaseConfig testDatabaseConfig(Map<String, String> environment) {
  final emptyPassword = environment['DW_DATABASE_PASSWORD'] == '';
  final config = DwDatabaseConfig.fromEnvironment({
    ...environment,
    if (emptyPassword) 'DW_DATABASE_PASSWORD': 'unused',
  });
  if (!emptyPassword) return config;
  return DwDatabaseConfig(
    host: config.host,
    port: config.port,
    name: config.name,
    user: config.user,
    password: '',
    ssl: config.ssl,
    caFile: config.caFile,
    maxConnections: config.maxConnections,
  );
}
