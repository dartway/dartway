import 'dart:io';

import 'package:dartway_example_server/dartway_example_server.dart';
import 'package:dartway_orm/dartway_orm.dart';

Future<void> main() async {
  final env = Platform.environment;
  final server = buildExampleServer(
    database: DwDatabaseConfig.fromEnvironment(env),
    port: int.parse(env['PORT'] ?? '8080'),
  );
  await server.start();
}
