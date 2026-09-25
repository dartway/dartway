import 'package:dartway_core_server/testing.dart';
import 'package:dartway_example_server/dartway_example_server.dart';
import 'package:dartway_example_server/src/chat/chat_rows.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';
import 'package:test/test.dart';

import 'club_harness.dart';

/// The staff chat seen from a test: channels and messages written straight
/// into the database, and the matchers the chat tests read in.
extension ChatHarness on ClubHarness {
  Future<ChatChannelRow> chatChannel(String title) =>
      db.chatChannels.insert(ChatChannelRow(title: title));

  /// A staff member: signed up through a real client, then promoted.
  Future<ClubMember> staff(String phone, String name) =>
      memberWithRole(phone, name, UserRole.staff);

  Future<ClubMember> admin(String phone, String name) =>
      memberWithRole(phone, name, UserRole.admin);

  /// [member]'s profile id: what a message names as its author.
  Future<int> profileIdOf(ClubMember member) async =>
      (await db.userProfiles.findFirst(
        where: (t) => t.accountId.equals(member.accountId),
      ))!.id!;
}

extension ChatMemberCalls on ClubMember {
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

/// A call refused with [code].
Matcher refusedWith(DwRefusalCode code) => isA<DwCallRefused<Object?>>().having(
  (r) => r.refusal.code,
  'refusal code',
  code.code,
);

/// The items of a window watch, newest first.
List<ChatMessage> itemsOf(DwWindowWatch<ChatMessage> window) =>
    dataOf(window.state)?.items ?? const [];
