import 'package:dartway_example_shared/dartway_example_shared.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// What the composer of a channel is doing besides writing — shared by the
/// message menu, which starts a reply or an edit, and the composer, which
/// shows it and ends it.
///
/// Held by the channel's body for as long as the channel is on screen.
final chatComposingProvider = NotifierProvider.autoDispose
    .family<ChatComposingController, ChatComposing, int>(
      ChatComposingController.new,
    );

/// Starts and ends a reply or an edit in channel [channelId]; one at a time.
class ChatComposingController extends Notifier<ChatComposing> {
  ChatComposingController(this.channelId);

  final int channelId;

  @override
  ChatComposing build() => const ChatComposing();

  void startReply(ChatMessage message) =>
      state = ChatComposing(replyTo: message);

  void startEdit(ChatMessage message) =>
      state = ChatComposing(editing: message);

  /// Back to writing a new message.
  void clear() => state = const ChatComposing();
}

/// The message the composer answers, or the one it edits; neither when
/// writing a new message.
final class ChatComposing {
  const ChatComposing({this.replyTo, this.editing});

  final ChatMessage? replyTo;
  final ChatMessage? editing;
}
