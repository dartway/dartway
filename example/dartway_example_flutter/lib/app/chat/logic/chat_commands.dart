import 'package:dartway_example_flutter/core/dw_core.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';

/// The commands the staff chat sends. The changed message comes back in the
/// answer and on its channel: nothing here, or in the widgets, adds it to a
/// list by hand.
abstract final class ChatCommands {
  /// Sends [text] to [channelId], replying to [replyTo] when set, with the
  /// files the member uploaded for it.
  static Future<DwCallResult<ChatMessage>> send(
    int channelId,
    String text, {
    ChatMessage? replyTo,
    List<ChatAttachmentDraft> attachments = const [],
  }) => dw.command(
    SendChatMessage(
      channelId: channelId,
      text: text,
      replyToMessageId: replyTo?.id,
      attachments: attachments,
    ),
  );

  /// Rewrites the member's own [message] as [text], within its edit window.
  static Future<DwCallResult<ChatMessage>> edit(
    ChatMessage message,
    String text,
  ) => dw.command(EditChatMessage(messageId: message.id, text: text));

  /// Toggles the member's [reaction] to [message]: the one they already gave
  /// ([mine]) is taken back, any other replaces it.
  static Future<DwCallResult<ChatMessage>> react(
    ChatMessage message,
    ChatReaction reaction, {
    required ChatReaction? mine,
  }) => dw.command(
    ReactToChatMessage(
      messageId: message.id,
      reaction: reaction == mine ? null : reaction,
    ),
  );

  /// Pins [message], or unpins it, for the whole team.
  static Future<DwCallResult<ChatMessage>> pin(
    ChatMessage message, {
    required bool pinned,
  }) => dw.command(PinChatMessage(messageId: message.id, pinned: pinned));

  /// Deletes [message]: its author's own, or anyone's for an admin.
  static Future<DwCallResult<void>> delete(ChatMessage message) =>
      dw.command(DeleteChatMessage(messageId: message.id));
}
