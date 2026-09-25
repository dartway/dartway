import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';

import '../../generated/dw_schema.dart';
import 'chat_rows.dart';

/// Read positions and unread counts of the staff chat.
abstract final class ChatReads {
  /// Moves [profileId]'s position in [message]'s channel forward to
  /// [message]; a message at or before the position changes nothing.
  ///
  /// Two statements and no read-then-write: the insert skips an existing
  /// row (waiting for a concurrent insert of the same pair to commit), and
  /// the update's condition is checked again against the locked row — so two
  /// marks racing each other leave the newer of the two, whatever the order
  /// they commit in.
  static Future<void> moveForward(
    DwDatabaseHandle db,
    int profileId,
    ChatMessageRow message,
  ) async {
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

  /// [profileId]'s read state of every channel, by channel id.
  static Future<List<ChatReadState>> ofMember(
    DwDatabaseHandle db,
    int profileId,
  ) async => [
    for (final (:state, accountId: _) in await _states(
      db,
      'p.id = @profile::int8',
      {'profile': profileId},
    ))
      state,
  ];

  /// [profileId]'s read state of [channelId].
  static Future<ChatReadState> ofMemberIn(
    DwDatabaseHandle db,
    int profileId,
    int channelId,
  ) async => (await _states(
    db,
    'p.id = @profile::int8 AND c.id = @channel::int8',
    {'profile': profileId, 'channel': channelId},
  )).single.state;

  /// Publishes every staff member's read state of [channelId] on their own
  /// chat reads channel: a message sent or deleted there moves the count of
  /// everyone who has not read past it.
  ///
  /// One statement for all of them, however many staff there are; a member
  /// whose count did not change hears the same state again, which their list
  /// applies as no change.
  static Future<void> publishChannel(DwCallContext ctx, int channelId) async {
    for (final (:accountId, :state) in await _states(
      ctx.db,
      'c.id = @channel::int8 AND p.role <> @client::text',
      {'channel': channelId, 'client': UserRole.client.name},
    )) {
      ctx.publish(
        DwLiveChannel.forAccount(ExampleChannel.chatReads, accountId),
        state,
      );
    }
  }

  /// Read states of the (member, channel) pairs [where] selects, `p` being
  /// the member's profile and `c` the channel.
  ///
  /// Raw SQL because the count is a correlated subquery per pair: messages
  /// of the channel after the position as the window orders them —
  /// `(sent_at, id)` compared as a row, which the `(channel_id, sent_at, id)`
  /// index answers as one range — not deleted and not the member's own.
  /// [where] is a constant of this file; values only ever come as [params].
  static Future<List<({int accountId, ChatReadState state})>> _states(
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
