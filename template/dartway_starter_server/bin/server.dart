import 'dart:io';

import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_starter_server/dartway_starter_server.dart';

/// Starts the server. Configured by the environment alone — there is no
/// configuration file:
///
/// - `DW_DATABASE_*` — the database (`DwDatabaseConfig.fromEnvironment`:
///   `HOST`, `PORT`, `NAME`, `USER`, `PASSWORD`, `SSL`, `MAX_CONNECTIONS`).
///   The server applies its migrations as it starts and exits non-zero when
///   one fails;
/// - `PORT` — the port to listen on, 8080 by default;
/// - `DW_STORAGE_*` — the S3-compatible storage for uploads
///   (`appStorageConfig`): `ENDPOINT`, `ACCESS_KEY` and `SECRET_KEY` together;
///   `PUBLIC_BUCKET` and `PRIVATE_BUCKET` (named after the project),
///   `PUBLIC_BASE_URL` (the public bucket on the endpoint), `REGION`,
///   `PATH_STYLE`, `VERIFY_BUCKETS`. Without `DW_STORAGE_ENDPOINT` the server
///   runs without uploads;
/// - `DW_STORAGE_PROVISION=true` — creates both buckets and sets their access
///   before starting (`DwFileStorageSetup.provision`): for a development MinIO
///   the project owns, never for a storage somebody else administers;
/// - `DW_MIN_APP_BUILD` — the oldest app build still served; an older one is
///   shown the "update the app" screen. Raising it needs a restart, not a
///   release;
/// - `DW_ALLOWED_ORIGINS` — browser origins, besides the one the live socket
///   is served on, that may open it: comma-separated full origins
///   (`https://app.example.com,http://localhost:5000`). A web app served
///   through the same host, as the deploy and `dartway dev` serve it, needs
///   none;
/// - `APP_BOOTSTRAP_ADMIN` — the phone or e-mail of the first administrator,
///   made one on every start; unset for none.
Future<void> main() async {
  final env = Platform.environment;
  final adminIdentifier = env[bootstrapAdminVariable]?.trim() ?? '';
  // Checked before anything starts: a mistyped admin is a startup error.
  if (adminIdentifier.isNotEmpty) parseAdminIdentifier(adminIdentifier);

  final storage = appStorageConfig(env);
  if (storage != null && env['DW_STORAGE_PROVISION'] == 'true') {
    await DwFileStorageSetup.provision(storage);
  }
  final server = buildDartwayStarterServer(
    database: DwDatabaseConfig.fromEnvironment(env),
    storage: storage,
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

  if (storage == null) {
    server.logger.warning(
      'DW_STORAGE_ENDPOINT is not set: profile photos cannot be uploaded.',
    );
  }
  if (adminIdentifier.isEmpty) {
    server.logger.warning(
      'No administrator is declared: set $bootstrapAdminVariable to reach the '
      'admin panel.',
    );
  } else if (await ensureAdministrator(server, adminIdentifier)) {
    server.logger.info('Administrator ensured: $adminIdentifier');
  } else {
    server.logger.info('Administrator already in place: $adminIdentifier');
  }
}
