import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';

import 'content_handlers.dart';

/// News and app settings: written by staff, read live by every member.
final contentFeature = DwServerFeature(
  'content',
  handlers: contentHandlers,
  channels: [
    DwChannelRule.single(
      ExampleChannel.news,
      canSubscribe: (ctx) async => true,
    ),
    DwChannelRule.single(
      ExampleChannel.settings,
      canSubscribe: (ctx) async => true,
    ),
  ],
);
