import 'dart:async';

import 'package:dartway_serverpod_core_client/dartway_serverpod_core_client.dart';
import 'package:dartway_serverpod_core_flutter/src/app/socket/service/dw_channel_subscriptions.dart';
import 'package:flutter_test/flutter_test.dart';

class ChannelUpdate implements SerializableModel {
  @override
  Map<String, dynamic> toJson() => {'update': true};
}

/// A channel subscription outlives the connection that carries it. The streams
/// die with the socket — on an unstable network, repeatedly — and what the app
/// asked to follow has to survive that and be reopened, or realtime goes quiet
/// for the rest of the session with nothing in the logs to say so.
void main() {
  late List<String> openedChannels;
  late Map<String, StreamController<SerializableModel>> channelControllers;
  late List<SerializableModel> receivedUpdates;
  late DwChannelSubscriptions channelSubscriptions;

  setUp(() {
    openedChannels = [];
    channelControllers = {};
    receivedUpdates = [];

    channelSubscriptions = DwChannelSubscriptions(
      openChannelStream: (channelName) {
        openedChannels.add(channelName);
        final controller = StreamController<SerializableModel>();
        channelControllers[channelName] = controller;
        return controller.stream;
      },
      onUpdate: receivedUpdates.add,
    );
  });

  test('opens nothing until the connection is up', () async {
    channelSubscriptions.request('userUpdates1');

    expect(openedChannels, isEmpty);
    expect(channelSubscriptions.requestedChannels, ['userUpdates1']);

    await channelSubscriptions.handleConnected();

    expect(openedChannels, ['userUpdates1']);
  });

  test('reopens the requested channels after a reconnect', () async {
    channelSubscriptions.request('userUpdates1');
    await channelSubscriptions.handleConnected();

    // The socket dies: the stream ends and the connection goes down.
    await channelControllers['userUpdates1']!.close();
    channelSubscriptions.handleDisconnected();
    expect(channelSubscriptions.liveChannels, isEmpty);

    await channelSubscriptions.handleConnected();

    expect(openedChannels, ['userUpdates1', 'userUpdates1']);
    expect(channelSubscriptions.liveChannels, ['userUpdates1']);
  });

  test('reopens a channel whose stream never reported its end', () async {
    channelSubscriptions.request('userUpdates1');
    await channelSubscriptions.handleConnected();

    // Reconnect without the previous stream ever completing — its `onDone` may
    // land late or not at all when the socket is dropped mid-flight.
    await channelSubscriptions.handleConnected();

    expect(openedChannels, ['userUpdates1', 'userUpdates1']);
    expect(channelSubscriptions.liveChannels, ['userUpdates1']);
  });

  test('delivers channel updates while the stream is live', () async {
    final update = ChannelUpdate();

    channelSubscriptions.request('userUpdates1');
    await channelSubscriptions.handleConnected();
    channelControllers['userUpdates1']!.add(update);
    await pumpEventQueue();

    expect(receivedUpdates, [update]);
  });

  test('opens one stream when the same channel is requested twice', () async {
    channelSubscriptions.request('userUpdates1');
    channelSubscriptions.request('userUpdates1');
    await channelSubscriptions.handleConnected();
    channelSubscriptions.request('userUpdates1');

    expect(openedChannels, ['userUpdates1']);
  });

  test('does not reopen a released channel', () async {
    channelSubscriptions.request('userUpdates1');
    channelSubscriptions.request('userUpdates2');
    await channelSubscriptions.handleConnected();

    await channelSubscriptions.release('userUpdates1');
    await channelSubscriptions.handleConnected();

    expect(channelSubscriptions.requestedChannels, ['userUpdates2']);
    expect(channelSubscriptions.liveChannels, ['userUpdates2']);
  });

  test('forgets every channel when all are released', () async {
    channelSubscriptions.request('userUpdates1');
    channelSubscriptions.request('userUpdates2');
    await channelSubscriptions.handleConnected();

    await channelSubscriptions.releaseAll();
    await channelSubscriptions.handleConnected();

    expect(channelSubscriptions.requestedChannels, isEmpty);
    expect(channelSubscriptions.liveChannels, isEmpty);
  });
}
