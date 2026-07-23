// ignore_for_file: deprecated_member_use

import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:serverpod/serverpod.dart';

// TODO(serverpod-legacy-streams): This endpoint still uses Serverpod's
// deprecated streaming endpoint lifecycle. Keep it as-is while the app upgrade
// is in progress, then migrate it to streaming methods.
class DwRealTimeEndpoint extends Endpoint {
  static userUpdatesChannel(int userId) => 'userUpdates$userId';

  @override
  Future<void> streamOpened(StreamingSession session) async {
    final userId = await session.currentUserProfileId;

    if (userId == null) {
      return;
    }

    final channel = userUpdatesChannel(userId);

    session.log('Subscribing to channel $channel');

    void updatesListener(SerializableModel update) =>
        sendStreamMessage(session, update);

    session.messages.addListener(channel, updatesListener);

    // Teardown is kept on the session rather than in a map on the endpoint, and
    // `setUserObject` is not used to recover the channel in `streamClosed`.
    // This endpoint is a singleton that lives as long as the process, and
    // Serverpod never releases what `setUserObject` stores in
    // `Endpoint._userObjects` — so every authenticated connection would leave
    // its session there forever, keeping the socket, the request and the
    // buffered session log alive with it.
    session.addWillCloseListener(
      (closingSession) =>
          closingSession.messages.removeListener(channel, updatesListener),
    );
  }
}
