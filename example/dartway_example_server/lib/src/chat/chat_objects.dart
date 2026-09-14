import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';

import '../../generated/dw_schema.dart';
import '../club_objects.dart';
import '../entities/chat.dart';
import '../entities/people.dart';

/// Chat rows → the data objects staff see. Like `ClubObjects`: every relation
/// of a batch is one query — authors, quoted messages, attachments, their
/// files, reactions — whatever the number of messages.
abstract final class ChatObjects {
  static ChatChannel channel(ChatChannelRow row) =>
      ChatChannel(id: row.id!, title: row.title);

  /// [rows] must not be deleted messages: a deleted message leaves every
  /// list, and is announced as `DwDeletedObject` instead. [author] is the
  /// author of every row, when the caller holds it.
  static Future<List<ChatMessage>> messages(
    DwDatabaseHandle db,
    List<ChatMessageRow> rows, {
    UserProfileRow? author,
  }) async {
    if (rows.isEmpty) return const [];
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
    final files = await storedFiles(db, [
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
          author: ClubObjects.person(authors[row.authorProfileId]!),
          sentAt: row.sentAt,
          editedAt: row.editedAt,
          pinnedAt: row.pinnedAt,
          replyTo: switch (quoted[row.replyToMessageId]) {
            final quote? => ChatMessageQuote(
              id: quote.id!,
              sentAt: quote.sentAt,
              authorName: _nameOf(authors[quote.authorProfileId]!),
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

  /// Name, content type and size of the confirmed stored files among
  /// [fileIds], in one query.
  ///
  /// Read from the framework's `dw_stored_file` directly: `ctx.files` answers
  /// for one file at a time (`requireOwned`), and a page of messages needs
  /// the files of all its attachments at once.
  static Future<Map<int, StoredFileFacts>> storedFiles(
    DwDatabaseHandle db,
    Iterable<int> fileIds,
  ) async {
    final ids = fileIds.toSet().toList();
    if (ids.isEmpty) return const {};
    return {
      for (final row in await db.query(
        'SELECT id, file_name, content_type, byte_size FROM dw_stored_file '
        'WHERE id = ANY(@ids::int8[]) AND confirmed_at IS NOT NULL',
        params: {'ids': ids},
      ))
        row.get<int>('id'): (
          fileName: row.get<String>('file_name'),
          contentType: row.get<String>('content_type'),
          byteSize: row.get<int>('byte_size'),
        ),
    };
  }

  static String _nameOf(UserProfileRow profile) => switch (profile.lastName) {
    final last? when last.isNotEmpty => '${profile.firstName} $last',
    _ => profile.firstName,
  };
}

/// What a message shows of a stored file.
typedef StoredFileFacts = ({String fileName, String contentType, int byteSize});
