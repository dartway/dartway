import 'package:dartway_push_shared/dartway_push_shared.dart';

/// The example's kinds of notification. The server's eligibility rule reads
/// them: news goes only to members who agreed to marketing.
enum DartwayExamplePushCategory with DwPushCategory {
  /// A news post was published.
  news,

  /// A session the member booked starts soon. Sent to everyone who booked:
  /// it is about their own visit, not marketing.
  bookingReminder,
}
