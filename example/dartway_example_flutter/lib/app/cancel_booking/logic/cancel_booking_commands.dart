import 'package:dartway_example_flutter/core/dw_core.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';

/// The command the cancel button sends.
abstract final class CancelBookingCommands {
  /// Cancels [booking] and frees its spot. The answer carries the booking and
  /// the session, and every list on screen takes them before the command
  /// completes; other devices get them on their channels.
  static Future<DwCallResult<SessionBooking>> cancel(SessionBooking booking) =>
      dw.command(CancelBooking(bookingId: booking.id));
}
