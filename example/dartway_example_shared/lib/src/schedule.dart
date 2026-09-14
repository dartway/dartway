import 'package:dartway_core_shared/dartway_core_shared.dart';

import 'example_channel.dart';
import 'example_refusal.dart';
import 'people.dart';

part 'schedule.dw.dart';

/// A service the club offers: a class type or a personal appointment.
final class ClubService extends DwDataObject with _$ClubService {
  const ClubService({
    required this.id,
    required this.title,
    required this.description,
    required this.durationMinutes,
    required this.price,
    this.imageUrl,
  });

  @override
  final int id;
  final String title;
  final String description;
  final int durationMinutes;
  final int price;
  final String? imageUrl;
}

/// One scheduled occurrence of a service.
///
/// The same object is published to everyone on the schedule, so it carries
/// nothing personal: whether *you* booked it lives in your bookings.
final class ClubSession extends DwDataObject with _$ClubSession {
  const ClubSession({
    required this.id,
    required this.service,
    required this.startsAt,
    required this.capacity,
    required this.bookedCount,
    this.coach,
  });

  @override
  final int id;
  final ClubService service;
  final PersonCard? coach;
  final DateTime startsAt;

  /// 1 = a personal appointment, N = a group class.
  final int capacity;
  final int bookedCount;

  int get spotsLeft => capacity - bookedCount;
}

/// The service catalogue, alphabetically; a service added live goes on top.
final class ListClubServices extends DwListRequest<ClubService>
    with _$ListClubServices {
  const ListClubServices();

  @override
  List<DwLiveChannel> get channels => const [
    DwLiveChannel(ExampleChannel.schedule),
  ];
}

/// Sessions starting at or after [from], soonest first.
final class ListUpcomingSessions extends DwListRequest<ClubSession>
    with _$ListUpcomingSessions {
  const ListUpcomingSessions({required this.from});

  final DateTime from;

  @override
  List<DwLiveChannel> get channels => const [
    DwLiveChannel(ExampleChannel.schedule),
  ];

  @override
  bool matches(ClubSession item) => !item.startsAt.isBefore(from);

  @override
  int Function(ClubSession a, ClubSession b) get sort =>
      (a, b) => a.startsAt.compareTo(b.startsAt);
}

/// Creates or edits a service. Admins only.
final class SaveClubService extends DwActionCommand<ClubService>
    with _$SaveClubService
    implements DwSelfValidating {
  const SaveClubService({
    this.id,
    required this.title,
    required this.description,
    required this.durationMinutes,
    required this.price,
    this.imageUrl,
  });

  /// `null` creates.
  final int? id;
  final String title;
  final String description;
  final int durationMinutes;
  final int price;
  final String? imageUrl;

  @override
  List<DwCallRefusal> validate() => [
    if (title.trim().isEmpty)
      DwCallRefusal(ExampleRefusal.titleRequired, field: 'title'),
    if (durationMinutes <= 0)
      DwCallRefusal(
        ExampleRefusal.durationNotPositive,
        field: 'durationMinutes',
      ),
    if (price < 0) DwCallRefusal(ExampleRefusal.priceNegative, field: 'price'),
  ];
}

/// Schedules a session. Staff only.
final class ScheduleSession extends DwActionCommand<ClubSession>
    with _$ScheduleSession
    implements DwSelfValidating {
  const ScheduleSession({
    required this.serviceId,
    required this.startsAt,
    required this.capacity,
    this.coachProfileId,
  });

  final int serviceId;
  final int? coachProfileId;
  final DateTime startsAt;
  final int capacity;

  /// Whether [startsAt] is in the past depends on the clock, so the server
  /// checks it; this checks only what the fields alone decide.
  @override
  List<DwCallRefusal> validate() => [
    if (capacity < 1)
      DwCallRefusal(ExampleRefusal.capacityTooSmall, field: 'capacity'),
  ];
}

/// Removes a session and its bookings. Staff only.
final class CancelSession extends DwActionCommand<void> with _$CancelSession {
  const CancelSession({required this.sessionId});

  final int sessionId;
}
