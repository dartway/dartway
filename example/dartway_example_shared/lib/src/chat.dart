import 'package:dartway_core_shared/dartway_core_shared.dart';

import 'example_channel.dart';
import 'example_refusal.dart';
import 'people.dart';

part 'chat.dw.dart';

final class ChatChannel extends DwDataObject with _$ChatChannel {
  const ChatChannel({required this.id, required this.title});

  @override
  final int id;
  final String title;
}

final class ChatMessage extends DwDataObject with _$ChatMessage {
  const ChatMessage({
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
  final PersonCard author;
  final DateTime createdAt;
}

/// The staff chat channels. Staff only.
final class ListChatChannels extends DwListRequest<ChatChannel>
    with _$ListChatChannels {
  const ListChatChannels();

  @override
  List<DwLiveChannel> get channels => const [
    DwLiveChannel(ExampleChannel.staffChannels),
  ];
}

/// A window over the messages of one channel, newest first: opened at the
/// newest messages or around one of them, and grown both ways.
///
/// The sequence is ordered by the time a message was sent, ties broken by
/// id — the same order the server reads in, since both build on
/// [positionOf]. Staff only.
final class ListChatMessages extends DwWindowRequest<ChatMessage, DateTime, int>
    with _$ListChatMessages {
  const ListChatMessages({required this.channelId})
    : super(pageSize: 30, maxPageSize: 150);

  final int channelId;

  @override
  List<DwLiveChannel> get channels => [
    DwLiveChannel(ExampleChannel.staffChat, channelId),
  ];

  @override
  bool matches(ChatMessage item) => item.channelId == channelId;

  @override
  DwWindowPosition<DateTime, int> positionOf(ChatMessage item) =>
      (sortValue: item.createdAt, id: item.id);
}

/// Posts a message as the caller. Staff only.
final class SendChatMessage extends DwActionCommand<ChatMessage>
    with _$SendChatMessage
    implements DwSelfValidating {
  const SendChatMessage({required this.channelId, required this.text});

  final int channelId;
  final String text;

  @override
  List<DwCallRefusal> validate() => [
    if (text.trim().isEmpty)
      DwCallRefusal(ExampleRefusal.messageEmpty, field: 'text'),
  ];
}
