import 'package:dartway_core_shared/dartway_core_shared.dart';
import 'package:dartway_example_shared/src/dartway_example_channel.dart';

part 'chat_channels.dw.dart';

final class ChatChannel extends DwDataObject with _$ChatChannel {
  const ChatChannel({required this.id, required this.title});

  @override
  final int id;
  final String title;
}

/// Where the caller stopped reading one channel, and how many messages came
/// after it. Its [id] is the channel's.
///
/// The position is the last message the caller has seen, as the chat window
/// orders messages — its time sent and id — so the chat reopens at it
/// ([lastReadCursor]) and counts what is newer.
final class ChatReadState extends DwDataObject with _$ChatReadState {
  const ChatReadState({
    required this.id,
    required this.unreadCount,
    this.lastReadMessageId,
    this.lastReadSentAt,
  });

  /// The channel id.
  @override
  final int id;

  /// Messages newer than the read position, the caller's own excluded.
  final int unreadCount;

  /// `null` until the caller has seen a message of the channel.
  final int? lastReadMessageId;

  /// When [lastReadMessageId] was sent.
  final DateTime? lastReadSentAt;

  /// The window cursor of the read position (`ListChatMessages`), `null`
  /// before the first message was seen.
  String? get lastReadCursor => switch ((lastReadSentAt, lastReadMessageId)) {
    (final DateTime sentAt, final int id) => DwWindowCursor.encode(sentAt, id),
    _ => null,
  };
}


/// The staff chat channels. Staff only.
final class ListChatChannels extends DwListRequest<ChatChannel>
    with _$ListChatChannels {
  const ListChatChannels();

  @override
  List<DwLiveChannel> get channels => const [
    DwLiveChannel(DartwayExampleChannel.staffChannels),
  ];
}

/// The caller's read state of every channel, live on the caller's own chat
/// reads channel: a message sent anywhere moves the counts of everyone who
/// has not read it. Staff only.
final class ListMyChatReadStates extends DwListRequest<ChatReadState>
    with _$ListMyChatReadStates {
  const ListMyChatReadStates();

  @override
  List<DwLiveChannel> get channels => const [
    DwLiveChannel.ofCaller(DartwayExampleChannel.chatReads),
  ];
}


/// Moves the caller's read position in a channel forward to [messageId].
/// A message older than the position changes nothing: the position never
/// moves back. Staff only.
final class MarkChatRead extends DwActionCommand<ChatReadState>
    with _$MarkChatRead {
  const MarkChatRead({required this.channelId, required this.messageId});

  final int channelId;
  final int messageId;
}
