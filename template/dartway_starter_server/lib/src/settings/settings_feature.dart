import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_starter_shared/dartway_starter_shared.dart';

import 'settings_handlers.dart';

/// App settings an admin edits and every member reads live.
final settingsFeature = DwServerFeature(
  'settings',
  handlers: settingsHandlers,
  channels: [
    DwChannelRule.single(
      DartwayStarterChannel.settings,
      canSubscribe: (ctx) async => true,
    ),
  ],
);
