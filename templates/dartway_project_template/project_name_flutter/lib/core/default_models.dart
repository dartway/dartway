import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
import 'package:project_name_client/project_name_client.dart';

class DefaultModels {
  static initRepository() {
    DwRepository.setupRepository(
      defaultModel: UserProfile(
        id: DwRepository.mockModelId,
        userInfoId: DwRepository.mockModelId,
        firstName: 'Dartway',
        phone: '79999999999',
        agreedForMarketingCommunications: true,
        conditionsAcceptedAt: DateTime.now(),
      ),
    );

    DwRepository.setupRepository(
      defaultModel: FeedPost(
        id: DwRepository.mockModelId,
        title: 'Feed Post',
        text: 'Feed Post Content',
        createdAt: DateTime.now(),
        authorProfileId: DwRepository.mockModelId,
      ),
    );

    DwRepository.setupRepository(
      defaultModel: WaterIntake(
        id: DwRepository.mockModelId,
        userProfileId: DwRepository.mockModelId,
        intakeAmount: 1000,
        intakeTime: DateTime.now(),
      ),
    );
  }
}
