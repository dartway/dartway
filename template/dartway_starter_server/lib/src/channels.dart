import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_starter_shared/dartway_starter_shared.dart';

import 'call_context.dart';

/// Who may read what, for a signed-in account: asked when a connection
/// subscribes, and for every channel a command publishes to, whether the
/// command's response carries it. So each rule holds for any caller, not only
/// for the screen that subscribes — and everything published to a channel is
/// readable by everyone its rule allows.
final appChannels = <DwChannelRule>[
  // "My" channel: a member subscribes to their own account's only.
  DwChannelRule.ofCaller(DartwayStarterChannel.profile),
  DwChannelRule.single(
    DartwayStarterChannel.settings,
    canSubscribe: _anyMember,
  ),
  DwChannelRule.single(
    DartwayStarterChannel.admin,
    canSubscribe: (ctx) => ctx.isAdmin,
  ),
];

Future<bool> _anyMember(DwCallContext ctx) async => true;

const adminChannel = DwLiveChannel(DartwayStarterChannel.admin);
const settingsChannel = DwLiveChannel(DartwayStarterChannel.settings);

/// Where [accountId]'s own profile hears a change to it, whoever made it.
DwLiveChannel profileOf(int accountId) =>
    DwLiveChannel.forAccount(DartwayStarterChannel.profile, accountId);
