import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_starter_server/src/admin/admin_handlers.dart';
import 'package:dartway_starter_server/src/core/call_context.dart';
import 'package:dartway_starter_shared/dartway_starter_shared.dart';

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
