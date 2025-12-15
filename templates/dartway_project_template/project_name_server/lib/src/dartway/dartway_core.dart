import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:project_name_server/src/crud/feed_post_crud_config.dart';
import 'package:project_name_server/src/crud/user_profile_crud_config.dart';
import 'package:project_name_server/src/crud/water_intake_crud_config.dart';
import 'package:project_name_server/src/generated/protocol.dart';
import 'package:serverpod/serverpod.dart';

late final DwCore<UserProfile> dw;

initDartwayCore(Serverpod serverpod) {
  dw = DwCore.init<UserProfile>(
    userProfileTable: UserProfile.t,
    crudConfigurations: [
      userProfileCrudConfig,
      feedPostCrudConfig,
      waterIntakeCrudConfig
    ],
    userProfileConstructor: ({
      required int userInfoId,
      required DwAuthDataStash dwDataStash,
    }) async =>
        UserProfile(
      userInfoId: userInfoId,
      phone: dwDataStash.identifier,
      firstName: dwDataStash.data['firstName'] ?? '',
      conditionsAcceptedAt: DateTime.now(),
      agreedForMarketingCommunications: bool.tryParse(
              dwDataStash.data['agreedForMarketingCommunications'] ?? '') ??
          false,
    ),
  );

  DwPhoneAuthConfig.set(DwPhoneAuthConfig.defaultDevelopmentConfig);
}
