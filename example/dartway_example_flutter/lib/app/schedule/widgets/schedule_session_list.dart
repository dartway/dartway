import 'package:dartway_example_flutter/app/schedule/logic/today_provider.dart';
import 'package:dartway_example_flutter/app/schedule/widgets/session_card.dart';
import 'package:dartway_example_flutter/core/app_l10n.dart';
import 'package:dartway_example_flutter/core/dw_core.dart';
import 'package:dartway_example_flutter/shared/placeholder_objects.dart';
import 'package:dartway_example_flutter/ui_kit/ui_kit.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

typedef _Schedule = ({List<ClubSession> sessions, List<SessionBooking> mine});

/// Upcoming sessions grouped by day, each card knowing whether you hold a
/// place on it. Both reads are live: a place someone else takes changes the
/// spots left on every screen, and your own booking or cancellation flips the
/// card — with no refresh code here.
class ScheduleSessionList extends ConsumerWidget {
  const ScheduleSessionList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsRequest = ListUpcomingSessions(
      from: ref.watch(todayProvider),
    );
    const bookingsRequest = ListMyBookings();
    final sessions = ref.watch(dw.request(sessionsRequest));
    final bookings = ref.watch(dw.request(bookingsRequest));

    final AsyncValue<_Schedule> schedule = switch ((sessions, bookings)) {
      (AsyncError(:final error, :final stackTrace), _) ||
      (
        _,
        AsyncError(:final error, :final stackTrace),
      ) => AsyncError(error, stackTrace),
      (AsyncData(value: final sessions), AsyncData(value: final mine)) =>
        AsyncData((sessions: sessions, mine: mine)),
      _ => const AsyncLoading(),
    };

    return schedule.section(
      loadingValue: (
        sessions: PlaceholderObjects.listOf(PlaceholderObjects.session, 5),
        mine: const [],
      ),
      onRetry: () => Future.wait([
        if (sessions.hasError)
          ref.read(dw.request(sessionsRequest).notifier).refetch(),
        if (bookings.hasError)
          ref.read(dw.request(bookingsRequest).notifier).refetch(),
      ]),
      builder: (schedule) {
        if (schedule.sessions.isEmpty) {
          return Center(child: AppText.body(context.l10n.noUpcomingSessions));
        }

        // A cancelled booking stays in the list with its status; only an
        // active one holds a place.
        final activeBySession = {
          for (final booking in schedule.mine)
            if (booking.status == BookingStatus.booked)
              booking.session.id: booking,
        };

        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            for (final (index, session) in schedule.sessions.indexed) ...[
              if (index == 0 ||
                  !session.startsAt.isSameDayAs(
                    schedule.sessions[index - 1].startsAt,
                  ))
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
                  child: AppText.caption(session.startsAt.dayLabel),
                ),
              SessionCard(
                session: session,
                activeBooking: activeBySession[session.id],
              ),
            ],
          ],
        );
      },
    );
  }
}
