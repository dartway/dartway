import 'dart:io';

import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_example_server/dartway_example_server.dart';

/// `dart run bin/migrate.dart <apply|rollback|status|create <name>|check|rehash>`
Future<void> main(List<String> args) async {
  exitCode = await DwMigrationCli(
    schema: dartwayExampleSchema,
    migrations: appMigrations,
    directory: 'lib/src/migrations',
    modules: {'dw': DwAppServer.frameworkMigrations},
    database: DwDatabaseConfig.fromEnvironment(Platform.environment),
  ).run(args);
}
