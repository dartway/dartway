import 'package:serverpod/serverpod.dart';

import '../endpoints/chat_endpoint.dart';

extension DwChatSessionExtension on Session {
  Future<void> dwSendToChat(int chatId, SerializableModel update) async {
    await messages.postMessage(
      ChatEndpoint.chatUpdatesChannel(chatId),
      update,
    );
  }
}
