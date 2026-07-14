import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:serverpod/serverpod.dart';

// You generally don't need any new endpoints for DartWay development
// But you can add them if you need to - for some special cases or for easier testing
// This is a simple example of how to add a new endpoint

class DevelopmentEndpoint extends Endpoint {
  Future<void> testNotification(
    Session session, {
    String notificationText = 'Test notification',
  }) async {
    final userId = await session.currentUserProfileId;

    if (userId == null) {
      throw Exception('User not found');
    }

    await session.sendUpdatesToUser(
      userId,
      updatedModels: [
        DwAppNotification(
          toUserId: userId,
          title: 'Test notification',
          body: notificationText,
        ),
      ],
    );
  }
}
