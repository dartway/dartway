/// The server of the app.
library;

import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_starter_shared/dartway_starter_shared.dart';

import 'generated/dw_schema.dart';
import 'src/auth.dart';
import 'src/bootstrap.dart';
import 'src/channels.dart';
import 'src/files.dart';
import 'src/handlers/admin_handlers.dart';
import 'src/handlers/profile_handlers.dart';
import 'src/handlers/settings_handlers.dart';
import 'src/migrations/migrations.dart';

export 'generated/dw_schema.dart';
export 'src/auth.dart' show AppAuth, CodeDelivery;
export 'src/bootstrap.dart';
export 'src/files.dart' show AppFiles;
export 'src/migrations/migrations.dart' show appMigrations;

/// The app's server, as `bin/server.dart` and the tests build it.
abstract final class DartwayStarterServer {
  /// Builds the server. `bin/server.dart` starts it from the environment; tests
  /// start it on a free port against their own database.
  ///
  /// With [storage] the server takes uploads by [AppFiles.uploadRules] and checks both
  /// buckets as it starts; without it, it runs and has no files.
  static DwAppServer build({
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
    auth: auth ?? AppAuth.config(),
    handlers: [...profileHandlers, ...adminHandlers, ...settingsHandlers],
    channels: AppChannels.rules,
    startup: [DwFirstAdministrator(grant: AppBootstrap.grantAdmin)],
    files: storage == null ? null : AppFiles.storage(storage),
    port: port,
    settings: settings,
  );
}
