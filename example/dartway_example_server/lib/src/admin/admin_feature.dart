import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_example_server/src/admin/admin_handlers.dart';
import 'package:dartway_example_server/src/core/call_context.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';

/// The admin panel: members, roles and the counters.
final adminFeature = DwServerFeature(
  'admin',
  handlers: adminHandlers,
  channels: [
    DwChannelRule.single(
      DartwayExampleChannel.admin,
      canSubscribe: (ctx) => ctx.isAdmin,
    ),
  ],
);
