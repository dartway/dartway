import 'dart:async';

import 'package:dartway_serverpod_core_client/dartway_serverpod_core_client.dart';
import 'package:dartway_serverpod_core_flutter/src/app/socket/domain/dw_socket_status.dart';
import 'package:dartway_serverpod_core_flutter/src/app/socket/service/dw_channel_subscriptions.dart';
import 'package:flutter_test/flutter_test.dart';

class ChannelUpdate implements SerializableModel {
  @override
  Map<String, dynamic> toJson() => {'update': true};
}

/// A channel subscription outlives the connection that carries it. The streams
/// die with the socket — on an unstable network, repeatedly — and what the app
/// asked to follow has to survive that and be opened again, or realtime goes
/// quiet for the rest of the session with nothing in the logs to say so.
///
/// Nothing else reopens them: Serverpod's method-stream client fails every open
/// stream when the socket dies and then stops, and the connection handler that
/// used to retry belongs to the streaming API this replaced.
void main() {
  late List<String> openedChannels;
  late Map<String, StreamController<SerializableModel>> channelControllers;
  late List<SerializableModel> receivedUpdates;
  late List<DwSocketStatus> statusChanges;
  late List<(String, DwChannelClosedReason)> closedByServer;
  late DwChannelSubscriptions channelSubscriptions;

  /// Short enough to keep the suite quick, long enough that a retry never
  /// races the assertion that precedes it.
  const retryDelay = Duration(milliseconds: 20);

  /// Lets the retry timer fire and its streams open.
  Future<void> waitForRetry() async {
    await Future<void>.delayed(retryDelay * 3);
    await pumpEventQueue();
  }

  setUp(() {
    openedChannels = [];
    channelControllers = {};
    receivedUpdates = [];
    statusChanges = [];
    closedByServer = [];

    channelSubscriptions = DwChannelSubscriptions(
      openChannelStream: (channelName) {
        openedChannels.add(channelName);
        final controller = StreamController<SerializableModel>();
        channelControllers[channelName] = controller;
        return controller.stream;
      },
      onUpdate: receivedUpdates.add,
      onStatusChanged: statusChanges.add,
      onChannelClosedByServer: (channel, reason) =>
          closedByServer.add((channel, reason)),
      retryDelay: retryDelay,
    );
  });

  test('opens nothing until the app is started', () async {
    channelSubscriptions.request('userUpdates1');

    expect(openedChannels, isEmpty);
    expect(channelSubscriptions.requestedChannels, ['userUpdates1']);

    channelSubscriptions.start();

    expect(openedChannels, ['userUpdates1']);
  });

  test('opens a channel requested after the start', () {
    channelSubscriptions.start();
    channelSubscriptions.request('userUpdates1');

    expect(openedChannels, ['userUpdates1']);
    expect(channelSubscriptions.liveChannels, ['userUpdates1']);
  });

  test('reopens a channel whose stream the socket took down', () async {
    channelSubscriptions.start();
    channelSubscriptions.request('userUpdates1');

    // The socket dies: the stream ends without an error of its own.
    await channelControllers['userUpdates1']!.close();
    await pumpEventQueue();
    expect(channelSubscriptions.liveChannels, isEmpty);

    await waitForRetry();

    expect(openedChannels, ['userUpdates1', 'userUpdates1']);
    expect(channelSubscriptions.liveChannels, ['userUpdates1']);
  });

  test('reopens a channel whose stream failed to connect', () async {
    channelSubscriptions.start();
    channelSubscriptions.request('userUpdates1');

    channelControllers['userUpdates1']!.addError(
      const WebSocketClosedException(),
    );
    await pumpEventQueue();
    expect(channelSubscriptions.liveChannels, isEmpty);

    await waitForRetry();

    expect(openedChannels, ['userUpdates1', 'userUpdates1']);
  });

  test('keeps retrying while the network stays down', () async {
    channelSubscriptions.start();
    channelSubscriptions.request('userUpdates1');

    for (var attempt = 0; attempt < 3; attempt++) {
      channelControllers['userUpdates1']!.addError(
        const WebSocketConnectException('offline'),
      );
      await pumpEventQueue();
      await waitForRetry();
    }

    // The first open plus one per failure: the loop never gives up on its own.
    expect(openedChannels, hasLength(4));
  });

  test('does not reopen a channel the server refused', () async {
    channelSubscriptions.start();
    channelSubscriptions.request('secretUpdates1');

    channelControllers['secretUpdates1']!.addError(
      DwChannelClosed(
        channel: 'secretUpdates1',
        reason: DwChannelClosedReason.notAllowed,
      ),
    );
    await pumpEventQueue();
    await waitForRetry();

    expect(openedChannels, ['secretUpdates1']);
    expect(channelSubscriptions.requestedChannels, isEmpty);
    expect(closedByServer, [
      ('secretUpdates1', DwChannelClosedReason.notAllowed),
    ]);
  });

  test('reports a subscription closed by revocation', () async {
    channelSubscriptions.start();
    channelSubscriptions.request('userUpdates1');

    channelControllers['userUpdates1']!.addError(
      DwChannelClosed(
        channel: 'userUpdates1',
        reason: DwChannelClosedReason.authenticationRevoked,
      ),
    );
    await pumpEventQueue();
    await waitForRetry();

    expect(openedChannels, ['userUpdates1']);
    expect(closedByServer, [
      ('userUpdates1', DwChannelClosedReason.authenticationRevoked),
    ]);
  });

  test('delivers channel updates while the stream is live', () async {
    final update = ChannelUpdate();

    channelSubscriptions.start();
    channelSubscriptions.request('userUpdates1');
    channelControllers['userUpdates1']!.add(update);
    await pumpEventQueue();

    expect(receivedUpdates, [update]);
  });

  test('opens one stream when the same channel is requested twice', () {
    channelSubscriptions.request('userUpdates1');
    channelSubscriptions.request('userUpdates1');
    channelSubscriptions.start();
    channelSubscriptions.request('userUpdates1');

    expect(openedChannels, ['userUpdates1']);
  });

  test('does not reopen a released channel', () async {
    channelSubscriptions.start();
    channelSubscriptions.request('userUpdates1');
    channelSubscriptions.request('userUpdates2');

    await channelSubscriptions.release('userUpdates1');
    await waitForRetry();

    expect(channelSubscriptions.requestedChannels, ['userUpdates2']);
    expect(channelSubscriptions.liveChannels, ['userUpdates2']);
  });

  test('forgets every channel when all are released', () async {
    channelSubscriptions.start();
    channelSubscriptions.request('userUpdates1');
    channelSubscriptions.request('userUpdates2');

    await channelSubscriptions.releaseAll();
    await waitForRetry();

    expect(channelSubscriptions.requestedChannels, isEmpty);
    expect(channelSubscriptions.liveChannels, isEmpty);
    expect(channelSubscriptions.status, DwSocketStatus.idle);
  });

  group('reopenAll', () {
    test('opens every requested channel on a fresh stream', () async {
      channelSubscriptions.start();
      channelSubscriptions.request('dwPublicUpdates');
      channelSubscriptions.request('chat:12');

      await channelSubscriptions.reopenAll();

      // A stream carries the authentication it was opened with, so an account
      // switch has to reopen the app's channels rather than keep them.
      expect(openedChannels, [
        'dwPublicUpdates',
        'chat:12',
        'dwPublicUpdates',
        'chat:12',
      ]);
      expect(channelSubscriptions.liveChannels, ['dwPublicUpdates', 'chat:12']);
    });

    test('closes the streams it replaces', () async {
      channelSubscriptions.start();
      channelSubscriptions.request('dwPublicUpdates');
      final previousStream = channelControllers['dwPublicUpdates']!;

      await channelSubscriptions.reopenAll();

      expect(previousStream.hasListener, isFalse);
    });
  });

  group('status', () {
    test('is idle with nothing subscribed', () {
      channelSubscriptions.start();

      expect(channelSubscriptions.status, DwSocketStatus.idle);
      expect(statusChanges, isEmpty);
    });

    test('follows the subscriptions through a blip and back', () async {
      channelSubscriptions.start();
      channelSubscriptions.request('userUpdates1');
      expect(statusChanges, [DwSocketStatus.connected]);

      channelControllers['userUpdates1']!.addError(
        const WebSocketClosedException(),
      );
      await pumpEventQueue();
      expect(statusChanges, [
        DwSocketStatus.connected,
        DwSocketStatus.waitingToRetry,
      ]);

      await waitForRetry();

      expect(statusChanges, [
        DwSocketStatus.connected,
        DwSocketStatus.waitingToRetry,
        DwSocketStatus.connected,
      ]);
    });

    test('is idle again once the last channel is released', () async {
      channelSubscriptions.start();
      channelSubscriptions.request('userUpdates1');
      await channelSubscriptions.release('userUpdates1');

      expect(statusChanges.last, DwSocketStatus.idle);
    });
  });
}
