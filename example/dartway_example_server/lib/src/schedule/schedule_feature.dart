import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';

import 'package:dartway_example_server/src/schedule/schedule_handlers.dart';

/// The club's services and the sessions on its schedule.
final scheduleFeature = DwServerFeature(
  'schedule',
  handlers: scheduleHandlers,
  channels: [
    DwChannelRule.single(
      DartwayExampleChannel.schedule,
      canSubscribe: (ctx) async => true,
    ),
  ],
);
