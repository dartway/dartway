import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_example_server/generated/dw_schema.dart';
import 'package:dartway_example_server/src/chat/chat_access.dart';
import 'package:dartway_example_server/src/chat/chat_rows.dart';

/// The staff chat's lookups and its read position, for its handlers.
extension ChatLookups on DwCallContext {
  /// The channel [channelId], or `dw.notFound`.
  Future<void> requireChatChannel(int channelId) async {
    if (!await db.chatChannels.exists(where: (t) => t.id.equals(channelId))) {
      refuse(DwCoreRefusal.notFound);
    }
  }

  /// The message [messageId] unless it is deleted; otherwise `dw.notFound`.
  Future<ChatMessageRow> requireChatMessage(
    int messageId, {
    bool lock = false,
  }) async =>
      await liveChatMessage(messageId, lock: lock) ??
      refuse(DwCoreRefusal.notFound);

  /// Moves [profileId]'s position in [message]'s channel forward to
  /// [message]; a message at or before the position changes nothing.
  ///
  /// Two statements and no read-then-write: the insert skips an existing
  /// row (waiting for a concurrent insert of the same pair to commit), and
  /// the update's condition is checked again against the locked row — so two
  /// marks racing each other leave the newer of the two, whatever the order
  /// they commit in.
  Future<void> moveChatReadForward(
    int profileId,
    ChatMessageRow message,
  ) async {
    final inserted = await db.chatReadPositions.tryInsert(
      NewChatReadPositionRow(
        profileId: profileId,
        channelId: message.channelId,
        messageId: message.id,
        sentAt: message.sentAt,
      ),
      onConflict: DwOnConflict.doNothing((t) => [t.profileId, t.channelId]),
    );
    if (inserted != null) return;
    await db.chatReadPositions.updateWhere(
      where: (t) =>
          t.profileId.equals(profileId) &
          t.channelId.equals(message.channelId) &
          (t.sentAt.lt(message.sentAt) |
              (t.sentAt.equals(message.sentAt) & t.messageId.lt(message.id))),
      set: (t) => [t.messageId.set(message.id), t.sentAt.set(message.sentAt)],
    );
  }
}
