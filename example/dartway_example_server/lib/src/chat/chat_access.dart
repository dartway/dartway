import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_example_server/generated/dw_schema.dart';
import 'package:dartway_example_server/src/chat/chat_rows.dart';
import 'package:dartway_example_server/src/profile/profile_access.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';

/// What the chat means by a message someone may still act on: the one
/// definition, which the handlers, the lookups and the attachments' read
/// rule all ask.
extension ChatAccessContext on DwCallContext {
  /// The message [messageId], or `null` when there is none or it is deleted.
  /// With [lock], held until the command commits: edits, deletions and pins of
  /// one message queue instead of overwriting each other's row.
  Future<ChatMessageRow?> liveChatMessage(
    int messageId, {
    bool lock = false,
  }) async {
    final row = await db.chatMessages.findById(
      messageId,
      lock: lock ? DwRowLock.forUpdate : null,
    );
    return row == null || row.isDeleted ? null : row;
  }

  /// The message [messageId], locked for a change, to staff; `null` — and no
  /// lock taken — for anyone else, or when there is none or it is deleted.
  Future<ChatMessageRow?> staffChatMessage(int messageId) async =>
      await isStaff ? await liveChatMessage(messageId, lock: true) : null;
}

/// Files attached to chat messages: who may upload them, and who may read one.
/// The chat's, because the answer is the chat's — a staff member, a message
/// not deleted; the server's library hands [rule] to the storage and asks
/// [canRead] first.
abstract final class ChatAttachments {
  /// Pictures and documents attached to staff chat messages: private, so every
  /// read goes through `DwGetFileLink` and [canRead].
  static final rule = DwUploadRule(
    DartwayExampleUpload.chatAttachment,
    visibility: DwFileVisibility.private,
    maxBytes: 20 * 1024 * 1024,
    contentTypes: {
      'image/jpeg',
      'image/png',
      'image/webp',
      'image/gif',
      'application/pdf',
      'text/plain',
    },
    // Only staff write in the chat, so only staff upload for it.
    canUpload: (ctx) => ctx.isStaff,
  );

  /// Who may read a chat attachment: `null` for a file of another purpose —
  /// not this rule's to decide.
  ///
  /// Staff, while the file is attached to a message that is not deleted: a
  /// deleted message takes its files out of reach even for someone who still
  /// holds the id. Before it is attached, only its uploader — the file of a
  /// message being written, shown back in the composer.
  static Future<bool?> canRead(DwCallContext ctx, DwFileRecord file) async {
    if (!file.isFor(DartwayExampleUpload.chatAttachment)) return null;
    // Anonymous: no; the framework tells the caller to sign in.
    if (ctx.accountId == null) return false;
    final attachment = await ctx.db.chatMessageAttachments.findFirst(
      where: (t) => t.fileId.equals(file.id),
    );
    if (attachment == null) return file.accountId == ctx.accountId;
    if (!await ctx.isStaff) return false;
    return await ctx.liveChatMessage(attachment.messageId) != null;
  }
}
