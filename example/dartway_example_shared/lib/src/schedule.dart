import 'package:dartway_core/dartway_core.dart';

import 'example_channel.dart';
import 'people.dart';

part 'schedule.dw.dart';

/// A service the club offers: a class type or a personal appointment.
final class ClubServiceView extends DwDataObject with _$ClubServiceView {
  const ClubServiceView({
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
final class ClubSessionView extends DwDataObject with _$ClubSessionView {
  const ClubSessionView({
    required this.id,
    required this.service,
    required this.startsAt,
    required this.capacity,
    required this.bookedCount,
    this.coach,
  });

  @override
  final int id;
  final ClubServiceView service;
  final PersonView? coach;
  final DateTime startsAt;

  /// 1 = a personal appointment, N = a group class.
  final int capacity;
  final int bookedCount;

  int get spotsLeft => capacity - bookedCount;
}

/// The service catalogue.
final class ListClubServices extends DwListRequest<ClubServiceView>
    with _$ListClubServices {
  const ListClubServices();

  @override
  List<DwChannel> get channels => const [DwChannel(ExampleChannel.schedule)];
}

/// Sessions starting at or after [from], soonest first.
final class ListUpcomingSessions extends DwListRequest<ClubSessionView>
    with _$ListUpcomingSessions {
  const ListUpcomingSessions({required this.from});

  final DateTime from;

  @override
  List<DwChannel> get channels => const [DwChannel(ExampleChannel.schedule)];

  @override
  bool matches(ClubSessionView object) => !object.startsAt.isBefore(from);

  @override
  int Function(ClubSessionView a, ClubSessionView b) get sort =>
      (a, b) => a.startsAt.compareTo(b.startsAt);
}

/// Creates or edits a service. Admin only.
final class SaveClubService extends DwCommand<ClubServiceView>
    with _$SaveClubService {
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
}

/// Schedules a session. Staff only.
final class ScheduleSession extends DwCommand<ClubSessionView>
    with _$ScheduleSession {
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
}

/// Removes a session and its bookings. Staff only.
final class CancelSession extends DwCommand<void> with _$CancelSession {
  const CancelSession({required this.sessionId});

  final int sessionId;
}
