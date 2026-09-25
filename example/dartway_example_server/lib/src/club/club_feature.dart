import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';

import 'booking_handlers.dart';
import 'schedule_handlers.dart';

/// The club's schedule and a member's bookings in it.
final clubFeature = DwServerFeature(
  'club',
  handlers: [...scheduleHandlers, ...bookingHandlers],
  channels: [
    DwChannelRule.single(
      ExampleChannel.schedule,
      canSubscribe: (ctx) async => true,
    ),
    // "My" channel: a member subscribes to their own account's only.
    DwChannelRule.ofCaller(ExampleChannel.bookings),
  ],
);
