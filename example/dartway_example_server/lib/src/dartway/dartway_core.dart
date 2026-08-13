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

/// Everything between "something happened" and a queued message: who is
/// eligible, how long the message is worth delivering, how the audience is
/// chunked. Null exactly when [dwPush] is.
DwPushDispatcher? dwPushDispatcher;

/// Categories this app sends, and what each is worth after a while.
abstract final class ExamplePushCategories {
  static const newsPost = 'news_post';
  static const bookingReminder = 'booking_reminder';
}

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

  // Built before the core, because the token registration action below is one
  // of its configs: a device registers through the app's ordinary CRUD
  // endpoint, and the module ships the config rather than a route of its own.
  dwPush = _buildDwPush(passwords);
  dwPushDispatcher = dwPush == null
      ? null
      : DwPushDispatcher(
          push: dwPush!,
          // A club announcement is stale tomorrow; a booking reminder is stale
          // in an hour. Anything not listed keeps the default day.
          categoryLifetimes: const {
            ExamplePushCategories.bookingReminder: Duration(hours: 2),
          },
          audienceFilter: _pushAudienceFilter,
        );

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
    // The device token registration action, shipped by the push module and
    // declared here — nothing of the module's is reachable until an app says
    // so. The recipient comes from the session, never from the request.
    dtoConfigurations: [
      if (dwPush != null)
        dwPush!.tokenRegistrationConfig(
          canRegister: (session, recipientId) async {
            final profile = await UserProfile.db.findById(session, recipientId);
            return profile != null;
          },
        ),
    ],
    // Empty on purpose, and not because channels are unused: this app listens
    // to `DwCoreConst.publicUpdatesChannel` and to the signed-in user's own
    // channel, and the framework declares both. An app channel of its own —
    // per chat, per team, per order — is declared here, or the server refuses
    // the subscription.
    channelConfigurations: [],
    userProfileConstructor: _buildUserProfile,
    dwAlerts: DwAlerts.init(),
    // Uploads are optional: configured when this run mode carries the
    // dwCloudStorage* keys (development points them at the `minio` service in
    // docker-compose), and simply absent when it does not.
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
      // The module's own token store, plus the one question it cannot answer:
      // may this person be sent this. Everything else — reading the tokens,
      // canonicalizing them, dropping the ones a provider rejected — is the
      // same in every app and lives in the resolver.
      recipientResolver: const DwDevicePushTokenResolver(
        isEligible: _isEligibleForPush,
      ),
      // Each device is sent through the transport that issued its token, which
      // the app reports at registration. A token from an older build carries no
      // provider yet and is probed once, in this order.
      transport: DwPushProviderTransport.routed(
        providers: {
          DwPushProviders.fcm: ?fcm,
          DwPushProviders.ruStore: ?ruStore,
        },
      ),
    ),
  );
}

/// Consent, checked at the moment of sending — the world may have changed since
/// the message was queued, and a marketing blast queued yesterday must not
/// reach somebody who withdrew their consent this morning.
Future<bool> _isEligibleForPush(
  Session session, {
  required int recipientId,
  required DwPushPayload payload,
  required Transaction transaction,
}) async {
  final profile = await UserProfile.db.findById(
    session,
    recipientId,
    transaction: transaction,
  );
  if (profile == null) return false;
  return payload.category != ExamplePushCategories.newsPost ||
      profile.agreedForMarketingCommunications;
}

/// The same rule in bulk, before anything is queued. An optimisation, not a
/// guarantee: the resolver asks again per recipient when the send happens.
Future<Set<int>> _pushAudienceFilter(
  Session session, {
  required Set<int> recipientIds,
  required String category,
  required Transaction transaction,
}) async {
  if (category != ExamplePushCategories.newsPost) return recipientIds;
  final profiles = await UserProfile.db.find(
    session,
    where: (table) => table.id.inSet(recipientIds),
    transaction: transaction,
  );
  return profiles
      .where((profile) => profile.agreedForMarketingCommunications)
      .map((profile) => profile.id)
      .whereType<int>()
      .toSet();
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
