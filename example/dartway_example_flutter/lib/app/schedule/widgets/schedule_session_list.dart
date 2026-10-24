import 'package:dartway_example_flutter/app/schedule/logic/schedule_snapshot.dart';
import 'package:dartway_example_flutter/app/schedule/widgets/session_card.dart';
import 'package:dartway_example_flutter/core/app_l10n.dart';
import 'package:dartway_example_flutter/shared/placeholder_objects.dart';
import 'package:dartway_example_flutter/ui_kit/ui_kit.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';
import 'package:flutter/material.dart';

/// Upcoming sessions grouped by day, each card knowing whether you hold a
/// place on it. Both reads are live: a place someone else takes changes the
/// spots left on every screen, and your own booking or cancellation flips the
/// card — with no refresh code here.
class ScheduleSessionList extends StatelessWidget {
  const ScheduleSessionList({super.key});

  @override
  Widget build(BuildContext context) {
    return DwReadBuilder.derived(
      scheduleSnapshotProvider,
      retry: refetchSchedule,
      placeholder: (
        sessions: PlaceholderObjects.listOf(PlaceholderObjects.session, 5),
        mine: const <SessionBooking>[],
      ),
      builder: (context, snapshot) =>
          _ScheduleDays(sessions: snapshot.sessions, mine: snapshot.mine),
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
      padding: const EdgeInsets.symmetric(vertical: AppSpace.s8),
      children: [
        for (final (index, session) in sessions.indexed) ...[
          if (index == 0 ||
              !session.startsAt.isSameDayAs(sessions[index - 1].startsAt))
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.s4,
                AppSpace.s16,
                AppSpace.s4,
                AppSpace.s8,
              ),
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
