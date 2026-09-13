import 'package:dartway_orm/dartway_orm.dart';

part 'content.dw.dart';

@DwTable('news_post', indexes: [DwIndex(['createdAt'])])
final class NewsPost extends DwEntity with _$NewsPost {
  const NewsPost({
    this.id,
    required this.authorProfileId,
    required this.title,
    required this.text,
    required this.createdAt,
  });

  @override
  final int? id;

  @DwReferences('user_profile', onDelete: DwOnDelete.cascade)
  final int authorProfileId;

  final String title;
  final String text;
  final DateTime createdAt;

  static const table = NewsPostTable();
}

@DwTable('chat_channel')
final class ChatChannel extends DwEntity with _$ChatChannel {
  const ChatChannel({this.id, required this.title});

  @override
  final int? id;
  final String title;

  static const table = ChatChannelTable();
}

@DwTable('chat_message', indexes: [DwIndex(['channelId', 'id'])])
final class ChatMessage extends DwEntity with _$ChatMessage {
  const ChatMessage({
    this.id,
    required this.channelId,
    required this.authorProfileId,
    required this.text,
    required this.createdAt,
  });

  @override
  final int? id;

  @DwReferences('chat_channel', onDelete: DwOnDelete.cascade)
  final int channelId;

  @DwReferences('user_profile', onDelete: DwOnDelete.cascade)
  final int authorProfileId;

  final String text;
  final DateTime createdAt;

  static const table = ChatMessageTable();
}

@DwTable('app_setting')
final class AppSetting extends DwEntity with _$AppSetting {
  const AppSetting({this.id, required this.key, required this.value});

  @override
  final int? id;

  @DwUnique()
  final String key;

  final String value;

  static const table = AppSettingTable();
}
