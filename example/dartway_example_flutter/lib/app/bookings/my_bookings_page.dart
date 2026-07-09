import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:dartway_example_client/dartway_example_client.dart';
import 'package:dartway_example_flutter/app/bookings/widgets/booking_card.dart';
import 'package:dartway_example_flutter/common/app_scaffold.dart';
import 'package:dartway_example_flutter/core/app_backend_filters.dart';
import 'package:dartway_example_flutter/core/app_l10n.dart';
import 'package:dartway_example_flutter/core/user_profile_provider.dart';
import 'package:dartway_example_flutter/ui_kit/ui_kit.dart';

class MyBookingsPage extends ConsumerWidget {
  const MyBookingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewedBookingIds = (ref.watchModelList<SessionReview>().value ?? [])
        .map((review) => review.bookingId)
        .toSet();

    return AppScaffold.main(
      appBar: AppBar(title: AppText.title(context.l10n.tabBookings)),
      body: ref
          .watchModelList<SessionBooking>(
            backendFilter: AppBackendFilters.clientBookings(
              ref.watchUserProfile.id!,
            ),
          )
          .dwBuildListAsync(
            loadingItemsCount: 3,
            childBuilder: (bookings) {
              if (bookings.isEmpty) {
                return Center(
                  child: AppText.body(context.l10n.noBookingsYet),
                );
              }

              final sorted = [...bookings]..sort(
                  (a, b) => (b.clubSession?.startsAt ?? b.createdAt)
                      .compareTo(a.clubSession?.startsAt ?? a.createdAt),
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
