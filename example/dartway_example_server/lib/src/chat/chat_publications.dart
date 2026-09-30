import 'package:dartway_core_server/dartway_core_server.dart';

import 'package:dartway_example_server/src/core/channels.dart';
import 'package:dartway_example_server/generated/dw_schema.dart';
import 'package:dartway_example_server/src/chat/chat_objects.dart';
import 'package:dartway_example_server/src/chat/chat_rows.dart';

/// What a chat change is published as, and to whom.
abstract final class ChatPublications {
  /// Publishes every staff member's read state of [channelId] on their own
  /// chat reads channel: a message sent or deleted there moves the count of
  /// everyone who has not read past it.
  ///
  /// One statement for all of them, however many staff there are; a member
  /// whose count did not change hears the same state again, which their list
  /// applies as no change.
  static Future<void> readStates(DwCallContext ctx, int channelId) async {
    for (final (:accountId, :state) in await ChatObjects.staffReadStatesIn(
      ctx.db,
      channelId,
    )) {
      ctx.publish(AppChannels.chatReadsOf(accountId), state);
    }
  }

  /// Republishes the live messages that quote [quoted]: their quote changed
  /// with it — its text, or that it is deleted.
  static Future<void> quoting(DwCallContext ctx, ChatMessageRow quoted) async {
    final replies = await ctx.db.chatMessages.find(
      where: (t) => t.replyToMessageId.equals(quoted.id) & t.deletedAt.isNull(),
    );
    for (final reply in await ChatObjects.messages(ctx, replies)) {
      ctx.publish(AppChannels.chatOf(reply.channelId), reply);
    }
  }
}
