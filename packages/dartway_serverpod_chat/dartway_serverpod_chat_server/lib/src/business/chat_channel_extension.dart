import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';

extension ChatChannelExtension on Session {
  Future<DwChatParticipant> joinChatChannel({
    required int chatChannelId,
    required int userId,
    // required bool sendUpdate,
  }) async {
    // try {
    return await db.insertRow(
      DwChatParticipant(userId: userId, chatChannelId: chatChannelId),
    );
    // } on DatabaseException catch (e) {
    //   log(
    //     'Failed to join chat $chatChannelId with user $userId',
    //     level: LogLevel.error,
    //     exception: e,
    //   );
    //   return null;
    // }
  }

  // Future<ChatParticipant> leaveChatChannel({
  //   required int chatChannelId,
  // }) async {
  //   final userId = await currentUserId;
  //   if (userId == null) {
  //     return null;
  //   }
  //   // try {
  //     return await db.deleteRow(
  //       ChatParticipant(userId: userId, chatChannelId: chatChannelId),
  //     );
  //   // } on DatabaseException catch (e) {
  //   //   log(
  //   //     'Failed to leave chat $chatChannelId with user $userId',
  //   //     level: LogLevel.error,
  //   //     exception: e,
  //   //   );
  //   //   return null;
  //   // }
  // }

  Future<DwChatChannel> createChatChannel({
    required String channel,
    bool withCurrentUser = true,
    List<int>? withOtherUserIds,
    // bool sendUpdatesToCurrentUser = false,
    // bool sendUpdatesToOtherUsers = true,
  }) async {
    final chatChannel = await db.insertRow(DwChatChannel(channel: channel));
    final userId = await currentUserProfileId;

    chatChannel.chatParticipants = [
      if (withCurrentUser && userId != null)
        await joinChatChannel(chatChannelId: chatChannel.id!, userId: userId),
      if (withOtherUserIds != null) ...[
        for (var id in withOtherUserIds)
          await joinChatChannel(chatChannelId: chatChannel.id!, userId: id),
      ],
    ];

    return chatChannel;

    // for (var id in [
    //   if (withCurrentUser && currentUserId != null) currentUserId,
    //   if (withOtherUserIds != null) ...withOtherUserIds,
    // ]) {}
  }
}
