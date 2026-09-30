import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_example_server/src/chat/chat_handlers.dart';
import 'package:dartway_example_server/src/chat/chat_messages_handlers.dart';
import 'package:dartway_example_server/src/chat/chat_rows.dart';
import 'package:dartway_example_server/src/profile/profile_access.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';

/// The staff chat: its channels, messages and read positions.
final chatFeature = DwServerFeature(
  'chat',
  handlers: [...chatHandlers, ...chatMessagesHandlers],
  startup: [
    DwSeedRows(
      'staff channels',
      table: ChatChannelRow.tableDef,
      key: (t) => [t.slug],
      rows: staffChannels,
    ),
  ],
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
