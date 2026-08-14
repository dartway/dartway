// The one place a model is legitimately built field by field with an id in
// hand. `model_rebuild_by_constructor` reads an id as "this row already exists,
// rebuild it with copyWith", and here there is no row and nothing to copy from:
// `mockModelId` is a synthetic constant, and the instance is invented from
// nothing to give the skeleton a shape. Every other id passed to a model
// constructor in an app is the rule's case, not this one.
//
// ignore_for_file: model_rebuild_by_constructor

import 'package:dartway_example_flutter/core/app_settings/app_setting_key.dart';
import 'package:dartway_example_flutter/core/dw_core.dart';
import 'package:dartway_example_client/dartway_example_client.dart';

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
      defaultModel: ClubService(
        id: dw.repo.mockModelId,
        title: 'Group workout',
        description: 'One hour group workout',
        durationMinutes: 60,
        price: 1000,
      ),
    );

    dw.repo.setupRepository(
      defaultModel: ClubSession(
        id: dw.repo.mockModelId,
        serviceId: dw.repo.mockModelId,
        coachProfileId: dw.repo.mockModelId,
        startsAt: DateTime.now(),
        capacity: 10,
      ),
    );

    dw.repo.setupRepository(
      defaultModel: SessionBooking(
        id: dw.repo.mockModelId,
        clubSessionId: dw.repo.mockModelId,
        clientProfileId: dw.repo.mockModelId,
        status: BookingStatus.booked,
        createdAt: DateTime.now(),
      ),
    );

    dw.repo.setupRepository(
      defaultModel: SessionReview(
        id: dw.repo.mockModelId,
        bookingId: dw.repo.mockModelId,
        rating: 5,
        createdAt: DateTime.now(),
      ),
    );

    dw.repo.setupRepository(
      defaultModel: ChatChannel(
        id: dw.repo.mockModelId,
        title: 'General',
        createdAt: DateTime.now(),
      ),
    );

    dw.repo.setupRepository(
      defaultModel: ChatMessage(
        id: dw.repo.mockModelId,
        channelId: dw.repo.mockModelId,
        authorProfileId: dw.repo.mockModelId,
        messageText: 'Message',
        createdAt: DateTime.now(),
      ),
    );

    dw.repo.setupRepository(
      defaultModel: NewsPost(
        id: dw.repo.mockModelId,
        title: 'News',
        text: 'News content',
        createdAt: DateTime.now(),
        authorProfileId: dw.repo.mockModelId,
      ),
    );

    dw.repo.setupRepository(
      defaultModel: AppSetting(
        id: dw.repo.mockModelId,
        settingKey: AppSettingKey.clubName.key,
        settingValue: 'DartWay Fitness',
      ),
    );
  }
}
