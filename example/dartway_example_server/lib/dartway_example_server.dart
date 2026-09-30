/// The DartWay example server: a fitness club.
library;

import 'package:dartway_analytics_server/dartway_analytics_server.dart';
import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_example_server/generated/dw_schema.dart';
import 'package:dartway_example_server/src/account/account_feature.dart';
import 'package:dartway_example_server/src/account/logic/auth.dart';
import 'package:dartway_example_server/src/admin/admin_feature.dart';
import 'package:dartway_example_server/src/bookings/bookings_feature.dart';
import 'package:dartway_example_server/src/chat/chat_access.dart';
import 'package:dartway_example_server/src/chat/chat_feature.dart';
import 'package:dartway_example_server/src/content/content_feature.dart';
import 'package:dartway_example_server/src/core/push.dart';
import 'package:dartway_example_server/src/migrations/migrations.dart';
import 'package:dartway_example_server/src/profile/profile_access.dart';
import 'package:dartway_example_server/src/profile/profile_feature.dart';
import 'package:dartway_example_server/src/schedule/schedule_feature.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';
import 'package:dartway_push_server/dartway_push_server.dart';

export 'package:dartway_example_server/generated/dw_schema.dart';
export 'package:dartway_example_server/src/account/logic/auth.dart'
    show AccountAuth;
export 'package:dartway_example_server/src/core/environment.dart'
    show AppEnvironment, AppPushEnvironment;
export 'package:dartway_example_server/src/core/files.dart' show AppFiles;
export 'package:dartway_example_server/src/core/push.dart' show AppPush;
export 'package:dartway_example_server/src/profile/profile_access.dart'
    show ProfileAccess;
export 'package:dartway_example_server/src/migrations/migrations.dart'
    show appMigrations;

/// The club's server, as `bin/server.dart` and the tests build it.
///
/// The one file that sees every feature: it lists them, hands the sign-in
/// hooks to the server and every upload purpose's rule to the storage.
abstract final class DartwayExampleServer {
  /// Builds the example server. `bin/server.dart` starts it; tests start it on a
  /// free port against their own database.
  ///
  /// With [storage] the server takes uploads by [uploadRules] — public
  /// purposes into its public bucket, private ones into its private bucket —
  /// and checks both buckets as it starts; without it, it has no files.
  ///
  /// [push] sends notifications (`AppPush.module`); by default it has no providers
  /// and records deliveries it has nobody to send through.
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
    DwPushModule? push,
    DwServerClock clock = DwServerClock.system,
  }) => DwAppServer(
    protocol: appProtocol,
    schema: dartwayExampleSchema,
    migrations: appMigrations,
    migrationsDirectory: 'lib/src/migrations',
    database: database,
    auth: auth ?? AccountAuth.config,
    features: [
      profileFeature,
      scheduleFeature,
      bookingsFeature,
      contentFeature,
      chatFeature,
      adminFeature,
      accountFeature(adminIdentifier: adminIdentifier),
    ],
    files: storage == null
        ? null
        : DwFileStorage(storage, rules: uploadRules, canRead: canReadFile),
    modules: [
      push ?? AppPush.module(eligibility: ProfileAccess.pushEligibility),
      // The admin panel's dashboards: admins read and edit, staff and
      // members do not.
      DwAnalyticsModule(readAccess: ProfileAccess.admin),
    ],
    port: port,
    settings: settings,
    clock: clock,
  );

  /// One rule per [DartwayExampleUpload], each declared by the feature the
  /// purpose belongs to. Adding a purpose is adding its rule there and
  /// listing it here — the buckets, the keys and the startup check follow.
  static List<DwUploadRule> get uploadRules => [
    ProfileAccess.avatarUpload,
    ChatAttachments.rule,
  ];

  /// Who may read a private file through `DwGetFileLink`: the purpose's own
  /// answer — each feature answers for its files and says `null` for any
  /// other — and otherwise only its uploader. Public files are never asked.
  static Future<bool> canReadFile(DwCallContext ctx, DwFileRecord file) async =>
      await ChatAttachments.canRead(ctx, file) ??
      file.accountId == ctx.accountId;
}
