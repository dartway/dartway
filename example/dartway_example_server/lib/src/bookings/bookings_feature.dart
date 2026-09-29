import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';

import 'bookings_handlers.dart';
import 'bookings_jobs.dart';

/// A member's bookings of the club's sessions, their reviews of the visits,
/// and the reminder before a booked session.
final bookingsFeature = DwServerFeature(
  'bookings',
  handlers: bookingsHandlers,
  channels: [
    // "My" channel: a member subscribes to their own account's only.
    DwChannelRule.ofCaller(DartwayExampleChannel.bookings),
  ],
  jobs: bookingsJobs,
);
