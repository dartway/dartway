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

late final DwCore<UserProfile> dw;

/// Fixed dev OTP. The showcase user switcher relies on it — keep in sync with
/// showcaseDevOtpCode in dartway_example_flutter (lib/showcase/logic/).
const _devVerificationCode = '000000';

String _randomVerificationCode() =>
    List.generate(6, (_) => Random.secure().nextInt(10)).join();

void initDartwayCore(Serverpod serverpod) {
  final isDevelopmentRun = serverpod.runMode == 'development';

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
      passwords: serverpod.server.passwords,
      // Dev: fixed code so the showcase shell can sign in programmatically.
      // Production keeps random 6-digit codes (framework default behavior).
      generateVerificationCodeMethod: (
        session, {
        required DwAuthRequest verificationRequest,
      }) async =>
          isDevelopmentRun ? _devVerificationCode : _randomVerificationCode(),
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
