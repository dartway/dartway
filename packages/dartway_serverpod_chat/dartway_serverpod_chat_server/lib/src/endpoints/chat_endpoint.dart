import 'package:dartway_serverpod_chat_server/dartway_serverpod_chat_server.dart';
import 'package:dartway_serverpod_chat_server/src/business/chat_session_extension.dart';
import 'package:dartway_serverpod_chat_server/src/crud/dw_chat_participant_config.dart';
import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:serverpod/serverpod.dart';

class ChatEndpoint extends Endpoint {
  static chatUpdatesChannel(int chatId) => 'chatUpdates$chatId';

  Stream<SerializableModel> updatesStream(
    Session session, {
    required int chatId,
  }) async* {
    final userId = await session.currentUserProfileId;

    if (userId == null) {
      return;
    }

    final stream = session.messages.createStream<SerializableModel>(
      chatUpdatesChannel(chatId),
    );

    final messages = await DwChatMessage.db.find(
      session,
      where: (t) => t.chatChannelId.equals(chatId) & t.isDeleted.equals(false),
      orderByList: (t) => [Order(column: t.sentAt)],
    );

    final participants = await DwChatParticipant.db.find(
      session,
      where: (t) => t.chatChannelId.equals(chatId),
    );

    final participantIds = participants.map((e) => e.userId).toSet();

    // TODO: implement attachments fetching
    // final initMedias = await Media.db.find(
    //   session,
    //   where: (t) => t.id.inSet(
    //     messages.expand((m) => (m.attachmentIds ?? <int>[])).toSet(),
    //   ),
    // );
    if (participantIds.isEmpty) {
      return;
    }

    yield DwChatInitialData(
      messages: messages,
      participantIds: participantIds.toList(),
      lastReadMessageId:
          participants
              .reduce(
                (a, b) =>
                    (a.lastReadMessageId ?? 0) > (b.lastReadMessageId ?? 0)
                        ? a
                        : b,
              )
              .lastReadMessageId, //TODO: для групповых чатов не будет работать эффект прочтения
      // TODO return additionalEntities
      // additionalEntities: [
      //   ...initMedias.map((e) => ObjectWrapper(object: e)),
      //   ...await ChatsConfig.additionalEntitiesLoaderForInitialChatData(
      //           session, participantIds)
      //       .then(
      //     (e) => e
      //         .map(
      //           (e) => ObjectWrapper(object: e),
      //         )
      //         .toList(),
      //   ),
      // ]
    );

    await for (var update in stream) {
      yield update;
      // yield update is TableRow ? ObjectWrapper.wrap(update)! : update;
    }

    // yield* session.messages.createStream<SerializableModel>(channel).map(
    //       (update) => update is TableRow ? ObjectWrapper.wrap(update)! : update,
    //     );
  }

  Future<void> readChatMessages(
    Session session,
    List<int> readMessageIds,
    int chatId,
  ) async {
    if (readMessageIds.isEmpty) {
      return;
    }

    final userId = await session.currentUserProfileId;

    readMessageIds.sort();
    final maxMessageId = readMessageIds.last;

    await session.dwSendToChat(
      chatId,
      DwChatReadMessageEvent(messageId: maxMessageId, userId: userId!),
    );

    final participant = await DwChatParticipant.db.findFirstRow(
      session,
      where: (p0) => p0.chatChannelId.equals(chatId) & p0.userId.equals(userId),
      include: chatParticipantInclude,
    );

    if (participant == null) {
      return;
    }

    final currentLastRead = participant.lastReadMessageId ?? 0;
    final newReadIds =
        readMessageIds.where((id) => id > currentLastRead).toList();

    if (newReadIds.isEmpty) {
      return;
    }

    participant.unreadCount = 0;

    participant.lastReadMessageId = newReadIds.last;

    await DwChatParticipant.db.updateRow(session, participant);

    session.sendUpdatesToUser(userId, updatedModels: [participant]);
  }

  Future<void> typingToggle(
    Session session,
    int channelId,
    bool isTyping,
  ) async {
    await session.dwSendToChat(
      channelId,
      DwChatTypingMessageEvent(
        userId: (await session.currentUserProfileId)!,
        isTyping: isTyping,
      ),
    );
  }

  // Future<void> sendCustomMessage(
  //   Session session,
  //   int chatId,
  //   CustomMessageType customMessageInfo,
  // ) async {
  //   session.nitSendToChat(chatId, update);
  // }
}
