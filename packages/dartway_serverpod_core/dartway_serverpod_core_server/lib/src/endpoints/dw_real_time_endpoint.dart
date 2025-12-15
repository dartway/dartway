import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:serverpod/serverpod.dart';

class DwRealTimeEndpoint extends Endpoint {
  static userUpdatesChannel(int userId) => 'userUpdates$userId';

  @override
  Future<void> streamOpened(StreamingSession session) async {
    final userId = await session.currentUserProfileId;

    if (userId == null) {
      return;
    }

    final channel = userUpdatesChannel(userId);

    setUserObject(session, channel);

    session.log('Subscribing to channel $channel');

    session.messages.addListener(
      channel,
      (update) => _listener(session, update),
    );
  }

  _listener(StreamingSession session, SerializableModel update) {
    // We expect that everything is already wrapped the right way
    sendStreamMessage(session, update);
  }

  @override
  Future<void> streamClosed(StreamingSession session) async {
    final channel = getUserObject(session);

    if (channel != null) {
      session.messages.removeListener(
        getUserObject(session),
        (update) => _listener(session, update),
      );
    }
  }
}
