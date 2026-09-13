import 'dart:io';

import 'package:dartway_example_server/dartway_example_server.dart';
import 'package:dartway_orm/dartway_orm.dart';

Future<void> main() async {
  final env = Platform.environment;
  final server = buildExampleServer(
    database: DwDatabaseConfig.fromEnvironment(env),
    port: int.parse(env['PORT'] ?? '8080'),
    // A web app served from another origin than the API (a CDN, a local dev
    // server on another port) is refused at the WebSocket upgrade unless its
    // origin is listed: `DW_ALLOWED_ORIGINS=http://localhost:5000,https://app.example.com`.
    allowedOrigins: {
      for (final origin in (env['DW_ALLOWED_ORIGINS'] ?? '').split(','))
        if (origin.trim().isNotEmpty) origin.trim(),
    },
  );
  await server.start();
}
