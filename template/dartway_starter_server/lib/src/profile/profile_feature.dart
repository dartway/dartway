import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_starter_shared/dartway_starter_shared.dart';

import 'profile_handlers.dart';

/// A member's own profile: reading and changing it, and hearing it change.
final profileFeature = DwServerFeature(
  'profile',
  handlers: profileHandlers,
  channels: [
    // "My" channel: a member subscribes to their own account's only.
    DwChannelRule.ofCaller(DartwayStarterChannel.profile),
  ],
);
