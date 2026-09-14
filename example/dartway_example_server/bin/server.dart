import 'dart:io';

import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_example_server/dartway_example_server.dart';

/// Starts the example server. Configured by the environment:
///
/// - `DW_DATABASE_*` — the database (see `DwDatabaseConfig.fromEnvironment`);
/// - `PORT` — the port to listen on, 8080 by default;
/// - `DW_MIN_APP_BUILD` — the oldest app build still served; an older one is
///   shown the "update the app" screen. Raising it needs a restart, not a
///   release;
/// - `DW_ALLOWED_ORIGINS` — the browser origins that may open the live socket
///   besides the one it is served on, comma-separated full origins
///   (`https://app.example.com,http://localhost:5000`): scheme, host and port
///   all count. A web app served through the same host, as R2.7 deploys it,
///   needs none; the server refuses to start on an entry that is not an
///   origin.
Future<void> main() async {
  final env = Platform.environment;
  final server = buildExampleServer(
    database: DwDatabaseConfig.fromEnvironment(env),
    port: int.parse(env['PORT'] ?? '8080'),
    settings: DwServerSettings(
      minAppBuild: int.parse(env['DW_MIN_APP_BUILD'] ?? '0'),
      allowedOrigins: {
        for (final entry in (env['DW_ALLOWED_ORIGINS'] ?? '').split(','))
          if (entry.trim() case final origin when origin.isNotEmpty) origin,
      },
    ),
  );
  await server.start();
}
