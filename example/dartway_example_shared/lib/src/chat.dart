import 'package:dartway_core/dartway_core.dart';

import 'example_channel.dart';
import 'people.dart';

part 'chat.dw.dart';

final class ChatChannelView extends DwDataObject with _$ChatChannelView {
  const ChatChannelView({required this.id, required this.title});

  @override
  final int id;
  final String title;
}

final class ChatMessageView extends DwDataObject with _$ChatMessageView {
  const ChatMessageView({
    required this.id,
    required this.channelId,
    required this.text,
    required this.author,
    required this.createdAt,
  });

  @override
  final int id;
  final int channelId;
  final String text;
  final PersonView author;
  final DateTime createdAt;
}

/// The staff chat channels. Staff only.
final class ListChatChannels extends DwListRequest<ChatChannelView>
    with _$ListChatChannels {
  const ListChatChannels();

  @override
  List<DwChannel> get channels => const [DwChannel(ExampleChannel.staffChannels)];
}

/// Messages of one channel, newest first, loaded backwards.
final class ListChatMessages extends DwCursorRequest<ChatMessageView>
    with _$ListChatMessages {
  const ListChatMessages({required this.channelId});

  final int channelId;

  @override
  int get pageSize => 40;

  @override
  List<DwChannel> get channels => [DwChannel(ExampleChannel.staffChat, channelId)];

  @override
  bool matches(ChatMessageView object) => object.channelId == channelId;
}

/// Posts a message as the caller. Staff only.
final class SendChatMessage extends DwCommand<ChatMessageView>
    with _$SendChatMessage {
  const SendChatMessage({required this.channelId, required this.text});

  final int channelId;
  final String text;
}
