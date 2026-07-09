import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:dartway_example_client/dartway_example_client.dart';
import 'package:dartway_example_flutter/app/bookings/widgets/review_bottom_sheet.dart';
import 'package:dartway_example_flutter/core/app_l10n.dart';
import 'package:dartway_example_flutter/ui_kit/ui_kit.dart';

class BookingCard extends StatelessWidget {
  const BookingCard({
    required this.booking,
    required this.isReviewed,
    super.key,
  });

  final SessionBooking booking;
  final bool isReviewed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final clubSession = booking.clubSession;
    final startsAt = clubSession?.startsAt;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: AppText.body(
                    clubSession?.service?.title ?? l10n.sessionFallbackTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                AppText.caption(l10n.bookingStatus(booking.status.name)),
              ],
            ),
            if (startsAt != null)
              AppText.caption('${startsAt.dayLabel} · ${startsAt.timeLabel}'),
            const Gap(12),
            if (_canCancel(startsAt))
              DwButton.secondary(
                l10n.cancelBooking,
                dwCallback: DwUiAction.create(
                  (context) => DwRepository.saveModel(
                    booking.copyWith(status: BookingStatus.cancelled),
                  ),
                  onSuccessNotification: l10n.bookingCancelled,
                ),
              ),
            if (booking.status == BookingStatus.attended && !isReviewed)
              DwButton.primary(
                l10n.leaveReview,
                dwCallback: DwUiAction.create(
                  (context) => context.showAppBottomSheet(
                    child: ReviewBottomSheet(booking: booking),
                  ),
                ),
              ),
            if (booking.status == BookingStatus.attended && isReviewed)
              AppText.caption(l10n.thanksForReview),
          ],
        ),
      ),
    );
  }

  bool _canCancel(DateTime? startsAt) =>
      booking.status == BookingStatus.booked &&
      (startsAt?.isAfter(DateTime.now()) ?? false);
}
