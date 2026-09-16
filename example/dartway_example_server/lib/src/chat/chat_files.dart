import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';

import '../../generated/dw_schema.dart';
import '../example_context.dart';

/// Files attached to chat messages: who may upload them, and who may read one.
abstract final class ChatAttachments {
  /// Pictures and documents attached to staff chat messages: private, so every
  /// read goes through `DwGetFileLink` and [canRead].
  static final rule = DwUploadRule(
    ExampleUpload.chatAttachment,
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
    if (!file.isFor(ExampleUpload.chatAttachment)) return null;
    // Anonymous: no; the framework tells the caller to sign in.
    if (ctx.accountId == null) return false;
    final attachment = await ctx.db.chatMessageAttachments.findFirst(
      where: (t) => t.fileId.equals(file.id),
    );
    if (attachment == null) return file.accountId == ctx.accountId;
    if (!await ctx.isStaff) return false;
    final message = await ctx.db.chatMessages.findById(attachment.messageId);
    return message != null && !message.isDeleted;
  }
}
