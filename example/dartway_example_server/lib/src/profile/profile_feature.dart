import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';

import 'profile_handlers.dart';

/// A member's own profile, heard live by its owner.
final profileFeature = DwServerFeature(
  'profile',
  handlers: profileHandlers,
  channels: [
    // "My" channel: a member subscribes to their own account's only.
    DwChannelRule.ofCaller(ExampleChannel.profile),
  ],
);
