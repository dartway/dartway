import 'package:dartway_example_flutter/core/dw_core.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:dartway_example_client/dartway_example_client.dart';
import 'package:dartway_example_flutter/app/schedule/widgets/session_card.dart';
import 'package:dartway_example_flutter/core/app_backend_filters.dart';
import 'package:dartway_example_flutter/core/app_l10n.dart';
import 'package:dartway_example_flutter/core/user_profile_provider.dart';
import 'package:dartway_example_flutter/ui_kit/ui_kit.dart';

/// Upcoming sessions grouped by day. Each list is live to *your own* writes:
/// book or cancel and the card updates with no refresh code. A change another
/// user makes shows on the next fetch — pushing it live to everyone needs a
/// named channel (`DwChannelSubscriptionWidget` + `postMessage`), which this
/// screen does not set up.
class ScheduleSessionList extends ConsumerWidget implements DwFeature {
  const ScheduleSessionList({super.key});

  @override
  DwFeatureSpec get dwFeature => const DwFeatureSpec(
    id: 'schedule/session-list',
    title: 'Realtime session list',
    purpose:
        'A club member sees what is on in the coming days and books a place '
        'without leaving the list.',
    behaviors: [
      'Upcoming sessions are grouped by day, nearest day first.',
      'Booking or cancelling updates the card without a manual refresh.',
      'A session at capacity is shown as full and cannot be booked.',
      'While the first page loads, five placeholder cards are shown.',
    ],
    requirements: [
      'Only sessions in the future are listed — the backend filter decides, '
          'not the widget.',
      'A member sees only their own bookings on the cards.',
    ],
    implementationNotes: [
      'ref.watch(dw.repo.modelList<ClubSession>()) with a backend filter: '
          'realtime sync, pagination and loading states come with it.',
      'Live to your own writes only. Another member booking the last seat '
          'shows on the next fetch — pushing it to everyone needs a named '
          'channel, which this screen deliberately does not set up.',
    ],
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myBookings =
        ref
            .watch(
              dw.repo.modelList<SessionBooking>(
                backendFilter: AppBackendFilters.clientBookings(
                  ref.watchUserProfile.id!,
                ),
              ),
            )
            .value ??
        [];

    return ref
        .watch(
          dw.repo.modelList<ClubSession>(
            backendFilter: AppBackendFilters.upcomingSessions(),
          ),
        )
        .dwBuildListAsync(
          loadingItemsCount: 5,
          childBuilder: (sessions) {
            if (sessions.isEmpty) {
              return Center(
                child: AppText.body(context.l10n.noUpcomingSessions),
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
