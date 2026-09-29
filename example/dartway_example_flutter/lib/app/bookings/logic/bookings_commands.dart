import 'package:dartway_example_flutter/core/dw_core.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';

/// The commands the bookings screen sends.
abstract final class BookingsCommands {
  /// Reviews the attended visit [booking]: a [rating] from 1 to 5 and an
  /// optional [text]. One review per visit — the server's rule.
  static Future<DwCallResult<SessionBooking>> review(
    SessionBooking booking, {
    required int rating,
    required String text,
  }) {
    final trimmed = text.trim();
    return dw.command(
      ReviewVisit(
        bookingId: booking.id,
        rating: rating,
        text: trimmed.isEmpty ? null : trimmed,
      ),
    );
  }
}
