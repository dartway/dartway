import 'package:dartway_example_flutter/core/dw_core.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:dartway_example_client/dartway_example_client.dart';
import 'package:dartway_example_flutter/app/bookings/widgets/booking_card.dart';
import 'package:dartway_example_flutter/shared/widgets/app_scaffold.dart';
import 'package:dartway_example_flutter/core/app_backend_filters.dart';
import 'package:dartway_example_flutter/core/app_l10n.dart';
import 'package:dartway_example_flutter/core/user_profile_provider.dart';
import 'package:dartway_example_flutter/ui_kit/ui_kit.dart';

class MyBookingsPage extends ConsumerWidget implements DwFeature {
  const MyBookingsPage({super.key});

  @override
  DwFeatureSpec get dwFeature => const DwFeatureSpec(
    id: 'bookings/my-bookings',
    title: 'My bookings',
    purpose:
        'A member checks what they have signed up for, and which visits they '
        'have already reviewed.',
    behaviors: [
      'Bookings are sorted by session start, the latest first.',
      'A booking that already has a review is marked as reviewed.',
      'With no bookings the screen says so instead of showing an empty list.',
      'While the first page loads, three placeholder cards are shown.',
    ],
    requirements: [
      'A member sees only their own bookings; staff sees all of them. The '
          'decision is the server access filter, not this screen.',
    ],
    implementationNotes: [
      'Two watches, joined locally: the bookings themselves and the reviews, '
          'intersected by bookingId. A review count on the booking model would '
          'remove the second watch — it is kept to show the join is cheap.',
    ],
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewedBookingIds =
        (ref.watch(dw.repo.modelList<SessionReview>()).value ?? [])
            .map((review) => review.bookingId)
            .toSet();

    return AppScaffold.main(
      appBar: AppBar(title: AppText.title(context.l10n.tabBookings)),
      body: ref
          .watch(
            dw.repo.modelList<SessionBooking>(
              backendFilter: AppBackendFilters.clientBookings(
                ref.watchUserProfile.id!,
              ),
            ),
          )
          .dwBuildListAsync(
            loadingItemsCount: 3,
            childBuilder: (bookings) {
              if (bookings.isEmpty) {
                return Center(child: AppText.body(context.l10n.noBookingsYet));
              }

              final sorted = [...bookings]
                ..sort(
                  (a, b) => (b.clubSession?.startsAt ?? b.createdAt).compareTo(
                    a.clubSession?.startsAt ?? a.createdAt,
                  ),
                );

              return ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: sorted.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) => BookingCard(
                  booking: sorted[index],
                  isReviewed: reviewedBookingIds.contains(sorted[index].id),
                ),
              );
            },
          ),
    );
  }
}
