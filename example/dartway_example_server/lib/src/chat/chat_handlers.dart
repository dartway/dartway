import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_example_server/generated/dw_schema.dart';
import 'package:dartway_example_server/src/chat/chat_objects.dart';
import 'package:dartway_example_server/src/chat/logic/chat_lookups.dart';
import 'package:dartway_example_server/src/core/channels.dart';
import 'package:dartway_example_server/src/profile/profile_access.dart';
import 'package:dartway_example_server/src/profile/profile_rows.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';

/// The staff chat's reads — channels, a window over each channel's messages,
/// pins and search — and read positions. Every call is staff only; what
/// changes a message is `chatMessagesHandlers`.
///
/// What changes a message is published as the message itself on its channel,
/// so the window and the pinned list each decide by `matches` whether it is
/// theirs. A message that quotes a changed one is republished too: its quote
/// is part of it.
final chatHandlers = <DwCallHandler>[
  /// The chat channels, by title. Staff only.
  DwCallHandler.list<ListChatChannels, ChatChannel>(
    access: ProfileAccess.staff,
    handle: (ctx, request) async => [
      for (final row in await ctx.db.chatChannels.find(
        orderBy: (t) => [t.title.asc(), t.id.asc()],
      ))
        ChatObjects.channel(row),
    ],
  ),

  /// The caller's read state of every channel. Staff only.
  DwCallHandler.list<ListMyChatReadStates, ChatReadState>(
    access: ProfileAccess.staff,
    handle: (ctx, request) async =>
        ChatObjects.readStates(ctx.db, (await ctx.profile).id),
  ),

  /// A window over a channel's messages, deleted ones left out. Staff only; a
  /// channel that does not exist is `dw.notFound`.
  DwCallHandler.window<ListChatMessages, ChatMessage, DateTime, int>(
    access: ProfileAccess.staff,
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
        await ctx.requireChatChannel(request.channelId);
      }
      return ChatObjects.messages(ctx, rows);
    },
  ),

  /// A channel's pinned messages, newest first. Staff only.
  DwCallHandler.list<ListPinnedChatMessages, ChatMessage>(
    access: ProfileAccess.staff,
    handle: (ctx, request) async {
      final rows = await ctx.db.chatMessages.find(
        where: (t) =>
            t.channelId.equals(request.channelId) &
            t.pinnedAt.isNotNull() &
            t.deletedAt.isNull(),
        orderBy: (t) => [t.sentAt.desc(), t.id.desc()],
      );
      if (rows.isEmpty) await ctx.requireChatChannel(request.channelId);
      return ChatObjects.messages(ctx, rows);
    },
  ),

  /// A channel's messages whose text or author matches the query. Staff only.
  DwCallHandler.list<ListChatMessagesMatching, ChatMessage>(
    access: ProfileAccess.staff,
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
          row.id,
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

  /// Moves the caller's read position forward to a message. Staff only;
  /// published to the caller's other devices.
  DwCallHandler.command<MarkChatRead, ChatReadState>(
    access: ProfileAccess.staff,
    handle: (ctx, command) async {
      final me = await ctx.profile;
      final message = await ctx.db.chatMessages.findById(command.messageId);
      if (message == null || message.channelId != command.channelId) {
        ctx.refuse(DwCoreRefusal.notFound);
      }
      await ctx.moveChatReadForward(me.id, message);
      final state = await ChatObjects.readStateIn(
        ctx.db,
        me.id,
        command.channelId,
      );
      // The caller's other devices: their unread badges follow.
      ctx.publish(AppChannels.chatReadsOf(me.ownerAccountId), state);
      return state;
    },
  ),
];
