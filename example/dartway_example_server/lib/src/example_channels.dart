import 'package:dartway_example_shared/dartway_example_shared.dart';
import 'package:dartway_server/dartway_server.dart';

import 'example_context.dart';

/// Who may listen to what. Checked once, at subscription: everything published
/// to a channel is readable by every subscriber of it.
final exampleChannels = <DwChannelRule>[
  DwChannelRule.single(ExampleChannel.schedule, canSubscribe: _signedIn),
  DwChannelRule.single(ExampleChannel.news, canSubscribe: _signedIn),
  DwChannelRule.single(ExampleChannel.settings, canSubscribe: _signedIn),
  DwChannelRule.single(
    ExampleChannel.staffChannels,
    canSubscribe: (ctx) => ctx.isStaff,
  ),
  DwChannelRule.keyed<int>(
    ExampleChannel.staffChat,
    parseKey: int.parse,
    canSubscribe: (ctx, channelId) => ctx.isStaff,
  ),
  DwChannelRule.keyed<int>(
    ExampleChannel.bookings,
    parseKey: int.parse,
    canSubscribe: (ctx, profileId) async =>
        (await ctx.profile).id == profileId || await ctx.isStaff,
  ),
  DwChannelRule.keyed<int>(
    ExampleChannel.profile,
    parseKey: int.parse,
    canSubscribe: (ctx, accountId) async => ctx.accountId == accountId,
  ),
  DwChannelRule.single(ExampleChannel.admin, canSubscribe: (ctx) => ctx.isAdmin),
];

Future<bool> _signedIn(DwContext ctx) async => ctx.accountId != null;
