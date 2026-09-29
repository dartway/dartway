import 'package:dartway_example_flutter/app/cancel_booking/logic/cancel_booking_commands.dart';
import 'package:dartway_example_flutter/core/app_l10n.dart';
import 'package:dartway_example_flutter/core/dw_core.dart';
import 'package:dartway_example_flutter/ui_kit/ui_kit.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';
import 'package:flutter/material.dart';

/// Cancels one active booking — on the schedule's session card and in "my
/// bookings" alike, so both cancel the same way.
class CancelBookingButton extends StatelessWidget implements DwFeatureWidget {
  const CancelBookingButton({required this.booking, super.key});

  @override
  DwFeatureSpec get dwFeature => const DwFeatureSpec(
    id: 'cancel_booking/button',
    title: 'Cancel a booking',
    behaviors: [
      'Cancels the booking and says so; the spot goes back to the session.',
      'The session card and the bookings list both change at once, here and '
          'on the member\'s other devices.',
    ],
    requirements: [
      'Only the member who booked cancels, and only an active booking: '
          'someone else\'s is not found, and a refused cancel shows why.',
    ],
  );

  final SessionBooking booking;

  @override
  Widget build(BuildContext context) => AppButton.secondary(
    context.l10n.cancel,
    onTap: dw.action(
      (_) => CancelBookingCommands.cancel(booking),
      onSuccessNotification: context.l10n.bookingCancelled,
    ),
  );
}
