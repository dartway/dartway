import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';

enum AppBackendFilters<T> with DwBackendFiltersMixin<T> {
  clientProfileId<int>(),
  channelId<int>(),
  startsAt<DateTime>();

  /// Bookings of one client. The server access filter enforces the same rule —
  /// this only narrows the query.
  static DwBackendFilter clientBookings(int userProfileId) =>
      AppBackendFilters.clientProfileId.equals(userProfileId);

  /// Messages of one chat channel.
  static DwBackendFilter channelMessages(int channelId) =>
      AppBackendFilters.channelId.equals(channelId);

  /// Schedule from the start of today onwards.
  static DwBackendFilter upcomingSessions() =>
      AppBackendFilters.startsAt.greaterThan(DateTime.now().dayStart);
}

extension on DateTime {
  DateTime get dayStart => DateTime(year, month, day);
}
