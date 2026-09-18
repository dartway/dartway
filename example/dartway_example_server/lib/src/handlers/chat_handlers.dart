import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';

import '../../generated/dw_schema.dart';
import '../chat/chat_objects.dart';
import '../chat/chat_reads.dart';
import '../entities/chat.dart';
import '../entities/people.dart';
import '../example_channels.dart';
import '../example_context.dart';

/// Advisory lock namespace of reactions: the first key of the two-key lock,
/// the message id the second.
const int _reactionLocks = 0x43480001;

/// The staff chat: channels, a window over each channel's messages, pins,
/// reactions, read positions and search. Every call is staff only.
///
/// What changes a message is published as the message itself on its channel,
/// so the window and the pinned list each decide by `matches` whether it is
/// theirs. A message that quotes a changed one is republished too: its quote
/// is part of it.
final chatHandlers = <DwCallHandler>[
  DwCallHandler.list<ListChatChannels, ChatChannel>(
    access: ExampleAccess.staff,
    handle: (ctx, request) async => [
      for (final row in await ctx.db.chatChannels.find(
        orderBy: (t) => [t.title.asc(), t.id.asc()],
      ))
        ChatObjects.channel(row),
    ],
  ),

  DwCallHandler.list<ListMyChatReadStates, ChatReadState>(
    access: ExampleAccess.staff,
    handle: (ctx, request) async =>
        ChatReads.ofMember(ctx.db, (await ctx.profile).id!),
  ),

  DwCallHandler.window<ListChatMessages, ChatMessage, DateTime, int>(
    access: ExampleAccess.staff,
    handle: (ctx, request, window) async {
      final position = window.position;
      final older = window.direction == DwWindowDirection.older;
      final rows = await ctx.db.chatMessages.find(
        where: (t) {
          final inChannel =
              t.channelId.equals(request.channelId) & t.deletedAt.isNull();
          if (position == null) return inChannel;
          final (:sortValue, :id) = position;
          // `(sentAt, id)` compared as a pair. The bound on `sentAt` alone is
          // what the index range scan starts from; the pair decides among
          // messages sent at the same instant.
          return older
              ? inChannel &
                    t.sentAt.lte(sortValue) &
                    (t.sentAt.lt(sortValue) |
                        (window.includesPosition ? t.id.lte(id) : t.id.lt(id)))
              : inChannel &
                    t.sentAt.gte(sortValue) &
                    (t.sentAt.gt(sortValue) | t.id.gt(id));
        },
        orderBy: (t) => older
            ? [t.sentAt.desc(), t.id.desc()]
            : [t.sentAt.asc(), t.id.asc()],
        limit: window.fetchLimit,
      );
      // Only an empty read asks whether the channel exists: a channel with
      // messages plainly does, and the question costs a query per read.
      if (rows.isEmpty && position == null) {
        await ctx._requireChannel(request.channelId);
      }
      return ChatObjects.messages(ctx.db, rows);
    },
  ),

  DwCallHandler.list<ListPinnedChatMessages, ChatMessage>(
    access: ExampleAccess.staff,
    handle: (ctx, request) async {
      final rows = await ctx.db.chatMessages.find(
        where: (t) =>
            t.channelId.equals(request.channelId) &
            t.pinnedAt.isNotNull() &
            t.deletedAt.isNull(),
        orderBy: (t) => [t.sentAt.desc(), t.id.desc()],
      );
      if (rows.isEmpty) await ctx._requireChannel(request.channelId);
      return ChatObjects.messages(ctx.db, rows);
    },
  ),

  DwCallHandler.list<ListChatMessagesMatching, ChatMessage>(
    access: ExampleAccess.staff,
    handle: (ctx, request) async {
      // LIKE's own characters in what was typed are matched literally.
      final pattern =
          '%${request.query.trim().replaceAllMapped(RegExp(r'[\\%_]'), (m) => '\\${m[0]}')}%';
      // Authors by name first, once: the messages are then one query on
      // their own table, by text or by one of these authors.
      final authors = [
        for (final row in await ctx.db.userProfiles.find(
          where: (t) => t.firstName.ilike(pattern) | t.lastName.ilike(pattern),
        ))
          row.id!,
      ];
      final rows = await ctx.db.chatMessages.find(
        where: (t) {
          final matching = authors.isEmpty
              ? t.text.ilike(pattern)
              : t.text.ilike(pattern) | t.authorProfileId.inList(authors);
          return t.channelId.equals(request.channelId) &
              t.deletedAt.isNull() &
              matching;
        },
        orderBy: (t) => [t.sentAt.desc(), t.id.desc()],
        limit: ListChatMessagesMatching.maxResults,
      );
      return ChatObjects.messages(ctx.db, rows);
    },
  ),

  DwCallHandler.command<SendChatMessage, ChatMessage>(
    access: ExampleAccess.staff,
    handle: (ctx, command) async {
      final me = await ctx.profile;
      await ctx._requireChannel(command.channelId);
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
          ExampleUpload.chatAttachment,
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
        ChatMessageRow(
          channelId: command.channelId,
          authorProfileId: me.id!,
          text: command.text.trim(),
          sentAt: DateTime.now(),
          replyToMessageId: command.replyToMessageId,
        ),
      );
      try {
        await ctx.db.chatMessageAttachments.insertAll([
          for (final (position, draft) in drafts.indexed)
            ChatMessageAttachmentRow(
              messageId: row.id!,
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
      await ChatReads.moveForward(ctx.db, me.id!, row);

      final message = (await ChatObjects.messages(ctx.db, [
        row,
      ], author: me)).single;
      ctx.publish(ExampleChannels.chatOf(row.channelId), message);
      await ChatReads.publishChannel(ctx, row.channelId);
      return message;
    },
  ),

  DwCallHandler.command<EditChatMessage, ChatMessage>(
    access: ExampleAccess.staff,
    handle: (ctx, command) async {
      final me = await ctx.profile;
      final row = await ctx._requireMessage(command.messageId, lock: true);
      if (row.authorProfileId != me.id) ctx.refuse(DwCoreRefusal.forbidden);
      if (DateTime.now().isAfter(row.sentAt.add(ChatMessage.editWindow))) {
        ctx.refuse(ExampleRefusal.editWindowClosed);
      }
      final text = command.text.trim();
      if (text.isEmpty &&
          !await ctx.db.chatMessageAttachments.exists(
            where: (t) => t.messageId.equals(row.id!),
          )) {
        ctx.refuse(ExampleRefusal.messageEmpty, field: 'text');
      }
      final edited = await ctx.db.chatMessages.update(
        row.copyWith(text: text, editedAt: DwFieldPatch.set(DateTime.now())),
      );
      final message = (await ChatObjects.messages(ctx.db, [
        edited,
      ], author: me)).single;
      ctx.publish(ExampleChannels.chatOf(edited.channelId), message);
      await ctx._publishQuoting(edited);
      return message;
    },
  ),

  DwCallHandler.command<DeleteChatMessage, void>(
    access: ExampleAccess.staff,
    handle: (ctx, command) async {
      final me = await ctx.profile;
      final row = await ctx._requireMessage(command.messageId, lock: true);
      if (row.authorProfileId != me.id && !await ctx.isAdmin) {
        ctx.refuse(DwCoreRefusal.forbidden);
      }
      final deleted = await ctx.db.chatMessages.update(
        row.copyWith(deletedAt: DwFieldPatch.set(DateTime.now())),
      );
      ctx.publish(
        ExampleChannels.chatOf(deleted.channelId),
        DwDeletedObject.of<ChatMessage>(deleted.id!, ctx.protocol),
      );
      await ctx._publishQuoting(deleted);
      // Someone who had not read it counts one message fewer.
      await ChatReads.publishChannel(ctx, deleted.channelId);
    },
  ),

  DwCallHandler.command<PinChatMessage, ChatMessage>(
    access: ExampleAccess.staff,
    handle: (ctx, command) async {
      final me = await ctx.profile;
      final row = await ctx._requireMessage(command.messageId, lock: true);
      // Pinning a pinned message keeps when it was pinned, and by whom.
      final saved = command.pinned == (row.pinnedAt != null)
          ? row
          : await ctx.db.chatMessages.update(
              command.pinned
                  ? row.copyWith(
                      pinnedAt: DwFieldPatch.set(DateTime.now()),
                      pinnedByProfileId: DwFieldPatch.set(me.id!),
                    )
                  : row.copyWith(
                      pinnedAt: const DwFieldPatch.clear(),
                      pinnedByProfileId: const DwFieldPatch.clear(),
                    ),
            );
      final message = (await ChatObjects.messages(ctx.db, [saved])).single;
      ctx.publish(ExampleChannels.chatOf(saved.channelId), message);
      return message;
    },
  ),

  DwCallHandler.command<ReactToChatMessage, ChatMessage>(
    access: ExampleAccess.staff,
    handle: (ctx, command) async {
      final me = await ctx.profile;
      final row = await ctx._requireMessage(command.messageId);
      // A double tap sends two commands at once: without the lock both
      // delete nothing and both insert, and the unique pair refuses one of
      // them as a database error. Under it the second sees the first's
      // reaction and replaces it.
      await ctx.db.advisoryLock(_reactionLocks, row.id!.toSigned(32));
      await ctx.db.chatMessageReactions.deleteWhere(
        where: (t) => t.messageId.equals(row.id!) & t.profileId.equals(me.id!),
      );
      if (command.reaction case final reaction?) {
        await ctx.db.chatMessageReactions.insert(
          ChatMessageReactionRow(
            messageId: row.id!,
            profileId: me.id!,
            reaction: reaction,
          ),
        );
      }
      final message = (await ChatObjects.messages(ctx.db, [row])).single;
      ctx.publish(ExampleChannels.chatOf(row.channelId), message);
      return message;
    },
  ),

  DwCallHandler.command<MarkChatRead, ChatReadState>(
    access: ExampleAccess.staff,
    handle: (ctx, command) async {
      final me = await ctx.profile;
      final message = await ctx.db.chatMessages.findById(command.messageId);
      if (message == null || message.channelId != command.channelId) {
        ctx.refuse(DwCoreRefusal.notFound);
      }
      await ChatReads.moveForward(ctx.db, me.id!, message);
      final state = await ChatReads.ofMemberIn(
        ctx.db,
        me.id!,
        command.channelId,
      );
      // The caller's other devices: their unread badges follow.
      ctx.publish(
        DwLiveChannel.forAccount(ExampleChannel.chatReads, me.ownerAccountId),
        state,
      );
      return state;
    },
  ),
];

extension on DwCallContext {
  Future<void> _requireChannel(int channelId) async {
    if (!await db.chatChannels.exists(where: (t) => t.id.equals(channelId))) {
      refuse(DwCoreRefusal.notFound);
    }
  }

  /// The message [messageId] unless it is deleted; otherwise `dw.notFound`.
  /// With [lock], held until the command commits: edits, deletions and pins of
  /// one message queue instead of overwriting each other's row.
  Future<ChatMessageRow> _requireMessage(
    int messageId, {
    bool lock = false,
  }) async {
    final row = await db.chatMessages.findById(
      messageId,
      lock: lock ? DwRowLock.forUpdate : null,
    );
    if (row == null || row.isDeleted) refuse(DwCoreRefusal.notFound);
    return row;
  }

  /// Republishes the live messages that quote [quoted]: their quote changed
  /// with it — its text, or that it is deleted.
  Future<void> _publishQuoting(ChatMessageRow quoted) async {
    final replies = await db.chatMessages.find(
      where: (t) => t.replyToMessageId.equals(quoted.id) & t.deletedAt.isNull(),
    );
    for (final reply in await ChatObjects.messages(db, replies)) {
      publish(ExampleChannels.chatOf(reply.channelId), reply);
    }
  }
}
