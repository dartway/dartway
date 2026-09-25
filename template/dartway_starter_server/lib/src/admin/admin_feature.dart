import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_starter_shared/dartway_starter_shared.dart';

import '../core/call_context.dart';
import 'admin_handlers.dart';

/// The admin panel: the members, their roles, the counters.
final adminFeature = DwServerFeature(
  'admin',
  handlers: adminHandlers,
  channels: [
    DwChannelRule.single(
      DartwayStarterChannel.admin,
      canSubscribe: (ctx) => ctx.isAdmin,
    ),
  ],
);
