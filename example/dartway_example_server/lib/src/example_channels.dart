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
  DwChannelRule.keyed<int>(
    ExampleChannel.bookings,
    parseKey: int.parse,
    canSubscribe: _ownAccount,
  ),
  DwChannelRule.keyed<int>(
    ExampleChannel.profile,
    parseKey: int.parse,
    canSubscribe: _ownAccount,
  ),
  DwChannelRule.single(
    ExampleChannel.admin,
    canSubscribe: (ctx) => ctx.isAdmin,
  ),
];

Future<bool> _anyMember(DwCallContext ctx) async => true;

Future<bool> _ownAccount(DwCallContext ctx, int accountId) async =>
    ctx.accountId == accountId;
