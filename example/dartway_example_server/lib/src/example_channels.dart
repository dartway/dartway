import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';

import 'example_context.dart';

/// Who may listen to what. Checked once, at subscription — and only for a
/// signed-in connection, which every subscription requires: everything
/// published to a channel is readable by every subscriber of it.
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
