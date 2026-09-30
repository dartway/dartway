import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_example_server/generated/dw_schema.dart';
import 'package:dartway_example_server/src/chat/chat_rows.dart';
import 'package:dartway_example_server/src/profile/profile_objects.dart';
import 'package:dartway_example_server/src/profile/profile_rows.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';

/// Chat rows → the data objects staff see. Every relation
/// of a batch is one query — authors, quoted messages, attachments, their
/// files, reactions — whatever the number of messages.
abstract final class ChatObjects {
  static ChatChannel channel(ChatChannelRow row) =>
      ChatChannel(id: row.id!, title: row.title);

  /// [rows] must not be deleted messages: a deleted message leaves every
  /// list, and is announced as `DwDeletedObject` instead. [author] is the
  /// author of every row, when the caller holds it.
  static Future<List<ChatMessage>> messages(
    DwCallContext ctx,
    List<ChatMessageRow> rows, {
    UserProfileRow? author,
  }) async {
    if (rows.isEmpty) return const [];
    final db = ctx.db;
    final ids = [for (final row in rows) row.id!];

    final quoted = {
      for (final row in await db.chatMessages.findByIds(
        rows.map((m) => m.replyToMessageId).whereType<int>(),
      ))
        row.id!: row,
    };

    final wantedAuthors = {
      for (final row in rows) row.authorProfileId,
      for (final row in quoted.values) row.authorProfileId,
    };
    if (author != null) wantedAuthors.remove(author.id);
    // An empty set asks nothing of the database.
    final authors = {
      for (final row in await db.userProfiles.findByIds(wantedAuthors))
        row.id!: row,
    };
    if (author != null) authors[author.id!] = author;

    // The quotes' attachments only tell whether a quote has any; they are
    // read in the same query as the messages' own.
    final attachmentRows = await db.chatMessageAttachments.find(
      where: (t) => t.messageId.inList({...ids, ...quoted.keys}),
      orderBy: (t) => [t.messageId.asc(), t.position.asc()],
    );
    final ownIds = ids.toSet();
    // Name, type and size of every attached file, in one query.
    final files = await ctx.files.describe([
      for (final a in attachmentRows)
        if (ownIds.contains(a.messageId)) a.fileId,
    ]);
    final attachments = <int, List<ChatAttachment>>{};
    final quotedWithAttachments = <int>{};
    for (final row in attachmentRows) {
      quotedWithAttachments.add(row.messageId);
      if (!ownIds.contains(row.messageId)) continue;
      // Absent only when the file went between the two reads: the attachment
      // row goes with it (cascade), so it is not shown.
      final file = files[row.fileId];
      if (file == null) continue;
      (attachments[row.messageId] ??= []).add(
        ChatAttachment(
          id: row.fileId,
          fileName: file.fileName,
          contentType: file.contentType,
          byteSize: file.byteSize,
          width: row.width,
          height: row.height,
        ),
      );
    }

    final reactions = <int, List<ChatMessageReaction>>{};
    for (final row in await db.chatMessageReactions.find(
      where: (t) => t.messageId.inList(ids),
      orderBy: (t) => [t.id.asc()],
    )) {
      (reactions[row.messageId] ??= []).add(
        ChatMessageReaction(id: row.profileId, reaction: row.reaction),
      );
    }

    return [
      for (final row in rows)
        ChatMessage(
          id: row.id!,
          channelId: row.channelId,
          text: row.text,
          author: ProfileObjects.person(authors[row.authorProfileId]!),
          sentAt: row.sentAt,
          editedAt: row.editedAt,
          pinnedAt: row.pinnedAt,
          replyTo: switch (quoted[row.replyToMessageId]) {
            final quote? => ChatMessageQuote(
              id: quote.id!,
              sentAt: quote.sentAt,
              authorName: _nameOf(authors[quote.authorProfileId]!),
              authorDeleted: authors[quote.authorProfileId]!.deletedAt != null,
              text: quote.isDeleted ? '' : quote.text,
              isDeleted: quote.isDeleted,
              hasAttachments:
                  !quote.isDeleted && quotedWithAttachments.contains(quote.id),
            ),
            null => null,
          },
          attachments: attachments[row.id] ?? const [],
          reactions: reactions[row.id] ?? const [],
        ),
    ];
  }

  static String _nameOf(UserProfileRow profile) => switch (profile.lastName) {
    final last? when last.isNotEmpty => '${profile.firstName} $last',
    _ => profile.firstName,
  };

  /// [profileId]'s read state of every channel, by channel id.
  static Future<List<ChatReadState>> readStates(
    DwDatabaseHandle db,
    int profileId,
  ) async => [
    for (final (:state, accountId: _) in await _readStates(
      db,
      'p.id = @profile::int8',
      {'profile': profileId},
    ))
      state,
  ];

  /// [profileId]'s read state of [channelId].
  static Future<ChatReadState> readStateIn(
    DwDatabaseHandle db,
    int profileId,
    int channelId,
  ) async => (await _readStates(
    db,
    'p.id = @profile::int8 AND c.id = @channel::int8',
    {'profile': profileId, 'channel': channelId},
  )).single.state;

  /// Every staff member's read state of [channelId], with their account.
  static Future<List<({int accountId, ChatReadState state})>> staffReadStatesIn(
    DwDatabaseHandle db,
    int channelId,
  ) => _readStates(db, 'c.id = @channel::int8 AND p.role <> @client::text', {
    'channel': channelId,
    'client': UserRole.client.name,
  });

  /// Read states of the (member, channel) pairs [where] selects, with each
  /// member's account, `p` being
  /// the member's profile and `c` the channel.
  ///
  /// Raw SQL because the count is a correlated subquery per pair: messages
  /// of the channel after the position as the window orders them —
  /// `(sent_at, id)` compared as a row, which the `(channel_id, sent_at, id)`
  /// index answers as one range — not deleted and not the member's own.
  /// [where] is a constant of this class; values only ever come as [params].
  static Future<List<({int accountId, ChatReadState state})>> _readStates(
    DwDatabaseHandle db,
    String where,
    Map<String, Object?> params,
  ) async => [
    for (final row in await db.query(
      'SELECT p.account_id, c.id AS channel_id, r.message_id, r.sent_at, '
      '(SELECT count(*) FROM chat_message m '
      'WHERE m.channel_id = c.id AND m.deleted_at IS NULL '
      'AND m.author_profile_id <> p.id '
      'AND (r.id IS NULL OR (m.sent_at, m.id) > (r.sent_at, r.message_id))'
      ') AS unread '
      'FROM user_profile p CROSS JOIN chat_channel c '
      'LEFT JOIN chat_read_position r '
      'ON r.profile_id = p.id AND r.channel_id = c.id '
      'WHERE $where ORDER BY p.id, c.id',
      params: params,
    ))
      (
        accountId: row.get<int>('account_id'),
        state: ChatReadState(
          id: row.get<int>('channel_id'),
          unreadCount: row.get<int>('unread'),
          lastReadMessageId: row['message_id'] as int?,
          lastReadSentAt: row['sent_at'] as DateTime?,
        ),
      ),
  ];
}
