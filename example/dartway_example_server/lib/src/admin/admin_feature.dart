import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';

import '../core/example_context.dart';
import 'admin_handlers.dart';

/// The admin panel: members, roles and the counters.
final adminFeature = DwServerFeature(
  'admin',
  handlers: adminHandlers,
  channels: [
    DwChannelRule.single(
      ExampleChannel.admin,
      canSubscribe: (ctx) => ctx.isAdmin,
    ),
  ],
);
