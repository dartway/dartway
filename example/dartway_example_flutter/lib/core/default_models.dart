import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
import 'package:dartway_example_client/dartway_example_client.dart';

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
      defaultModel: ClubService(
        id: DwRepository.mockModelId,
        title: 'Group workout',
        description: 'One hour group workout',
        durationMinutes: 60,
        price: 1000,
      ),
    );

    DwRepository.setupRepository(
      defaultModel: ClubSession(
        id: DwRepository.mockModelId,
        serviceId: DwRepository.mockModelId,
        coachProfileId: DwRepository.mockModelId,
        startsAt: DateTime.now(),
        capacity: 10,
      ),
    );

    DwRepository.setupRepository(
      defaultModel: SessionBooking(
        id: DwRepository.mockModelId,
        sessionId: DwRepository.mockModelId,
        clientProfileId: DwRepository.mockModelId,
        status: BookingStatus.booked,
        createdAt: DateTime.now(),
      ),
    );

    DwRepository.setupRepository(
      defaultModel: SessionReview(
        id: DwRepository.mockModelId,
        bookingId: DwRepository.mockModelId,
        rating: 5,
        createdAt: DateTime.now(),
      ),
    );

    DwRepository.setupRepository(
      defaultModel: ChatChannel(
        id: DwRepository.mockModelId,
        title: 'General',
        createdAt: DateTime.now(),
      ),
    );

    DwRepository.setupRepository(
      defaultModel: ChatMessage(
        id: DwRepository.mockModelId,
        channelId: DwRepository.mockModelId,
        authorProfileId: DwRepository.mockModelId,
        messageText: 'Message',
        createdAt: DateTime.now(),
      ),
    );

    DwRepository.setupRepository(
      defaultModel: NewsPost(
        id: DwRepository.mockModelId,
        title: 'News',
        text: 'News content',
        createdAt: DateTime.now(),
        authorProfileId: DwRepository.mockModelId,
      ),
    );

    DwRepository.setupRepository(
      defaultModel: AppSetting(
        id: DwRepository.mockModelId,
        settingKey: 'clubName',
        settingValue: 'DartWay Fitness',
      ),
    );
  }
}
