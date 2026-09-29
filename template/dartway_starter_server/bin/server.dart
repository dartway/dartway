import 'dart:io';

import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_starter_server/dartway_starter_server.dart';

/// Starts the server. Configured by the environment alone — the server reads
/// no configuration file, and on a developer's machine
/// `DwLocalEnvironment.overlay` puts `deploy/config.yaml > local` and
/// `deploy/secrets.yaml > local` into that environment before it is read. A
/// real environment variable beats both, and a deployed server has neither
/// file.
///
/// `AppEnvironment.read` (`lib/src/core/environment.dart`) reads every
/// variable at once and stops the start with the whole list of what is
/// missing. The framework's own, in `DwServerEnvironment`:
///
/// - `DW_DATABASE_*` — the database (`HOST`, `PORT`, `NAME`, `USER`,
///   `PASSWORD`, `SSL`, `CA_FILE`, `MAX_CONNECTIONS`). The server applies its
///   migrations as it starts and exits non-zero when one fails;
/// - `DW_MIGRATE_ONLY=true` — applies the migrations and exits without
///   serving: how `dartway deploy` migrates between the old server and the
///   new one;
/// - `PORT` — the port to listen on, 8080 by default;
/// - `DW_STORAGE_*` — the S3-compatible storage for uploads: `ENDPOINT`,
///   `ACCESS_KEY` and `SECRET_KEY` together; `PUBLIC_BUCKET` and
///   `PRIVATE_BUCKET` (named after the project by default), `PUBLIC_BASE_URL`
///   (the public bucket on the endpoint), `REGION`, `PATH_STYLE`,
///   `VERIFY_BUCKETS`. Without `DW_STORAGE_ENDPOINT` the server runs without
///   uploads;
/// - `DW_STORAGE_PROVISION=true` — creates both buckets and sets their access
///   before starting (`DwFileStorageSetup.provision`): for a development
///   storage the project owns, never for a storage somebody else administers;
/// - `DW_ALLOWED_ORIGINS` — browser origins, besides the one the live socket
///   is served on, that may open it: comma-separated full origins
///   (`https://app.example.com,http://localhost:5000`). A web app served
///   through the same host, as the deploy and `dartway dev` serve it, needs
///   none;
/// - `DW_ADMIN_IDENTIFIER` — the phone or e-mail of the first administrator,
///   made one on every start by the framework's `DwFirstAdministrator` step
///   (declared in `DartwayStarterServer.build`); unset for none.
Future<void> main() async {
  final env = AppEnvironment.read(
    DwLocalEnvironment.overlay(Platform.environment),
  );
  final storage = env.server.storage;
  if (storage != null && env.server.provisionStorage) {
    await DwFileStorageSetup.provision(storage);
  }
  final server = DartwayStarterServer.build(
    database: env.server.database,
    storage: storage,
    port: env.server.port,
    settings: DwServerSettings(allowedOrigins: env.server.allowedOrigins),
  );
  await server.start();

  if (storage == null) {
    server.logger.warning(
      'DW_STORAGE_ENDPOINT is not set: profile photos cannot be uploaded.',
    );
  }
}
