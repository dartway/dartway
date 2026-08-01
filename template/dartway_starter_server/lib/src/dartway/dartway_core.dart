import 'dart:math';

import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:dartway_starter_server/src/crud/app_setting_crud_config.dart';
import 'package:dartway_starter_server/src/crud/user_profile_crud_config.dart';
import 'package:dartway_starter_server/src/generated/protocol.dart';
import 'package:serverpod/serverpod.dart';

late DwCore<UserProfile> dw;
bool _initialized = false;

String _randomVerificationCode() =>
    List.generate(6, (_) => Random.secure().nextInt(10)).join();

/// Boots DartWay for this app.
///
/// Takes the passwords map rather than the whole [Serverpod] — that is the only
/// thing the core needs from it, and passing it explicitly is what lets the
/// integration tests bring DartWay up without a running server (`withServerpod`
/// builds its own Serverpod and never calls `run`).
void initDartwayCore({
  required Map<String, String> passwords,
  // This app has no legacy passwords — it was born on DartWay. The seam is here
  // because an app migrating off another backend registers its old hash format
  // through it, and because the integration suite proves the upgrade with it.
  List<DwPasswordVerifier> legacyPasswordVerifiers = const [],
}) {
  // Tests call this from `setUpAll` in every group; booting once is enough.
  if (_initialized) return;
  _initialized = true;

  dw = DwCore.init<UserProfile>(
    userProfileTable: UserProfile.t,
    userProfileInclude: UserProfile.include(),
    // One entry per model the app exposes. A model with no config here is not
    // reachable at all — access is granted, never forgotten away.
    // Your domain models go below; see `example/` in the DartWay monorepo for a
    // full application built this way.
    crudConfigurations: [
      userProfileCrudConfig,
      appSettingCrudConfig,
    ],
    dtoConfigurations: [],
    // One entry per realtime channel the app names itself. A channel that is
    // not declared here cannot be subscribed to — a channel name arrives from
    // the client as a bare string, and this list is how the server tells a real
    // name from a guessed one. `DwCoreConst.publicUpdatesChannel`, which the
    // skeleton already listens to, is declared by the framework.
    //
    //   DwChannelConfig.public(prefix: 'catalogue'),
    //   DwChannelConfig.owner(prefix: 'orders'),   // orders42 -> user 42 only
    //   DwChannelConfig.guarded(
    //     prefix: 'team_',
    //     allowListen: (session, suffix) async => /* is caller in the team? */,
    //   ),
    channelConfigurations: [],
    userProfileConstructor: _buildUserProfile,
    dwAlerts: DwAlerts.init(),
    // Uploads are optional: configured when this run mode carries the
    // dwCloudStorage* keys (development points them at the `minio` service in
    // docker-compose), and simply absent when it does not — rather than a boot
    // that fails on a half-filled config.
    cloudStorageConfig:
        passwords.containsKey(DwConfigurationKeys.dwCloudStorageEndpoint)
        ? DwCloudStorageConfig.fromEnv(passwords)
        : null,
    dwAuthConfig: DwAuthConfig(
      passwords: passwords,
      legacyPasswordVerifiers: legacyPasswordVerifiers,
      // Test/reviewer accounts carry a fixed, admin-rotated code
      // (UserProfile.testVerificationCode, serverOnly — never sent to clients);
      // everyone else gets a fresh random code. Works in any run mode, so store
      // reviewers can sign in, while real users are never handed a fixed code.
      generateVerificationCodeMethod: (
        session, {
        required DwAuthRequest verificationRequest,
      }) async {
        final profile = await UserProfile.db.findFirstRow(
          session,
          where: (t) =>
              t.userIdentifier.equals(verificationRequest.userIdentifier),
        );
        return profile?.testVerificationCode ?? _randomVerificationCode();
      },
      // Dev: log the code to the server console instead of sending an SMS.
      // Wire a real SMS/email sender here for production.
      sendVerificationCodeMethod: (
        session, {
        required DwAuthRequest verificationRequest,
        required String verificationCode,
      }) async {
        session.log(
          'Verification code for ${verificationRequest.userIdentifier}: '
          '$verificationCode',
        );
      },
    ),
  );
}

/// Builds a new [UserProfile] when a user registers via the DartWay auth flow.
/// New users always start as [UserRole.user]; the admin role is assigned by an
/// admin (see the role guard in the UserProfile CRUD config).
Future<UserProfile> _buildUserProfile(
  Session session, {
  required DwAuthRequest registrationRequest,
}) async {
  final extra = registrationRequest.extraData ?? const <String, String>{};

  return UserProfile(
    userIdentifier: registrationRequest.userIdentifier,
    phone: registrationRequest.userIdentifier,
    firstName: extra['firstName'] ?? '',
    conditionsAcceptedAt: DateTime.now(),
    agreedForMarketingCommunications:
        bool.tryParse(extra['agreedForMarketingCommunications'] ?? '') ?? false,
  );
}
