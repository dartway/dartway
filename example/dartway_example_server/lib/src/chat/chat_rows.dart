import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';

part 'chat_rows.dw.dart';

@DwSqlTable('chat_channel')
final class ChatChannelRow extends DwTableRow with _$ChatChannelRow {
  const ChatChannelRow({this.id, required this.title});

  @override
  final int? id;
  final String title;

  static const tableDef = ChatChannelTable();
}

/// One message of a channel. Deleting it only sets [deletedAt]: replies keep
/// their link to it, and quote it as deleted rather than losing the quote.
///
/// The window over a channel reads by `(channelId, sentAt, id)` in both
/// directions, and the unread counts compare against the same pair; the index
/// serves each as one range scan.
@DwSqlTable(
  'chat_message',
  indexes: [
    DwTableIndex(['channelId', 'sentAt', 'id']),
  ],
)
final class ChatMessageRow extends DwTableRow with _$ChatMessageRow {
  const ChatMessageRow({
    this.id,
    required this.channelId,
    required this.authorProfileId,
    required this.text,
    required this.sentAt,
    this.editedAt,
    this.pinnedAt,
    this.pinnedByProfileId,
    this.replyToMessageId,
    this.deletedAt,
  });

  @override
  final int? id;

  @DwForeignKey('chat_channel', onDelete: DwOnDelete.cascade)
  final int channelId;

  @DwForeignKey('user_profile', onDelete: DwOnDelete.cascade)
  final int authorProfileId;

  /// Stays in the row after a deletion, but no client is sent it again: a
  /// quote of a deleted message goes out without it.
  final String text;

  /// Set by the server when the message is sent; the window's sort value.
  final DateTime sentAt;

  /// Set by the server on every edit.
  final DateTime? editedAt;

  final DateTime? pinnedAt;

  @DwForeignKey('user_profile', onDelete: DwOnDelete.setNull)
  final int? pinnedByProfileId;

  /// Messages are only ever soft-deleted, so the link survives a deletion;
  /// it goes only with the channel itself.
  @DwForeignKey('chat_message', onDelete: DwOnDelete.setNull)
  final int? replyToMessageId;

  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  static const tableDef = ChatMessageTable();
}

/// A stored file attached to a message, in the message's order. A file is
/// attached once: [fileId] is unique, so a file cannot be smuggled into a
/// second message and inherit its readers.
@DwSqlTable(
  'chat_message_attachment',
  indexes: [
    DwTableIndex(['messageId', 'position']),
  ],
)
final class ChatMessageAttachmentRow extends DwTableRow
    with _$ChatMessageAttachmentRow {
  const ChatMessageAttachmentRow({
    this.id,
    required this.messageId,
    required this.fileId,
    required this.position,
    this.width,
    this.height,
  });

  @override
  final int? id;

  @DwForeignKey('chat_message', onDelete: DwOnDelete.cascade)
  final int messageId;

  /// The framework's `dw_stored_file` id.
  @DwUniqueColumn()
  @DwForeignKey('dw_stored_file', onDelete: DwOnDelete.cascade)
  final int fileId;

  final int position;
  final int? width;
  final int? height;

  static const tableDef = ChatMessageAttachmentTable();
}

/// One member's reaction to a message. The unique pair is what makes "one
/// reaction per member" true under a double tap, not the handler's check.
@DwSqlTable(
  'chat_message_reaction',
  indexes: [
    DwTableIndex(['messageId', 'profileId'], unique: true),
  ],
)
final class ChatMessageReactionRow extends DwTableRow
    with _$ChatMessageReactionRow {
  const ChatMessageReactionRow({
    this.id,
    required this.messageId,
    required this.profileId,
    required this.reaction,
  });

  @override
  final int? id;

  @DwForeignKey('chat_message', onDelete: DwOnDelete.cascade)
  final int messageId;

  @DwForeignKey('user_profile', onDelete: DwOnDelete.cascade)
  final int profileId;

  final ChatReaction reaction;

  static const tableDef = ChatMessageReactionTable();
}

/// How far one member has read one channel: the last message seen, as the
/// window orders messages. [sentAt] is copied from the message so the unread
/// count compares pairs without joining it back.
@DwSqlTable(
  'chat_read_position',
  indexes: [
    DwTableIndex(['profileId', 'channelId'], unique: true),
  ],
)
final class ChatReadPositionRow extends DwTableRow with _$ChatReadPositionRow {
  const ChatReadPositionRow({
    this.id,
    required this.profileId,
    required this.channelId,
    required this.messageId,
    required this.sentAt,
  });

  @override
  final int? id;

  @DwForeignKey('user_profile', onDelete: DwOnDelete.cascade)
  final int profileId;

  @DwForeignKey('chat_channel', onDelete: DwOnDelete.cascade)
  final int channelId;

  @DwForeignKey('chat_message', onDelete: DwOnDelete.cascade)
  final int messageId;

  final DateTime sentAt;

  static const tableDef = ChatReadPositionTable();
}
