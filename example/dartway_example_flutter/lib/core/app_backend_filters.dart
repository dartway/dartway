import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';

enum AppBackendFilters<T> with DwBackendFiltersMixin<T> {
  userId<int>(),
  userProfileId<int>(),
  createdAt<DateTime>(),
  intakeTime<DateTime>();

  // toUserId<int>(),
  // isRead<bool>(),

  static DwBackendFilter userWaterIntake(int userId) => DwBackendFilter.and(
        [
          AppBackendFilters.userProfileId.equals(userId),
          AppBackendFilters.intakeTime.greaterThan(
            DateTime.now().trimTime,
          ),
        ],
      );
}

extension on DateTime {
  DateTime get trimTime => DateTime(year, month, day);
}
