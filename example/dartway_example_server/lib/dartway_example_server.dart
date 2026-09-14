/// The DartWay example server: a fitness club.
library;

import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';

import 'generated/dw_schema.dart';
import 'src/example_auth.dart';
import 'src/example_channels.dart';
import 'src/example_files.dart';
import 'src/handlers/admin_handlers.dart';
import 'src/handlers/booking_handlers.dart';
import 'src/handlers/chat_handlers.dart';
import 'src/handlers/content_handlers.dart';
import 'src/handlers/profile_handlers.dart';
import 'src/handlers/schedule_handlers.dart';
import 'src/migrations/migrations.dart';

export 'generated/dw_schema.dart';
export 'src/example_auth.dart' show createProfile, exampleAuth, normalizePhone;
export 'src/example_files.dart'
    show exampleFileStorage, exampleStorageConfig, exampleUploadRules;
export 'src/migrations/migrations.dart' show appMigrations;

/// Builds the example server. `bin/server.dart` starts it; tests start it on a
/// free port against their own database.
///
/// With [storage] the server takes uploads by [exampleUploadRules] — public
/// purposes into its public bucket, private ones into its private bucket —
/// and checks both buckets as it starts; without it, it has no files.
DwAppServer buildExampleServer({
  required DwDatabaseConfig database,
  DwFileStorageConfig? storage,
  int port = 8080,
  DwAuthConfig? auth,
  DwServerSettings settings = const DwServerSettings(),
}) => DwAppServer(
  protocol: dartwayExampleProtocol,
  schema: dartwayExampleSchema,
  migrations: appMigrations,
  database: database,
  auth: auth ?? exampleAuth,
  handlers: [
    ...profileHandlers,
    ...scheduleHandlers,
    ...bookingHandlers,
    ...contentHandlers,
    ...chatHandlers,
    ...adminHandlers,
  ],
  channels: exampleChannels,
  files: storage == null ? null : exampleFileStorage(storage),
  port: port,
  settings: settings,
);
