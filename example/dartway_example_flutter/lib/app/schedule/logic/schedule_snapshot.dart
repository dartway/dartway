import 'package:dartway_example_flutter/app/schedule/logic/today_controller.dart';
import 'package:dartway_example_flutter/core/dw_core.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

typedef ScheduleSnapshot = ({
  List<ClubSession> sessions,
  List<SessionBooking> mine,
});

ListMySessionBookings _bookingsOf(List<ClubSession> sessions) =>
    ListMySessionBookings(
      sessionIds: [for (final session in sessions) session.id],
    );

/// Booking marks depend on real session ids, never on loading placeholders.
final scheduleSnapshotProvider =
    Provider.autoDispose<AsyncValue<ScheduleSnapshot>>((ref) {
      final sessions = ref.watch(
        dw.request(
          ListUpcomingSessions(from: ref.watch(todayControllerProvider)),
        ),
      );
      return switch (sessions) {
        AsyncData(:final value) =>
          ref
              .watch(dw.request(_bookingsOf(value)))
              .whenData((mine) => (sessions: value, mine: mine)),
        AsyncError(:final error, :final stackTrace) => AsyncError(
          error,
          stackTrace,
        ),
        _ => const AsyncLoading(),
      };
    });

Future<void> refetchSchedule(WidgetRef ref) async {
  final sessions = dw.request(
    ListUpcomingSessions(from: ref.read(todayControllerProvider)),
  );
  await ref.read(sessions.notifier).refetch();
  if (ref.read(sessions) case AsyncData(:final value)) {
    await ref.read(dw.request(_bookingsOf(value)).notifier).refetch();
  }
}
