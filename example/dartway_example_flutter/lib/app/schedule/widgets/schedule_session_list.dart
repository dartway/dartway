import 'package:dartway_example_flutter/app/schedule/logic/today_provider.dart';
import 'package:dartway_example_flutter/app/schedule/widgets/session_card.dart';
import 'package:dartway_example_flutter/core/app_l10n.dart';
import 'package:dartway_example_flutter/core/dw_core.dart';
import 'package:dartway_example_flutter/shared/placeholder_objects.dart';
import 'package:dartway_example_flutter/ui_kit/ui_kit.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Upcoming sessions grouped by day, each card knowing whether you hold a
/// place on it. Both reads are live: a place someone else takes changes the
/// spots left on every screen, and your own booking or cancellation flips the
/// card — with no refresh code here.
class ScheduleSessionList extends ConsumerWidget {
  const ScheduleSessionList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Two reads, one nested in the other: the list waits for both, and each
    // fails, retries and follows the server on its own.
    return DwReadBuilder(
      dw.request(ListUpcomingSessions(from: ref.watch(todayProvider))),
      placeholder: PlaceholderObjects.listOf(PlaceholderObjects.session, 5),
      builder: (context, sessions) => DwReadBuilder(
        dw.request(const ListMyBookings()),
        placeholder: const <SessionBooking>[],
        builder: (context, mine) =>
            _ScheduleDays(sessions: sessions, mine: mine),
      ),
    );
  }
}

class _ScheduleDays extends StatelessWidget {
  const _ScheduleDays({required this.sessions, required this.mine});

  final List<ClubSession> sessions;
  final List<SessionBooking> mine;

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return Center(child: AppText.body(context.l10n.noUpcomingSessions));
    }

    // A cancelled booking stays in the list with its status; only an
    // active one holds a place.
    final activeBySession = {
      for (final booking in mine)
        if (booking.status == BookingStatus.booked) booking.session.id: booking,
    };

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        for (final (index, session) in sessions.indexed) ...[
          if (index == 0 ||
              !session.startsAt.isSameDayAs(sessions[index - 1].startsAt))
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
  }
}
