import 'package:dartway_core_shared/dartway_core_shared.dart';

import 'example_channel.dart';
import 'example_refusal.dart';
import 'people.dart';

part 'chat.dw.dart';

/// The reactions a staff member can put on a message: one each, replaced by
/// the next one they choose.
enum ChatReaction { heart, fire, thumbsUp, thumbsDown, money }

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

  /// The window cursor of the read position ([ListChatMessages]), `null`
  /// before the first message was seen.
  String? get lastReadCursor => switch ((lastReadSentAt, lastReadMessageId)) {
    (final DateTime sentAt, final int id) => DwWindowCursor.encode(sentAt, id),
    _ => null,
  };
}

/// A message as quoted by a reply to it. A deleted message keeps its place
/// in the replies — the link stays, the text does not.
final class ChatMessageQuote extends DwDataObject with _$ChatMessageQuote {
  const ChatMessageQuote({
    required this.id,
    required this.sentAt,
    required this.authorName,
    required this.text,
    required this.isDeleted,
    this.hasAttachments = false,
  });

  /// The quoted message id.
  @override
  final int id;
  final DateTime sentAt;
  final String authorName;

  /// Empty for a deleted message.
  final String text;
  final bool isDeleted;
  final bool hasAttachments;
}

/// A file attached to a message. Private: read through a short-lived link
/// (`DwGetFileLink`) that only staff are given.
final class ChatAttachment extends DwDataObject with _$ChatAttachment {
  const ChatAttachment({
    required this.id,
    required this.fileName,
    required this.contentType,
    required this.byteSize,
    this.width,
    this.height,
  });

  /// The stored file id.
  @override
  final int id;
  final String fileName;
  final String contentType;
  final int byteSize;

  /// The picture's size in pixels, for an image: the chat lays the picture
  /// out before it has loaded, so nothing moves when it arrives.
  final int? width;
  final int? height;

  bool get isImage => contentType.startsWith('image/');
}

/// One member's reaction to a message. Its [id] is the member's profile id.
final class ChatMessageReaction extends DwDataObject
    with _$ChatMessageReaction {
  const ChatMessageReaction({required this.id, required this.reaction});

  /// The profile id of the member who reacted.
  @override
  final int id;
  final ChatReaction reaction;
}

final class ChatMessage extends DwDataObject with _$ChatMessage {
  const ChatMessage({
    required this.id,
    required this.channelId,
    required this.text,
    required this.author,
    required this.sentAt,
    this.editedAt,
    this.pinnedAt,
    this.replyTo,
    this.attachments = const [],
    this.reactions = const [],
  });

  /// How long after sending its author may still edit a message.
  static const Duration editWindow = Duration(hours: 24);

  /// The most attachments one message carries.
  static const int maxAttachments = 10;

  /// The longest text of a message, in characters.
  static const int maxTextLength = 4000;

  @override
  final int id;
  final int channelId;
  final String text;
  final PersonCard author;
  final DateTime sentAt;

  /// Set by the last edit.
  final DateTime? editedAt;

  /// Set while the message is pinned to its channel.
  final DateTime? pinnedAt;
  final ChatMessageQuote? replyTo;
  final List<ChatAttachment> attachments;

  /// Every member's reaction, not only the caller's: the chat counts them by
  /// kind and marks the caller's own.
  final List<ChatMessageReaction> reactions;

