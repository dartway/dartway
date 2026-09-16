/// The server of the app.
library;

import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_starter_shared/dartway_starter_shared.dart';

import 'generated/dw_schema.dart';
import 'src/auth.dart';
import 'src/channels.dart';
import 'src/files.dart';
import 'src/handlers/admin_handlers.dart';
import 'src/handlers/profile_handlers.dart';
import 'src/handlers/settings_handlers.dart';
import 'src/migrations/migrations.dart';

export 'generated/dw_schema.dart';
export 'src/auth.dart' show CodeDelivery, appAuth, createProfile;
export 'src/bootstrap.dart';
export 'src/files.dart'
    show
        appFileStorage,
        appStorageConfig,
        appUploadRules,
        defaultPrivateBucket,
        defaultPublicBucket;
export 'src/migrations/migrations.dart' show appMigrations;

/// Builds the server. `bin/server.dart` starts it from the environment; tests
/// start it on a free port against their own database.
///
/// With [storage] the server takes uploads by [appUploadRules] and checks both
/// buckets as it starts; without it, it runs and has no files.
DwAppServer buildDartwayStarterServer({
  required DwDatabaseConfig database,
  DwFileStorageConfig? storage,
  int port = 8080,
  DwAuthConfig? auth,
  DwServerSettings settings = const DwServerSettings(),
}) => DwAppServer(
  protocol: dartwayStarterProtocol,
  schema: dartwayStarterSchema,
  migrations: appMigrations,
  migrationsDirectory: 'lib/src/migrations',
  database: database,
  auth: auth ?? appAuth(),
  handlers: [...profileHandlers, ...adminHandlers, ...settingsHandlers],
  channels: appChannels,
  files: storage == null ? null : appFileStorage(storage),
  port: port,
  settings: settings,
);
