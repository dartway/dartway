/// The DartWay example server: a fitness club.
library;

import 'package:dartway_example_shared/dartway_example_shared.dart';
import 'package:dartway_orm/dartway_orm.dart';
import 'package:dartway_server/dartway_server.dart';

import 'generated/dw_schema.dart';
import 'src/example_auth.dart';
import 'src/example_channels.dart';
import 'src/handlers/admin_handlers.dart';
import 'src/handlers/booking_handlers.dart';
import 'src/handlers/content_handlers.dart';
import 'src/handlers/profile_handlers.dart';
import 'src/handlers/schedule_handlers.dart';
import 'src/migrations/migrations.dart';

export 'generated/dw_schema.dart';

/// Builds the example server. `bin/server.dart` starts it; tests start it on a
/// free port against their own database.
DwServer buildExampleServer({
  required DwDatabaseConfig database,
  int port = 8080,
}) => DwServer(
  protocol: dartwayExampleProtocol,
  schema: dartwayExampleSchema,
  migrations: appMigrations,
  database: database,
  auth: exampleAuth,
  handlers: [
    ...profileHandlers,
    ...scheduleHandlers,
    ...bookingHandlers,
    ...contentHandlers,
    ...adminHandlers,
  ],
  channels: exampleChannels,
  port: port,
);