  bool get isPinned => pinnedAt != null;
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

/// The caller's read state of every channel, live on the caller's own chat
/// reads channel: a message sent anywhere moves the counts of everyone who
/// has not read it. Staff only.
final class ListMyChatReadStates extends DwListRequest<ChatReadState>
    with _$ListMyChatReadStates {
  const ListMyChatReadStates();

  @override
  List<DwLiveChannel> get channels => const [
    DwLiveChannel.ofCaller(ExampleChannel.chatReads),
  ];
}

/// A window over the messages of one channel, newest first: opened at the
/// newest messages or around one of them, and grown both ways.
///
/// The sequence is ordered by the time a message was sent, ties broken by
/// id — the same order the server reads in, since both build on
/// [positionOf]. A deleted message leaves the window. Staff only.
final class ListChatMessages extends DwWindowRequest<ChatMessage, DateTime, int>
    with _$ListChatMessages {
  const ListChatMessages({required this.channelId})
    : super(pageSize: 40, maxPageSize: 160);

  final int channelId;

  @override
  List<DwLiveChannel> get channels => [
    DwLiveChannel(ExampleChannel.staffChat, channelId),
  ];

  @override
  bool matches(ChatMessage item) => item.channelId == channelId;

  @override
  DwWindowPosition<DateTime, int> positionOf(ChatMessage item) =>
      (sortValue: item.sentAt, id: item.id);
}

/// The pinned messages of one channel, newest first. A message pinned or
/// unpinned anywhere in the history joins or leaves the list live: the pin
/// is published as the message itself. Staff only.
final class ListPinnedChatMessages extends DwListRequest<ChatMessage>
    with _$ListPinnedChatMessages {
  const ListPinnedChatMessages({required this.channelId});

  final int channelId;

  @override
  List<DwLiveChannel> get channels => [
    DwLiveChannel(ExampleChannel.staffChat, channelId),
  ];

  @override
  bool matches(ChatMessage item) =>
      item.channelId == channelId && item.isPinned;

  @override
  int Function(ChatMessage a, ChatMessage b) get sort => (a, b) {
    final bySent = b.sentAt.compareTo(a.sentAt);
    return bySent != 0 ? bySent : b.id.compareTo(a.id);
  };
}

/// The messages of one channel whose text contains [query], newest first, at
/// most [maxResults]. A snapshot, not live: a search is asked again when its
/// query changes. Staff only.
final class ListChatMessagesMatching extends DwListRequest<ChatMessage>
    with _$ListChatMessagesMatching
    implements DwSelfValidating {
  const ListChatMessagesMatching({required this.channelId, required this.query});

  static const int minQueryLength = 2;
  static const int maxResults = 100;

  final int channelId;
  final String query;

  @override
  List<DwCallRefusal> validate() => [
    if (query.trim().length < minQueryLength)
      DwCallRefusal(
        ExampleRefusal.searchQueryTooShort,
        field: 'query',
        params: {'min': minQueryLength},
      ),
  ];
}

/// A file uploaded for a message about to be sent, with the picture's size
/// when it is one. Its [id] is the stored file id.
final class ChatAttachmentDraft extends DwDataObject
    with _$ChatAttachmentDraft {
  const ChatAttachmentDraft({required this.id, this.width, this.height});

  /// The stored file id, uploaded by the caller for the chat attachment
  /// purpose.
  @override
  final int id;
  final int? width;
  final int? height;
}

/// Posts a message as the caller: text, attachments or both, optionally in
/// reply to another message of the channel. Staff only.
final class SendChatMessage extends DwActionCommand<ChatMessage>
    with _$SendChatMessage
    implements DwSelfValidating {
  const SendChatMessage({
    required this.channelId,
    required this.text,
    this.replyToMessageId,
    this.attachments = const [],
  });

  final int channelId;
  final String text;
  final int? replyToMessageId;
  final List<ChatAttachmentDraft> attachments;

  @override
  List<DwCallRefusal> validate() => [
    if (text.trim().isEmpty && attachments.isEmpty)
      DwCallRefusal(ExampleRefusal.messageEmpty, field: 'text'),
    if (text.length > ChatMessage.maxTextLength)
      DwCallRefusal(
        ExampleRefusal.messageTooLong,
        field: 'text',
        params: {'max': ChatMessage.maxTextLength},
      ),
    if (attachments.length > ChatMessage.maxAttachments)
      DwCallRefusal(
        ExampleRefusal.tooManyAttachments,
        field: 'attachments',
        params: {'max': ChatMessage.maxAttachments},
      ),
  ];
}

/// Replaces the text of one of the caller's own messages, within
/// [ChatMessage.editWindow] of sending it. A message with attachments may
/// lose its text; one without keeps some. Staff only.
final class EditChatMessage extends DwActionCommand<ChatMessage>
    with _$EditChatMessage
    implements DwSelfValidating {
  const EditChatMessage({required this.messageId, required this.text});

  final int messageId;
  final String text;

  @override
  List<DwCallRefusal> validate() => [
    if (text.length > ChatMessage.maxTextLength)
      DwCallRefusal(
        ExampleRefusal.messageTooLong,
        field: 'text',
        params: {'max': ChatMessage.maxTextLength},
      ),
  ];
}

/// Deletes a message: its author's own, or any as an admin. Replies keep
/// their quote of it, without the text.
final class DeleteChatMessage extends DwActionCommand<void>
    with _$DeleteChatMessage {
  const DeleteChatMessage({required this.messageId});

  final int messageId;
}

/// Pins a message to the top of its channel, or unpins it. Staff only.
final class PinChatMessage extends DwActionCommand<ChatMessage>
    with _$PinChatMessage {
  const PinChatMessage({required this.messageId, required this.pinned});

  final int messageId;
  final bool pinned;
}

/// Sets the caller's reaction to a message; `null` takes it back. Staff only.
final class ReactToChatMessage extends DwActionCommand<ChatMessage>
    with _$ReactToChatMessage {
  const ReactToChatMessage({required this.messageId, this.reaction});

  final int messageId;
  final ChatReaction? reaction;
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
