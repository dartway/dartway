import 'package:dartway_example_flutter/core/app_l10n.dart';
import 'package:dartway_example_flutter/core/dw_core.dart';
import 'package:dartway_example_flutter/ui_kit/ui_kit.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class SessionCard extends StatelessWidget {
  const SessionCard({
    required this.session,
    required this.activeBooking,
    super.key,
  });

  final ClubSessionView session;

  /// The current user's active booking for this session, if any.
  final BookingView? activeBooking;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final coach = session.coach;
    final booking = activeBooking;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Column(
              children: [
                AppText.title(session.startsAt.timeLabel),
                AppText.caption(
                  l10n.minutesShort(session.service.durationMinutes),
                ),
              ],
            ),
            const Gap(16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText.body(
                    session.service.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (coach != null)
                    AppText.caption(l10n.withCoach(coach.firstName)),
                  AppText.caption(
                    l10n.spotsLeft(session.spotsLeft, session.capacity),
                  ),
                ],
              ),
            ),
            const Gap(12),
            // The results need no handling: the server publishes the booking
            // and the session, and both lists on screen take them live.
            if (booking != null)
              AppButton.secondary(
                l10n.cancel,
                onTap: dw.action(
                  (_) => dw.command(CancelBooking(bookingId: booking.id)),
                  onSuccessNotification: l10n.bookingCancelled,
                ),
              )
            else if (session.startsAt.isAfter(DateTime.now()))
              session.spotsLeft > 0
                  ? AppButton.primary(
                      l10n.book,
                      onTap: dw.action(
                        (_) => dw.command(BookSession(sessionId: session.id)),
                        onSuccessNotification: l10n.youAreBooked,
                      ),
                    )
                  : AppButton.primary(l10n.sessionFull, onTap: null),
          ],
        ),
      ),
    );
  }
}
