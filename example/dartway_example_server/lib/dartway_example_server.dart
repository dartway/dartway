/// The DartWay example server: a fitness club.
library;

import 'package:dartway_analytics_server/dartway_analytics_server.dart';
import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';
import 'package:dartway_push_server/dartway_push_server.dart';

import 'generated/dw_schema.dart';
import 'src/core/auth.dart';
import 'src/core/bootstrap.dart';
import 'src/core/call_context.dart';
import 'src/core/files.dart';
import 'src/core/push.dart';
import 'src/admin/admin_feature.dart';
import 'src/bookings/bookings_feature.dart';
import 'src/chat/chat_feature.dart';
import 'src/content/content_feature.dart';
import 'src/migrations/migrations.dart';
import 'src/profile/profile_feature.dart';
import 'src/schedule/schedule_feature.dart';

export 'generated/dw_schema.dart';
export 'src/core/auth.dart' show AppAuth;
export 'src/core/bootstrap.dart' show AppBootstrap;
export 'src/core/environment.dart' show AppEnvironment, AppPushEnvironment;
export 'src/core/files.dart' show AppFiles;
export 'src/core/push.dart' show AppPush;
export 'src/migrations/migrations.dart' show appMigrations;

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
  ///
  /// [adminIdentifier] is made an administrator at every start
  /// (`DwFirstAdministrator`): `bin/server.dart` passes `DW_ADMIN_IDENTIFIER`,
  /// read into `DwServerEnvironment.adminIdentifier`.
  /// [clock] is the time every handler and job reads as `ctx.now` — the
  /// system's, unless a test sets its own (`DwTestClock`).
  static DwAppServer build({
    required DwDatabaseConfig database,
    DwFileStorageConfig? storage,
    int port = 8080,
    DwAuthConfig? auth,
    DwServerSettings settings = const DwServerSettings(),
    required String? adminIdentifier,
    DwPushModule? push,
    DwServerClock clock = DwServerClock.system,
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
    startup: [
      DwFirstAdministrator(
        grant: AppBootstrap.grantAdmin,
        identifier: adminIdentifier,
      ),
    ],
    files: storage == null ? null : AppFiles.storage(storage),
    modules: [
      push ?? AppPush.module(),
      // The admin panel's dashboards: admins read and edit, staff and
      // members do not.
      DwAnalyticsModule(readAccess: AppAccess.admin),
    ],
    port: port,
    settings: settings,
    clock: clock,
  );
}
