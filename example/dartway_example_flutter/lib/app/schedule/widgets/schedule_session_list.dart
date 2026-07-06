import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:dartway_example_client/dartway_example_client.dart';
import 'package:dartway_example_flutter/app/schedule/widgets/session_card.dart';
import 'package:dartway_example_flutter/core/app_backend_filters.dart';
import 'package:dartway_example_flutter/core/user_profile_provider.dart';
import 'package:dartway_example_flutter/ui_kit/ui_kit.dart';

/// Upcoming sessions grouped by day. Both lists are live: a booking made on
/// another device updates the cards without any refresh code.
class ScheduleSessionList extends ConsumerWidget {
  const ScheduleSessionList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myBookings = ref
            .watchModelList<SessionBooking>(
              backendFilter: AppBackendFilters.clientBookings(
                ref.watchUserProfile.id!,
              ),
            )
            .value ??
        [];

    return ref
        .watchModelList<ClubSession>(
          backendFilter: AppBackendFilters.upcomingSessions(),
        )
        .dwBuildListAsync(
          loadingItemsCount: 5,
          childBuilder: (sessions) {
            if (sessions.isEmpty) {
              return Center(
                child: AppText.body('No upcoming sessions yet'),
              );
            }

            return ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: _groupedByDay(sessions, myBookings),
            );
          },
        );
  }

  List<Widget> _groupedByDay(
    List<ClubSession> sessions,
    List<SessionBooking> myBookings,
  ) {
    final items = <Widget>[];
    DateTime? shownDay;

    for (final session in sessions) {
      if (shownDay == null || !session.startsAt.isSameDayAs(shownDay)) {
        shownDay = session.startsAt;
        items.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
            child: AppText.caption(session.startsAt.dayLabel),
          ),
        );
      }
      items.add(
        SessionCard(
          session: session,
          activeBooking: _activeBookingFor(session, myBookings),
        ),
      );
    }
    return items;
  }

  SessionBooking? _activeBookingFor(
    ClubSession session,
    List<SessionBooking> myBookings,
  ) {
    for (final booking in myBookings) {
      if (booking.clubSessionId == session.id &&
          booking.status == BookingStatus.booked) {
        return booking;
      }
    }
    return null;
  }
}
