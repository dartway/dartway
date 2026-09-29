import 'package:dartway_core_server/testing.dart';
import 'package:dartway_example_server/dartway_example_server.dart';
import 'package:dartway_example_server/src/chat/chat_rows.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';

import 'app_harness.dart';

/// The staff chat seen from a test: channels and messages written straight
/// into the database, and the matchers the chat tests read in.
extension ChatHarness on AppHarness {
  Future<ChatChannelRow> chatChannel(String title) =>
      db.chatChannels.insert(NewChatChannelRow(title: title));
}

extension ChatMemberCalls on AppMember {
  Future<ChatMessage> send(
    int channelId,
    String text, {
    int? replyTo,
    List<ChatAttachmentDraft> attachments = const [],
  }) async => (await client.command(
    SendChatMessage(
      channelId: channelId,
      text: text,
      replyToMessageId: replyTo,
      attachments: attachments,
    ),
  )).valueOrThrow;
}

/// The items of a window watch, newest first.
List<ChatMessage> itemsOf(DwWindowWatch<ChatMessage> window) =>
    dataOf(window.state)?.items ?? const [];
