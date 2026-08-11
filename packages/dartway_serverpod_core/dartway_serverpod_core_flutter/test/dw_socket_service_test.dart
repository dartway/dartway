import 'dart:async';

import 'package:dartway_serverpod_core_client/dartway_serverpod_core_client.dart';
import 'package:dartway_serverpod_core_flutter/src/app/socket/service/dw_socket_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Signing out reopens the app's channels: a method stream carries the
/// authentication it was opened with, so one that outlives the session it
/// belongs to keeps delivering into an app that no longer has a user.
///
/// Reopening them with no user is also how a `guarded` channel gets refused,
/// and that refusal used to be reported as a bug in the app's declarations —
/// an error dialog raised by the act of leaving, on the screen the sign-out
/// button lives on. The channel is public or it is not; who is asking is what
/// changed, and the app was told about it as though it had misconfigured
/// something.
void main() {
  /// A channel the app follows for as long as its screen is on-screen — the
  /// catalogue feed, the admin post list. Only these are affected: the user's
  /// own channel is dropped by name before anything is reopened.
  const appChannel = 'general_updates_channel';

  late List<String> openedChannels;
  late Map<String, StreamController<SerializableModel>> channelControllers;
  late List<Object> reportedErrors;
  late DwSocketService socketService;

  /// Lets the reopening — scheduled, not awaited — run to its refusal.
  Future<void> settle() => pumpEventQueue();

  void refuse(String channel) {
    channelControllers[channel]!.addError(
      DwChannelClosed(
        channel: channel,
        reason: DwChannelClosedReason.notAllowed,
      ),
    );
  }

  setUp(() {
    openedChannels = [];
    channelControllers = {};
    reportedErrors = [];

    socketService = DwSocketService(
      openChannelStream: (channel) {
        openedChannels.add(channel);
        final controller = StreamController<SerializableModel>();
        channelControllers[channel] = controller;
        return controller.stream;
      },
      reportError: (error, _) => reportedErrors.add(error),
    );

    socketService.init();
  });

  test('says nothing when signing out gets a channel refused', () async {
    socketService.onUserChanged(null, 7);
    await socketService.subscribeToChannel(appChannel);
    await settle();

    socketService.onUserChanged(7, null);
    await settle();

    // The channel was reopened by the sign-out and the server turned the
    // anonymous session away — the expected answer, not a report to raise.
    refuse(appChannel);
    await settle();

    expect(reportedErrors, isEmpty);
  });

  test('reports a refusal while somebody is signed in', () async {
    socketService.onUserChanged(null, 7);
    await socketService.subscribeToChannel(appChannel);
    await settle();

    refuse(appChannel);
    await settle();

    // Here the app really is at fault: an undeclared channel, or one this user
    // does not belong in. Staying quiet would leave a screen that silently
    // stopped updating and nothing to explain it.
    expect(reportedErrors, hasLength(1));
    expect(reportedErrors.single.toString(), contains(appChannel));
  });

  test('still reopens the app channels when the user signs out', () async {
    socketService.onUserChanged(null, 7);
    await socketService.subscribeToChannel(appChannel);
    await settle();
    openedChannels.clear();

    socketService.onUserChanged(7, null);
    await settle();

    // Quieter reporting is not permission to stop asking: a `public` channel
    // outlives the session, and it only stays live because it is opened again
    // against the server rather than assumed dead here.
    expect(openedChannels, contains(appChannel));
  });
}
