import 'package:dartway_core_server/dartway_core_server.dart';

part 'content.dw.dart';

@DwSqlTable(
  'news_post',
  indexes: [
    DwTableIndex(['createdAt']),
  ],
)
final class NewsPostRow extends DwTableRow with _$NewsPostRow {
  const NewsPostRow({
    this.id,
    required this.authorProfileId,
    required this.title,
    required this.text,
    required this.createdAt,
  });

  @override
  final int? id;

  @DwForeignKey('user_profile', onDelete: DwOnDelete.cascade)
  final int authorProfileId;

  final String title;
  final String text;
  final DateTime createdAt;

  static const table = NewsPostTable();
}

@DwSqlTable('chat_channel')
final class ChatChannelRow extends DwTableRow with _$ChatChannelRow {
  const ChatChannelRow({this.id, required this.title});

  @override
  final int? id;
  final String title;

  static const table = ChatChannelTable();
}

/// The window over a channel reads by `(channelId, createdAt, id)` in both
/// directions; the index serves each read as one range scan.
@DwSqlTable(
  'chat_message',
  indexes: [
    DwTableIndex(['channelId', 'createdAt', 'id']),
  ],
)
final class ChatMessageRow extends DwTableRow with _$ChatMessageRow {
  const ChatMessageRow({
    this.id,
    required this.channelId,
    required this.authorProfileId,
    required this.text,
    required this.createdAt,
  });

  @override
  final int? id;

  @DwForeignKey('chat_channel', onDelete: DwOnDelete.cascade)
  final int channelId;

  @DwForeignKey('user_profile', onDelete: DwOnDelete.cascade)
  final int authorProfileId;

  final String text;
  final DateTime createdAt;

  static const table = ChatMessageTable();
}

@DwSqlTable('app_setting')
final class AppSettingRow extends DwTableRow with _$AppSettingRow {
  const AppSettingRow({this.id, required this.key, required this.value});

  @override
  final int? id;

  @DwUniqueColumn()
  final String key;

  final String value;

  static const table = AppSettingTable();
}
