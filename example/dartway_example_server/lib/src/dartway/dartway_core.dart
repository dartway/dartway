import 'dart:math';

import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:dartway_example_server/src/crud/app_setting_crud_config.dart';
import 'package:dartway_example_server/src/crud/chat_channel_crud_config.dart';
import 'package:dartway_example_server/src/crud/chat_message_crud_config.dart';
import 'package:dartway_example_server/src/crud/club_service_crud_config.dart';
import 'package:dartway_example_server/src/crud/club_session_crud_config.dart';
import 'package:dartway_example_server/src/crud/news_post_crud_config.dart';
import 'package:dartway_example_server/src/crud/session_booking_crud_config.dart';
import 'package:dartway_example_server/src/crud/session_review_crud_config.dart';
import 'package:dartway_example_server/src/crud/user_profile_crud_config.dart';
import 'package:dartway_example_server/src/generated/protocol.dart';
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
    crudConfigurations: [
      userProfileCrudConfig,
      clubServiceCrudConfig,
      clubSessionCrudConfig,
      sessionBookingCrudConfig,
      sessionReviewCrudConfig,
      chatChannelCrudConfig,
      chatMessageCrudConfig,
      newsPostCrudConfig,
      appSettingCrudConfig,
    ],
    dtoConfigurations: [],
    userProfileConstructor: _buildUserProfile,
    dwAlerts: DwAlerts.init(),
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
/// New users always start as [UserRole.client]; staff and admin roles are
/// assigned by the admin (see the role guard in the UserProfile CRUD config).
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
