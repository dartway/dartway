import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
import 'package:dartway_starter_client/dartway_starter_client.dart';

/// Default (mock) instances the repository renders skeleton loading states
/// from: the shape of a real model, filled with placeholder values.
///
/// Register one per model you add — the skeleton is derived from your real
/// widget built against this instance, which is why it looks like the content
/// that is about to arrive instead of a generic shimmer.
class DefaultModels {
  static void initRepository() {
    DwRepository.setupRepository(
      defaultModel: UserProfile(
        id: DwRepository.mockModelId,
        userIdentifier: '79999999999',
        firstName: 'Dartway',
        phone: '79999999999',
        agreedForMarketingCommunications: true,
        conditionsAcceptedAt: DateTime.now(),
      ),
    );

    DwRepository.setupRepository(
      defaultModel: AppSetting(
        id: DwRepository.mockModelId,
        settingKey: 'appName',
        settingValue: 'DartWay Starter',
      ),
    );
  }
}
