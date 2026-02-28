import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:serverpod/serverpod.dart';

class DwRealTimeEndpoint extends Endpoint {
  static userUpdatesChannel(int userId) => 'userUpdates$userId';

  /// Stores the listener per session so we can remove it later with the
  /// exact same reference.
  final Map<StreamingSession, void Function(SerializableModel)>
      _sessionListeners = {};

  @override
  Future<void> streamOpened(StreamingSession session) async {
    final userId = await session.currentUserProfileId;

    if (userId == null) {
      return;
    }

    final channel = userUpdatesChannel(userId);

    setUserObject(session, channel);

    session.log('Subscribing to channel $channel');

    final listener = (SerializableModel update) {
      sendStreamMessage(session, update);
    };

    _sessionListeners[session] = listener;

    session.messages.addListener(channel, listener);
  }

  @override
  Future<void> streamClosed(StreamingSession session) async {
    final channel = getUserObject(session);
    final listener = _sessionListeners.remove(session);

    if (channel != null && listener != null) {
      session.messages.removeListener(channel, listener);
    }
  }
}
