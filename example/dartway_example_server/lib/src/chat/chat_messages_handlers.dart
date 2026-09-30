import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_example_server/generated/dw_schema.dart';
import 'package:dartway_example_server/src/chat/chat_access.dart';
import 'package:dartway_example_server/src/chat/chat_objects.dart';
import 'package:dartway_example_server/src/chat/chat_publications.dart';
import 'package:dartway_example_server/src/chat/chat_rows.dart';
import 'package:dartway_example_server/src/chat/logic/chat_lookups.dart';
import 'package:dartway_example_server/src/core/channels.dart';
import 'package:dartway_example_server/src/profile/profile_access.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';

/// Advisory lock namespace of reactions: the first key of the two-key lock,
/// the message id the second.
const int _reactionLocks = 0x43480001;

/// What changes a message of the staff chat: sending, editing, deleting,
/// pinning and reacting. Every call is staff only; each change is published
/// as the message itself on its channel, with every message quoting it.
final chatMessagesHandlers = <DwCallHandler>[
  /// Sends a message, with the caller's own unsent uploads attached. Staff
  /// only. Published on its channel; moves the sender's read position and
  /// everyone's unread counts.
  DwCallHandler.command<SendChatMessage, ChatMessage>(
    access: ProfileAccess.staff,
    handle: (ctx, command) async {
      final me = await ctx.profile;
      await ctx.requireChatChannel(command.channelId);
      if (command.replyToMessageId case final quotedId?) {
        final quoted = await ctx.db.chatMessages.findById(quotedId);
        if (quoted == null ||
            quoted.isDeleted ||
            quoted.channelId != command.channelId) {
          ctx.refuse(DwCoreRefusal.notFound, field: 'replyToMessageId');
        }
      }

      // The same file twice is one attachment.
      final drafts = {
        for (final draft in command.attachments) draft.id: draft,
      }.values.toList();
      for (final draft in drafts) {
        await ctx.files.requireOwned(
          draft.id,
          DartwayExampleUpload.chatAttachment,
          field: 'attachments',
        );
      }
      // Owned, but already sent with another message: it is that message's
      // now, readable by whoever reads that message.
      if (drafts.isNotEmpty &&
          await ctx.db.chatMessageAttachments.exists(
            where: (t) => t.fileId.inList([for (final d in drafts) d.id]),
          )) {
        ctx.refuse(DwUploadRefusal.notOwned, field: 'attachments');
      }

      final row = await ctx.db.chatMessages.insert(
        NewChatMessageRow(
          channelId: command.channelId,
          authorProfileId: me.id,
          text: command.text.trim(),
          sentAt: ctx.now,
          replyToMessageId: command.replyToMessageId,
        ),
      );
      try {
        await ctx.db.chatMessageAttachments.insertAll([
          for (final (position, draft) in drafts.indexed)
            NewChatMessageAttachmentRow(
              messageId: row.id,
              fileId: draft.id,
              position: position,
              width: draft.width,
              height: draft.height,
            ),
        ]);
      } on DwUniqueViolation {
        // The same file sent with two messages at once: the other one won.
        ctx.refuse(DwUploadRefusal.notOwned, field: 'attachments');
      }
      // Sending is having read up to one's own message.
      await ctx.moveChatReadForward(me.id, row);

      final message = (await ChatObjects.messages(ctx, [
        row,
      ], author: me)).single;
      ctx.publish(AppChannels.chatOf(row.channelId), message);
      await ChatPublications.readStates(ctx, row.channelId);
      return message;
    },
  ),

  /// Rewrites a message within its edit window. Staff only, and only its
  /// author: other staff are refused `dw.forbidden` (the message is visible to
  /// them), anyone else — a demoted author too — `dw.notFound`. Published with
  /// every message quoting it.
  DwCallHandler.command<EditChatMessage, ChatMessage>(
    access: DwAccessRule.resource<EditChatMessage, ChatMessageRow>(
      load: (ctx, command) => ctx.staffChatMessage(command.messageId),
      // The whole permission: `visible` only picks the refusal.
      allows: (ctx, command, row) async =>
          await ctx.isStaff && row.authorProfileId == (await ctx.profile).id,
      visible: (ctx, command, row) => ctx.isStaff,
    ),
    handle: (ctx, command) async {
      final me = await ctx.profile;
      final row = ctx.accessed<ChatMessageRow>();
      if (ctx.now.isAfter(row.sentAt.add(ChatMessage.editWindow))) {
        ctx.refuse(DartwayExampleRefusal.editWindowClosed);
      }
      final text = command.text.trim();
      if (text.isEmpty &&
          !await ctx.db.chatMessageAttachments.exists(
            where: (t) => t.messageId.equals(row.id),
          )) {
        ctx.refuse(DartwayExampleRefusal.messageEmpty, field: 'text');
      }
      final edited = await ctx.db.chatMessages.update(
        row.copyWith(text: text, editedAt: DwFieldPatch.set(ctx.now)),
      );
      final message = (await ChatObjects.messages(ctx, [
        edited,
      ], author: me)).single;
      ctx.publish(AppChannels.chatOf(edited.channelId), message);
      await ChatPublications.quoting(ctx, edited);
      return message;
    },
  ),

  /// Deletes a message. Staff only: its author or an admin; other staff are
  /// refused `dw.forbidden`, anyone else `dw.notFound`. Gone from its channel;
  /// the messages quoting it and the unread counts follow.
  DwCallHandler.command<DeleteChatMessage, void>(
    access: DwAccessRule.resource<DeleteChatMessage, ChatMessageRow>(
      load: (ctx, command) => ctx.staffChatMessage(command.messageId),
      allows: (ctx, command, row) async =>
          await ctx.isStaff &&
          (row.authorProfileId == (await ctx.profile).id || await ctx.isAdmin),
      visible: (ctx, command, row) => ctx.isStaff,
    ),
    handle: (ctx, command) async {
      final row = ctx.accessed<ChatMessageRow>();
      final deleted = await ctx.db.chatMessages.update(
        row.copyWith(deletedAt: DwFieldPatch.set(ctx.now)),
      );
      ctx.publish(
        AppChannels.chatOf(deleted.channelId),
        DwDeletedObject.of<ChatMessage>(deleted.id, ctx.protocol),
      );
      await ChatPublications.quoting(ctx, deleted);
      // Someone who had not read it counts one message fewer.
      await ChatPublications.readStates(ctx, deleted.channelId);
    },
  ),

  /// Pins or unpins a message. Staff only; published on its channel.
  DwCallHandler.command<PinChatMessage, ChatMessage>(
    access: ProfileAccess.staff,
    handle: (ctx, command) async {
      final me = await ctx.profile;
      final row = await ctx.requireChatMessage(command.messageId, lock: true);
      // Pinning a pinned message keeps when it was pinned, and by whom.
      final saved = command.pinned == (row.pinnedAt != null)
          ? row
          : await ctx.db.chatMessages.update(
              command.pinned
                  ? row.copyWith(
                      pinnedAt: DwFieldPatch.set(ctx.now),
                      pinnedByProfileId: DwFieldPatch.set(me.id),
                    )
                  : row.copyWith(
                      pinnedAt: const DwFieldPatch.clear(),
                      pinnedByProfileId: const DwFieldPatch.clear(),
                    ),
            );
      final message = (await ChatObjects.messages(ctx, [saved])).single;
      ctx.publish(AppChannels.chatOf(saved.channelId), message);
      return message;
    },
  ),

  /// Sets or clears the caller's reaction to a message. Staff only; published
  /// on its channel.
  DwCallHandler.command<ReactToChatMessage, ChatMessage>(
    access: ProfileAccess.staff,
    handle: (ctx, command) async {
      final me = await ctx.profile;
      final row = await ctx.requireChatMessage(command.messageId);
      // A double tap sends two commands at once: without the lock both
      // delete nothing and both insert, and the unique pair refuses one of
      // them as a database error. Under it the second sees the first's
      // reaction and replaces it.
      await ctx.db.advisoryLock(_reactionLocks, row.id.toSigned(32));
      await ctx.db.chatMessageReactions.deleteWhere(
        where: (t) => t.messageId.equals(row.id) & t.profileId.equals(me.id),
      );
      if (command.reaction case final reaction?) {
        await ctx.db.chatMessageReactions.insert(
          NewChatMessageReactionRow(
            messageId: row.id,
            profileId: me.id,
            reaction: reaction,
          ),
        );
      }
      final message = (await ChatObjects.messages(ctx, [row])).single;
      ctx.publish(AppChannels.chatOf(row.channelId), message);
      return message;
    },
  ),
];
