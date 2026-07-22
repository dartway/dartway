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

String _randomVerificationCode() =>
    List.generate(6, (_) => Random.secure().nextInt(10)).join();

void initDartwayCore(Serverpod serverpod) {
  final pushConfig = _buildPushConfig(serverpod.server.passwords);
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
      // Test/reviewer accounts carry a fixed, admin-rotated code
      // (UserProfile.testVerificationCode, serverOnly — never sent to clients);
      // everyone else gets a fresh random code. Works in any run mode, so store
      // reviewers can sign in, while real users are never handed a fixed code.
      generateVerificationCodeMethod:
          (session, {required DwAuthRequest verificationRequest}) async {
            final profile = await UserProfile.db.findFirstRow(
              session,
              where: (t) =>
                  t.userIdentifier.equals(verificationRequest.userIdentifier),
            );
            return profile?.testVerificationCode ?? _randomVerificationCode();
          },
      // Dev: log the code to the server console instead of sending an SMS.
      // Wire a real SMS/email sender here for production.
      sendVerificationCodeMethod:
          (
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
    // Push stays disabled when the example has no provider credentials. A real
    // application keeps tokens and eligibility rules in its resolver, while
    // DartWay owns the provider transport implementation.
    pushConfig: pushConfig,
  );
}

DwPushConfig? _buildPushConfig(Map<String, String> passwords) {
  final fcmConfig = DwFcmPushProviderConfig.fromPasswords(passwords);
  final ruStoreConfig = DwRuStorePushProviderConfig.fromPasswords(passwords);
  final fcm = fcmConfig.isConfigured
      ? DwFcmPushProvider(config: fcmConfig)
      : null;
  final ruStore = ruStoreConfig.isConfigured
      ? DwRuStorePushProvider(config: ruStoreConfig)
      : null;
  if (fcm == null && ruStore == null) return null;

  return DwPushConfig(
    recipientResolver: const _ExamplePushRecipientResolver(),
    transport: DwPushProviderTransport(
      provider: fcm ?? ruStore!,
      fallbackProvider: fcm == null ? null : ruStore,
    ),
  );
}

final class _ExamplePushRecipientResolver extends DwPushRecipientResolver {
  const _ExamplePushRecipientResolver();

  @override
  Future<DwPushRecipient> resolve(
    Session session, {
    required int recipientId,
    required DwPushPayload payload,
    required Transaction transaction,
  }) async {
    // Replace with a lookup of active app-owned device tokens and preferences.
    return DwPushRecipient(const []);
  }
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
