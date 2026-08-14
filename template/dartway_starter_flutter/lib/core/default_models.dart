// The one place a model is legitimately built field by field with an id in
// hand. `model_rebuild_by_constructor` reads an id as "this row already exists,
// rebuild it with copyWith", and here there is no row and nothing to copy from:
// `mockModelId` is a synthetic constant, and the instance is invented from
// nothing to give the skeleton a shape. Every other id passed to a model
// constructor in your app is the rule's case, not this one.
//
// ignore_for_file: model_rebuild_by_constructor

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
