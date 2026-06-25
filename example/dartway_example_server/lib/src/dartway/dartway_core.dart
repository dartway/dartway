import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:dartway_example_server/src/crud/feed_post_crud_config.dart';
import 'package:dartway_example_server/src/crud/user_profile_crud_config.dart';
import 'package:dartway_example_server/src/crud/water_intake_crud_config.dart';
import 'package:dartway_example_server/src/generated/protocol.dart';
import 'package:serverpod/serverpod.dart';

late final DwCore<UserProfile> dw;

void initDartwayCore(Serverpod serverpod) {
  dw = DwCore.init<UserProfile>(
    userProfileTable: UserProfile.t,
    userProfileInclude: UserProfile.include(),
    crudConfigurations: [
      userProfileCrudConfig,
      feedPostCrudConfig,
      waterIntakeCrudConfig,
    ],
    dtoConfigurations: [],
    userProfileConstructor: _buildUserProfile,
    dwAlerts: DwAlerts.init(),
    dwAuthConfig: DwAuthConfig(
      passwords: serverpod.server.passwords,
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
Future<UserProfile> _buildUserProfile(
  Session session, {
  required DwAuthRequest registrationRequest,
}) async {
  final extra = registrationRequest.extraData ?? const <String, String>{};

  return UserProfile(
    phone: registrationRequest.userIdentifier,
    firstName: extra['firstName'] ?? '',
    conditionsAcceptedAt: DateTime.now(),
    agreedForMarketingCommunications:
        bool.tryParse(extra['agreedForMarketingCommunications'] ?? '') ?? false,
  );
}
