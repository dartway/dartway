import 'dart:io';

import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_starter_server/dartway_starter_server.dart';

/// `dart run bin/migrate.dart <apply|rollback|status|create <name>|check|rehash>`
/// against the database in `DW_DATABASE_*`. `create` and `check` work on
/// throwaway databases of their own next to it.
Future<void> main(List<String> args) async {
  exitCode = await DwMigrationCli(
    schema: dartwayStarterSchema,
    migrations: appMigrations,
    directory: 'lib/src/migrations',
    modules: {'dw': DwAppServer.frameworkMigrations},
    database: DwDatabaseConfig.fromEnvironment(Platform.environment),
  ).run(args);
}
