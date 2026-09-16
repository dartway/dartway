import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_starter_shared/dartway_starter_shared.dart';

import 'call_context.dart';

/// The app's live channels: the rules deciding who may hear each, and the
/// channels handlers publish to.
abstract final class AppChannels {
  /// Who may read what, for a signed-in account: asked when a connection
  /// subscribes, and for every channel a command publishes to, whether the
  /// command's response carries it. So each rule holds for any caller, not only
  /// for the screen that subscribes — and everything published to a channel is
  /// readable by everyone its rule allows.
  static final rules = <DwChannelRule>[
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

  static Future<bool> _anyMember(DwCallContext ctx) async => true;

  static const admin = DwLiveChannel(DartwayStarterChannel.admin);
  static const settings = DwLiveChannel(DartwayStarterChannel.settings);

  /// Where [accountId]'s own profile hears a change to it, whoever made it.
  static DwLiveChannel profileOf(int accountId) =>
      DwLiveChannel.forAccount(DartwayStarterChannel.profile, accountId);
}
