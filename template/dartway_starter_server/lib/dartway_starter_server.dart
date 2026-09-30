/// The server of the app.
library;

import 'package:dartway_analytics_server/dartway_analytics_server.dart';
import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_starter_server/generated/dw_schema.dart';
import 'package:dartway_starter_server/src/account/account_feature.dart';
import 'package:dartway_starter_server/src/account/logic/auth.dart';
import 'package:dartway_starter_server/src/admin/admin_feature.dart';
import 'package:dartway_starter_server/src/migrations/migrations.dart';
import 'package:dartway_starter_server/src/profile/profile_access.dart';
import 'package:dartway_starter_server/src/profile/profile_feature.dart';
import 'package:dartway_starter_server/src/settings/settings_feature.dart';
import 'package:dartway_starter_shared/dartway_starter_shared.dart';

export 'package:dartway_starter_server/generated/dw_schema.dart';
export 'package:dartway_starter_server/src/account/logic/auth.dart'
    show AccountAuth, CodeDelivery;
export 'package:dartway_starter_server/src/core/environment.dart'
    show AppEnvironment;
export 'package:dartway_starter_server/src/core/files.dart' show AppFiles;
export 'package:dartway_starter_server/src/migrations/migrations.dart'
    show appMigrations;

/// The app's server, as `bin/server.dart` and the tests build it.
///
/// The one file that sees every feature: it lists them, hands the sign-in
/// hooks to the server and every upload purpose's rule to the storage.
abstract final class DartwayStarterServer {
  /// Builds the server. `bin/server.dart` starts it from the environment; tests
  /// start it on a free port against their own database.
  ///
  /// With [storage] the server takes uploads by [uploadRules] and checks both
  /// buckets as it starts; without it, it runs and has no files.
  ///
  /// [adminIdentifier] is made an administrator at every start (the account
  /// feature's `DwFirstAdministrator`): `bin/server.dart` passes
  /// `DW_ADMIN_IDENTIFIER`, read into `DwServerEnvironment.adminIdentifier`.
  /// [clock] is the time every handler and job reads as `ctx.now` — the
  /// system's, unless a test sets its own (`DwTestClock`).
  static DwAppServer build({
    required DwDatabaseConfig database,
    DwFileStorageConfig? storage,
    int port = 8080,
    DwAuthConfig? auth,
    DwServerSettings settings = const DwServerSettings(),
    required String? adminIdentifier,
    DwServerClock clock = DwServerClock.system,
  }) => DwAppServer(
    protocol: appProtocol,
    schema: dartwayStarterSchema,
    migrations: appMigrations,
    migrationsDirectory: 'lib/src/migrations',
    database: database,
    auth: auth ?? AccountAuth.config(),
    features: [
      profileFeature,
      adminFeature,
      settingsFeature,
      accountFeature(adminIdentifier: adminIdentifier),
    ],
    // The app's events, and the admin panel's reports and dashboards over
    // them: admins read and edit, nobody else.
    modules: [DwAnalyticsModule(readAccess: ProfileAccess.admin)],
    files: storage == null ? null : DwFileStorage(storage, rules: uploadRules),
    port: port,
    settings: settings,
    clock: clock,
  );

  /// One rule per [DartwayStarterUpload], each declared by the feature the
  /// purpose belongs to. Adding a purpose is adding its rule there and
  /// listing it here — the buckets, the keys and the startup check follow.
  static List<DwUploadRule> get uploadRules => [ProfileAccess.avatarUpload];
}
