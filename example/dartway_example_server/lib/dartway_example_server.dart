/// The DartWay example server: a fitness club.
library;

import 'package:dartway_analytics_server/dartway_analytics_server.dart';
import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';
import 'package:dartway_push_server/dartway_push_server.dart';

import 'package:dartway_example_server/generated/dw_schema.dart';
import 'package:dartway_example_server/src/core/auth.dart';
import 'package:dartway_example_server/src/core/bootstrap.dart';
import 'package:dartway_example_server/src/core/call_context.dart';
import 'package:dartway_example_server/src/core/files.dart';
import 'package:dartway_example_server/src/core/push.dart';
import 'package:dartway_example_server/src/admin/admin_feature.dart';
import 'package:dartway_example_server/src/bookings/bookings_feature.dart';
import 'package:dartway_example_server/src/chat/chat_feature.dart';
import 'package:dartway_example_server/src/content/content_feature.dart';
import 'package:dartway_example_server/src/migrations/migrations.dart';
import 'package:dartway_example_server/src/profile/profile_feature.dart';
import 'package:dartway_example_server/src/schedule/schedule_feature.dart';

export 'package:dartway_example_server/generated/dw_schema.dart';
export 'package:dartway_example_server/src/core/auth.dart' show AppAuth;
export 'package:dartway_example_server/src/core/bootstrap.dart'
    show AppBootstrap;
export 'package:dartway_example_server/src/core/files.dart' show AppFiles;
export 'package:dartway_example_server/src/core/push.dart' show AppPush;
export 'package:dartway_example_server/src/migrations/migrations.dart'
    show appMigrations;

/// The club's server, as `bin/server.dart` and the tests build it.
abstract final class DartwayExampleServer {
  /// Builds the example server. `bin/server.dart` starts it; tests start it on a
  /// free port against their own database.
  ///
  /// With [storage] the server takes uploads by [AppFiles.uploadRules] — public
  /// purposes into its public bucket, private ones into its private bucket —
  /// and checks both buckets as it starts; without it, it has no files.
  ///
  /// [push] sends notifications (`AppPush.module`); by default it has no providers
  /// and records deliveries it has nobody to send through.
  static DwAppServer build({
    required DwDatabaseConfig database,
    DwFileStorageConfig? storage,
    int port = 8080,
    DwAuthConfig? auth,
    DwServerSettings settings = const DwServerSettings(),
    DwPushModule? push,
  }) => DwAppServer(
    protocol: appProtocol,
    schema: dartwayExampleSchema,
    migrations: appMigrations,
    migrationsDirectory: 'lib/src/migrations',
    database: database,
    auth: auth ?? AppAuth.config,
    features: [
      profileFeature,
      scheduleFeature,
      bookingsFeature,
      contentFeature,
      chatFeature,
      adminFeature,
    ],
    startup: [DwFirstAdministrator(grant: AppBootstrap.grantAdmin)],
    files: storage == null ? null : AppFiles.storage(storage),
    modules: [
      push ?? AppPush.module(),
      // The admin panel's dashboards: admins read and edit, staff and
      // members do not.
      DwAnalyticsModule(readAccess: AppAccess.admin),
    ],
    port: port,
    settings: settings,
  );
}
