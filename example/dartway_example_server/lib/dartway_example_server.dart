/// The DartWay example server: a fitness club.
library;

import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';
import 'package:dartway_push_server/dartway_push_server.dart';

import 'generated/dw_schema.dart';
import 'src/example_auth.dart';
import 'src/example_bootstrap.dart';
import 'src/example_channels.dart';
import 'src/example_files.dart';
import 'src/example_push.dart';
import 'src/handlers/admin_handlers.dart';
import 'src/handlers/booking_handlers.dart';
import 'src/handlers/chat_handlers.dart';
import 'src/handlers/content_handlers.dart';
import 'src/handlers/profile_handlers.dart';
import 'src/handlers/schedule_handlers.dart';
import 'src/migrations/migrations.dart';

export 'generated/dw_schema.dart';
export 'src/example_auth.dart' show ExampleAuth;
export 'src/example_bootstrap.dart' show ExampleBootstrap;
export 'src/example_files.dart' show ExampleFiles;
export 'src/example_push.dart' show ExamplePush;
export 'src/migrations/migrations.dart' show appMigrations;

/// The club's server, as `bin/server.dart` and the tests build it.
abstract final class ExampleServer {
  /// Builds the example server. `bin/server.dart` starts it; tests start it on a
  /// free port against their own database.
  ///
  /// With [storage] the server takes uploads by [ExampleFiles.uploadRules] — public
  /// purposes into its public bucket, private ones into its private bucket —
  /// and checks both buckets as it starts; without it, it has no files.
  ///
  /// [push] sends notifications (`ExamplePush.module`); by default it has no providers
  /// and records deliveries it has nobody to send through.
  static DwAppServer build({
    required DwDatabaseConfig database,
    DwFileStorageConfig? storage,
    int port = 8080,
    DwAuthConfig? auth,
    DwServerSettings settings = const DwServerSettings(),
    DwPushModule? push,
  }) => DwAppServer(
    protocol: exampleProtocol,
    schema: dartwayExampleSchema,
    migrations: appMigrations,
    migrationsDirectory: 'lib/src/migrations',
    database: database,
    auth: auth ?? ExampleAuth.config,
    handlers: [
      ...profileHandlers,
      ...scheduleHandlers,
      ...bookingHandlers,
      ...contentHandlers,
      ...chatHandlers,
      ...adminHandlers,
    ],
    channels: ExampleChannels.rules,
    startup: [DwFirstAdministrator(grant: ExampleBootstrap.grantAdmin)],
    files: storage == null ? null : ExampleFiles.storage(storage),
    modules: [push ?? ExamplePush.module()],
    port: port,
    settings: settings,
  );
}
