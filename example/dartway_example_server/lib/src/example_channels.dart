import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';

import 'example_context.dart';

/// Who may read what, for a signed-in account: asked when a connection
/// subscribes, and for every channel a command publishes to, whether the
/// command's response carries it. So each rule holds for any caller, not only
/// for the screen that subscribes — and everything published to a channel is
/// readable by everyone its rule allows.
final exampleChannels = <DwChannelRule>[
  DwChannelRule.single(ExampleChannel.schedule, canSubscribe: _anyMember),
  DwChannelRule.single(ExampleChannel.news, canSubscribe: _anyMember),
  DwChannelRule.single(ExampleChannel.settings, canSubscribe: _anyMember),
  DwChannelRule.single(
    ExampleChannel.staffChannels,
    canSubscribe: (ctx) => ctx.isStaff,
  ),
  DwChannelRule.keyed<int>(
    ExampleChannel.staffChat,
    parseKey: int.parse,
    canSubscribe: (ctx, channelId) => ctx.isStaff,
  ),
  // "My" channels: a member subscribes to their own account's only.
  DwChannelRule.ofCaller(ExampleChannel.bookings),
  DwChannelRule.ofCaller(ExampleChannel.profile),
  // A caller channel, as `ofCaller` declares one — the member's own account
  // only — and staff only besides: nothing is ever published to a client's,
  // and a subscription that can never hear anything is a mistake to refuse.
  DwChannelRule.keyed<int>(
    ExampleChannel.chatReads,
    parseKey: int.parse,
    canSubscribe: (ctx, accountId) async =>
        ctx.accountId == accountId && await ctx.isStaff,
  ),
  DwChannelRule.single(
    ExampleChannel.admin,
    canSubscribe: (ctx) => ctx.isAdmin,
  ),
];

Future<bool> _anyMember(DwCallContext ctx) async => true;

/// The bookings channel of [accountId]'s member: where their "my bookings"
/// hears a booking of theirs, whoever changed it.
DwLiveChannel bookingsOf(int accountId) =>
    DwLiveChannel.forAccount(ExampleChannel.bookings, accountId);

/// The profile channel of [accountId]'s member: where their own profile
/// hears a change to it, whoever made it.
DwLiveChannel profileOf(int accountId) =>
    DwLiveChannel.forAccount(ExampleChannel.profile, accountId);
