import 'package:dartway_example_server/dartway_example_server.dart';
import 'package:dartway_example_server/src/migrations/migrations.dart';
import 'package:dartway_orm/dartway_orm.dart';

Future<void> main(List<String> args) => DwMigrationCli(
  schema: dartwayExampleSchema,
  migrations: appMigrations,
  directory: 'lib/src/migrations',
).run(args);
