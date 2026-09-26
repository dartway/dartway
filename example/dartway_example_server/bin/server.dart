import 'dart:io';

import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_example_server/dartway_example_server.dart';

/// Starts the example server. Configured by the environment — and on a
/// developer's machine `DwLocalEnvironment.overlay` puts
/// `deploy/config.yaml > local` and `deploy/secrets.yaml > local` into it
/// first, so nothing has to be exported. A real variable beats both:
///
/// - `DW_DATABASE_*` — the database (see `DwDatabaseConfig.fromEnvironment`);
/// - `DW_MIGRATE_ONLY=true` — applies the migrations and exits without
///   serving: how `dartway deploy` migrates between the old server and the
///   new one;
/// - `PORT` — the port to listen on, 8080 by default;
/// - `DW_ALLOWED_ORIGINS` — the browser origins that may open the live socket
///   besides the one it is served on, comma-separated full origins
///   (`https://app.example.com,http://localhost:5000`): scheme, host and port
///   all count. A web app served through the same host (`docs/4-server/app-server.md`
///   "Same origin"), as the deploy does it,
///   needs none; the server refuses to start on an entry that is not an
///   origin;
/// - `DW_STORAGE_*` — file storage (see `ExampleFiles.storageConfig`): without
///   `DW_STORAGE_ENDPOINT` the server takes no uploads. `DW_STORAGE_ENDPOINT`,
///   `DW_STORAGE_ACCESS_KEY` and `DW_STORAGE_SECRET_KEY` are required with
///   it; the buckets default to `club-public` and `club-private`, and the
///   public base URL to the public bucket on the endpoint. At startup the
///   server verifies that the public bucket reads anonymously and the private
///   one does not (`DW_STORAGE_VERIFY_BUCKETS=false` skips it);
/// - `FCM_SERVICE_ACCOUNT_FILE`, `FCM_WEB_LINK_BASE`,
///   `RUSTORE_PUSH_PROJECT_ID`, `RUSTORE_PUSH_SERVICE_TOKEN` — push providers
///   (see `ExamplePush.providers`); without them the server queues and records
///   notifications but has nothing to send them through;
/// - `DW_STORAGE_PROVISION=true` — creates both buckets and sets their access
///   before starting (`DwFileStorageSetup.provision`): for a development
///   storage the project owns, never for a storage somebody else administers.
Future<void> main() async {
  final env = DwLocalEnvironment.overlay(Platform.environment);
  final storage = ExampleFiles.storageConfig(env);
  if (storage != null && env['DW_STORAGE_PROVISION'] == 'true') {
    await DwFileStorageSetup.provision(storage);
  }
  final server = ExampleServer.build(
    database: DwDatabaseConfig.fromEnvironment(env),
    storage: storage,
    port: int.parse(env['PORT'] ?? '8080'),
    push: ExamplePush.module(providers: ExamplePush.providers(env)),
    settings: DwServerSettings(
      allowedOrigins: {
        for (final entry in (env['DW_ALLOWED_ORIGINS'] ?? '').split(','))
          if (entry.trim() case final origin when origin.isNotEmpty) origin,
      },
    ),
  );
  await server.start();
}
