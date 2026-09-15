import 'dart:io';

import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_example_server/dartway_example_server.dart';
import 'package:dartway_push_server/dartway_push_server.dart';

/// `dart run bin/migrate.dart <apply|rollback|status|create <name>|check|rehash>`
Future<void> main(List<String> args) async {
  exitCode = await DwMigrationCli(
    schema: dartwayExampleSchema,
    migrations: appMigrations,
    directory: 'lib/src/migrations',
    modules: {
      'dw': DwAppServer.frameworkMigrations,
      dwPushNamespace: dwPushMigrations,
    },
    database: DwDatabaseConfig.fromEnvironment(Platform.environment),
  ).run(args);
}
