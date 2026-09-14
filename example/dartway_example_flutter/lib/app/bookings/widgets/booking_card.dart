import 'package:dartway_example_flutter/app/bookings/widgets/review_bottom_sheet.dart';
import 'package:dartway_example_flutter/core/app_l10n.dart';
import 'package:dartway_example_flutter/core/dw_core.dart';
import 'package:dartway_example_flutter/ui_kit/ui_kit.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class BookingCard extends StatelessWidget {
  const BookingCard({required this.booking, super.key});

  final SessionBooking booking;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final session = booking.session;
    final startsAt = session.startsAt;

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
                    session.service.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                AppText.caption(l10n.bookingStatus(booking.status.name)),
              ],
            ),
            AppText.caption('${startsAt.dayLabel} · ${startsAt.timeLabel}'),
            const Gap(12),
            if (booking.status == BookingStatus.booked &&
                startsAt.isAfter(DateTime.now()))
              AppButton.secondary(
                l10n.cancelBooking,
                onTap: dw.action(
                  (_) => dw.command(CancelBooking(bookingId: booking.id)),
                  onSuccessNotification: l10n.bookingCancelled,
                ),
              ),
            if (booking.status == BookingStatus.attended)
              booking.review == null
                  ? AppButton.primary(
                      l10n.leaveReview,
                      onTap: dw.action(
                        (context) => context.showAppBottomSheet(
                          child: ReviewBottomSheet(booking: booking),
                        ),
                      ),
                    )
                  : AppText.caption(l10n.thanksForReview),
          ],
        ),
      ),
    );
  }
}
