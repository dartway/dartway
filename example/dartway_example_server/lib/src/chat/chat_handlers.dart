import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';

import '../../generated/dw_schema.dart';
import 'chat_objects.dart';
import 'chat_publications.dart';
import 'chat_rows.dart';
import '../profile/profile_rows.dart';
import '../core/channels.dart';
import '../core/call_context.dart';

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
  /// The chat channels, by title. Staff only.
  DwCallHandler.list<ListChatChannels, ChatChannel>(
    access: AppAccess.staff,
    handle: (ctx, request) async => [
      for (final row in await ctx.db.chatChannels.find(
        orderBy: (t) => [t.title.asc(), t.id.asc()],
      ))
        ChatObjects.channel(row),
    ],
  ),

  /// The caller's read state of every channel. Staff only.
  DwCallHandler.list<ListMyChatReadStates, ChatReadState>(
    access: AppAccess.staff,
    handle: (ctx, request) async =>
        ChatObjects.readStates(ctx.db, (await ctx.profile).id!),
  ),

  /// A window over a channel's messages, deleted ones left out. Staff only; a
  /// channel that does not exist is `dw.notFound`.
  DwCallHandler.window<ListChatMessages, ChatMessage, DateTime, int>(
    access: AppAccess.staff,
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
      return ChatObjects.messages(ctx, rows);
    },
  ),

  /// A channel's pinned messages, newest first. Staff only.
  DwCallHandler.list<ListPinnedChatMessages, ChatMessage>(
    access: AppAccess.staff,
    handle: (ctx, request) async {
      final rows = await ctx.db.chatMessages.find(
        where: (t) =>
            t.channelId.equals(request.channelId) &
            t.pinnedAt.isNotNull() &
            t.deletedAt.isNull(),
        orderBy: (t) => [t.sentAt.desc(), t.id.desc()],
      );
      if (rows.isEmpty) await ctx._requireChannel(request.channelId);
      return ChatObjects.messages(ctx, rows);
    },
  ),

  /// A channel's messages whose text or author matches the query. Staff only.
  DwCallHandler.list<ListChatMessagesMatching, ChatMessage>(
    access: AppAccess.staff,
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
      return ChatObjects.messages(ctx, rows);
    },
  ),

  /// Sends a message, with the caller's own unsent uploads attached. Staff
  /// only. Published on its channel; moves the sender's read position and
  /// everyone's unread counts.
  DwCallHandler.command<SendChatMessage, ChatMessage>(
    access: AppAccess.staff,
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
      await ctx._moveReadForward(me.id!, row);

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
      load: (ctx, command) => ctx._staffMessage(command.messageId),
      // The whole permission: `visible` only picks the refusal.
      allows: (ctx, command, row) async =>
          await ctx.isStaff && row.authorProfileId == (await ctx.profile).id,
      visible: (ctx, command, row) => ctx.isStaff,
    ),
    handle: (ctx, command) async {
      final me = await ctx.profile;
      final row = ctx.accessed<ChatMessageRow>();
      if (DateTime.now().isAfter(row.sentAt.add(ChatMessage.editWindow))) {
        ctx.refuse(DartwayExampleRefusal.editWindowClosed);
      }
      final text = command.text.trim();
      if (text.isEmpty &&
          !await ctx.db.chatMessageAttachments.exists(
            where: (t) => t.messageId.equals(row.id!),
          )) {
        ctx.refuse(DartwayExampleRefusal.messageEmpty, field: 'text');
      }
      final edited = await ctx.db.chatMessages.update(
        row.copyWith(text: text, editedAt: DwFieldPatch.set(DateTime.now())),
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
      load: (ctx, command) => ctx._staffMessage(command.messageId),
      allows: (ctx, command, row) async =>
          await ctx.isStaff &&
          (row.authorProfileId == (await ctx.profile).id || await ctx.isAdmin),
      visible: (ctx, command, row) => ctx.isStaff,
    ),
    handle: (ctx, command) async {
      final row = ctx.accessed<ChatMessageRow>();
      final deleted = await ctx.db.chatMessages.update(
        row.copyWith(deletedAt: DwFieldPatch.set(DateTime.now())),
      );
      ctx.publish(
        AppChannels.chatOf(deleted.channelId),
        DwDeletedObject.of<ChatMessage>(deleted.id!, ctx.protocol),
      );
      await ChatPublications.quoting(ctx, deleted);
      // Someone who had not read it counts one message fewer.
      await ChatPublications.readStates(ctx, deleted.channelId);
    },
  ),

  /// Pins or unpins a message. Staff only; published on its channel.
  DwCallHandler.command<PinChatMessage, ChatMessage>(
    access: AppAccess.staff,
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
      final message = (await ChatObjects.messages(ctx, [saved])).single;
      ctx.publish(AppChannels.chatOf(saved.channelId), message);
      return message;
    },
  ),

  /// Sets or clears the caller's reaction to a message. Staff only; published
  /// on its channel.
  DwCallHandler.command<ReactToChatMessage, ChatMessage>(
    access: AppAccess.staff,
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
      final message = (await ChatObjects.messages(ctx, [row])).single;
      ctx.publish(AppChannels.chatOf(row.channelId), message);
      return message;
    },
  ),

  /// Moves the caller's read position forward to a message. Staff only;
  /// published to the caller's other devices.
  DwCallHandler.command<MarkChatRead, ChatReadState>(
    access: AppAccess.staff,
    handle: (ctx, command) async {
      final me = await ctx.profile;
      final message = await ctx.db.chatMessages.findById(command.messageId);
      if (message == null || message.channelId != command.channelId) {
        ctx.refuse(DwCoreRefusal.notFound);
      }
      await ctx._moveReadForward(me.id!, message);
      final state = await ChatObjects.readStateIn(
        ctx.db,
        me.id!,
        command.channelId,
      );
      // The caller's other devices: their unread badges follow.
      ctx.publish(AppChannels.chatReadsOf(me.ownerAccountId), state);
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
  Future<ChatMessageRow> _requireMessage(
    int messageId, {
    bool lock = false,
  }) async =>
      await _liveMessage(messageId, lock: lock) ??
      refuse(DwCoreRefusal.notFound);

  /// The message [messageId], locked for a change, to staff; `null` — and no
  /// lock taken — for anyone else, or when there is none or it is deleted.
  Future<ChatMessageRow?> _staffMessage(int messageId) async =>
      await isStaff ? await _liveMessage(messageId, lock: true) : null;

  /// The message [messageId], or `null` when there is none or it is deleted.
  /// With [lock], held until the command commits: edits, deletions and pins of
  /// one message queue instead of overwriting each other's row.
  Future<ChatMessageRow?> _liveMessage(
    int messageId, {
    bool lock = false,
  }) async {
    final row = await db.chatMessages.findById(
      messageId,
      lock: lock ? DwRowLock.forUpdate : null,
    );
    return row == null || row.isDeleted ? null : row;
  }

  /// Moves [profileId]'s position in [message]'s channel forward to
  /// [message]; a message at or before the position changes nothing.
  ///
  /// Two statements and no read-then-write: the insert skips an existing
  /// row (waiting for a concurrent insert of the same pair to commit), and
  /// the update's condition is checked again against the locked row — so two
  /// marks racing each other leave the newer of the two, whatever the order
  /// they commit in.
  Future<void> _moveReadForward(int profileId, ChatMessageRow message) async {
    final inserted = await db.chatReadPositions.tryInsert(
      ChatReadPositionRow(
        profileId: profileId,
        channelId: message.channelId,
        messageId: message.id!,
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
              (t.sentAt.equals(message.sentAt) & t.messageId.lt(message.id!))),
      set: (t) => [t.messageId.set(message.id!), t.sentAt.set(message.sentAt)],
    );
  }
}
