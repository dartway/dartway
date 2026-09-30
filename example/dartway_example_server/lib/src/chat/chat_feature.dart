import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_example_server/src/chat/chat_handlers.dart';
import 'package:dartway_example_server/src/core/call_context.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';

/// The staff chat: its channels, messages and read positions.
final chatFeature = DwServerFeature(
  'chat',
  handlers: chatHandlers,
  channels: [
    DwChannelRule.single(
      DartwayExampleChannel.staffChannels,
      canSubscribe: (ctx) => ctx.isStaff,
    ),
    DwChannelRule.keyed<int>(
      DartwayExampleChannel.staffChat,
      parseKey: int.parse,
      canSubscribe: (ctx, channelId) => ctx.isStaff,
    ),
    // A caller channel, as `ofCaller` declares one — the member's own account
    // only — and staff only besides: nothing is ever published to a client's,
    // and a subscription that can never hear anything is a mistake to refuse.
    DwChannelRule.keyed<int>(
      DartwayExampleChannel.chatReads,
      parseKey: int.parse,
      canSubscribe: (ctx, accountId) async =>
          ctx.accountId == accountId && await ctx.isStaff,
    ),
  ],
);
