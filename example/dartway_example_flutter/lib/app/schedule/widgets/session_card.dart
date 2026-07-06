import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:dartway_example_client/dartway_example_client.dart';
import 'package:dartway_example_flutter/core/user_profile_provider.dart';
import 'package:dartway_example_flutter/ui_kit/ui_kit.dart';

class SessionCard extends ConsumerWidget {
  const SessionCard({
    required this.session,
    required this.activeBooking,
    super.key,
  });

  final ClubSession session;

  /// The current user's active booking for this session, if any.
  final SessionBooking? activeBooking;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coachName = session.coachProfile?.firstName ?? '';

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Column(
              children: [
                AppText.title(session.startsAt.timeLabel),
                AppText.caption('${session.service?.durationMinutes ?? 0} min'),
              ],
            ),
            const Gap(16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText.body(
                    session.service?.title ?? 'Session',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (coachName.isNotEmpty) AppText.caption('with $coachName'),
                  AppText.caption('up to ${session.capacity} people'),
                ],
              ),
            ),
            const Gap(12),
            if (activeBooking == null)
              DwButton.primary(
                'Book',
                dwCallback: DwUiAction.create(
                  (context) => DwRepository.saveModel(
                    SessionBooking(
                      clubSessionId: session.id!,
                      clientProfileId: ref.readUserProfile.id!,
                      status: BookingStatus.booked,
                      createdAt: DateTime.now(),
                    ),
                  ),
                  onSuccessNotification: 'You are booked!',
                ),
              )
            else
              DwButton.secondary(
                'Cancel',
                dwCallback: DwUiAction.create(
                  (context) => DwRepository.saveModel(
                    activeBooking!.copyWith(status: BookingStatus.cancelled),
                  ),
                  onSuccessNotification: 'Booking cancelled',
                ),
              ),
          ],
        ),
      ),
    );
  }
}
