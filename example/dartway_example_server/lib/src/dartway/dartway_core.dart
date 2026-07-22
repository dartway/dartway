import 'dart:math';

import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:dartway_push_server/dartway_push_server.dart';
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

/// The optional push delivery engine, owned by the app (not by [DwCore]).
///
/// Push is a separate Serverpod module (`dartway_push_server`): an app that
/// needs it constructs its own [DwPush] and schedules the worker itself. Stays
/// `null` when no push provider is configured.
DwPush? dwPush;

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

  // Push lives in a separate module, not in DwCore: the app owns the engine and
  // schedules its worker. Stays null without provider credentials. Authorising
  // who may send marketing or pause the worker is the app's job — it owns the
  // endpoints; the module ships no gating.
  dwPush = _buildDwPush(passwords);
}

/// Builds the optional push delivery engine from provider credentials.
///
/// Returns `null` — no engine, no worker — when the example has no FCM or
/// RuStore credentials, which is the default. Because push is a separate module,
/// an app that omits the dependency gets none of the `dw_push_*` tables at all.
DwPush? _buildDwPush(Map<String, String> passwords) {
  final fcmConfig = DwFcmPushProviderConfig.fromPasswords(passwords);
  final ruStoreConfig = DwRuStorePushProviderConfig.fromPasswords(passwords);
  final fcm = fcmConfig.isConfigured ? DwFcmPushProvider(config: fcmConfig) : null;
  final ruStore = ruStoreConfig.isConfigured
      ? DwRuStorePushProvider(config: ruStoreConfig)
      : null;
  if (fcm == null && ruStore == null) return null;

  return DwPush(
    config: DwPushConfig(
      recipientResolver: const _ExamplePushRecipientResolver(),
      transport: DwPushProviderTransport(
        provider: fcm ?? ruStore!,
        fallbackProvider: fcm == null ? null : ruStore,
      ),
    ),
  );
}

/// Minimal resolver that shows the seam. A real app looks up active app-owned
/// device tokens and per-recipient preferences here and returns only the
/// targets that are eligible to receive [payload].
final class _ExamplePushRecipientResolver extends DwPushRecipientResolver {
  const _ExamplePushRecipientResolver();

  @override
  Future<DwPushRecipient> resolve(
    Session session, {
    required int recipientId,
    required DwPushPayload payload,
    required Transaction transaction,
  }) async {
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
