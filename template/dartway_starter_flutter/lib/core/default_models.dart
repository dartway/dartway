// The one place a model is legitimately built field by field with an id in
// hand. There is no row here and nothing to copy from: `mockModelId` is a
// synthetic constant, and the instance is invented from nothing to give the
// skeleton a shape. `model_rebuild_by_constructor` reads the sentinel and stays
// silent by itself — no `ignore_for_file` to carry. Every other id passed to a
// model constructor in your app is the rule's case, not this one.

import 'package:dartway_starter_flutter/core/dw_core.dart';
import 'package:dartway_starter_client/dartway_starter_client.dart';

/// Default (mock) instances the repository renders skeleton loading states
/// from: the shape of a real model, filled with placeholder values.
///
/// Register one per model you add — the skeleton is derived from your real
/// widget built against this instance, which is why it looks like the content
/// that is about to arrive instead of a generic shimmer.
class DefaultModels {
  static void initRepository() {
    dw.repo.setupRepository(
      defaultModel: UserProfile(
        id: dw.repo.mockModelId,
        userIdentifier: '79999999999',
        firstName: 'Dartway',
        phone: '79999999999',
        agreedForMarketingCommunications: true,
        conditionsAcceptedAt: DateTime.now(),
      ),
    );

    dw.repo.setupRepository(
      defaultModel: AppSetting(
        id: dw.repo.mockModelId,
        settingKey: 'appName',
        settingValue: 'DartWay Starter',
      ),
    );
  }
}
