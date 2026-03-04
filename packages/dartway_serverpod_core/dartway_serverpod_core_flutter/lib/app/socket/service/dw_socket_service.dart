import 'dart:async';

import 'package:dartway_serverpod_core_client/dartway_serverpod_core_client.dart';
import 'package:dartway_serverpod_core_flutter/private/dw_singleton.dart';
import 'package:flutter/foundation.dart';

import '../../../repository/dw_repository.dart';

class DwSocketService {
  DwSocketService();

  // final ServerpodClientShared client;
  // final dynamic endpointCaller;

  StreamingConnectionHandler? _connectionHandler;
  StreamSubscription<SerializableModel>? _mainStreamSub;
  final Map<String, StreamSubscription<SerializableModel>> _channelSubs = {};

  final ValueNotifier<StreamingConnectionStatus> statusNotifier = ValueNotifier(
    StreamingConnectionStatus.disconnected,
  );

  void init() {
    _connectionHandler = StreamingConnectionHandler(
      client: dw.client,
      retryEverySeconds: 1,
      listener: (_) => _refresh(),
    );

    _connectionHandler!.connect();
  }

  Future<void> dispose() async {
    await _mainStreamSub?.cancel();
    _mainStreamSub = null;
    await unsubscribeAllChannels();
    _connectionHandler?.client.closeStreamingConnection();
    _connectionHandler = null;
  }

  void onUserChanged(int? previousUserId, int? nextUserId) {
    if (previousUserId != nextUserId) {
      _connectionHandler?.client.closeStreamingConnection();
      unsubscribeAllChannels();
    }
  }

  void _refresh() {
    final status =
        _connectionHandler?.status.status ??
        StreamingConnectionStatus.disconnected;

    if (status == StreamingConnectionStatus.connected) {
      _startMainStream();
    }

    statusNotifier.value = status;
  }

  void _processUpdatedModels(List<DwModelWrapper> updatedModels) {
    DwRepository.updateListeningStates(
      wrappedModelUpdates: updatedModels
          .where((e) => e.modelId != null)
          .toList(),
    );
  }

  void _processUpdate(SerializableModel update) {
    if (update is DwModelWrapper) {
      _processUpdatedModels([update]);
    } else if (update is DwUpdatesTransport) {
      _processUpdatedModels(update.wrappedModelUpdates);
    }
  }

  Future<void> _startMainStream() async {
    await _mainStreamSub?.cancel();

    dw.endpointCaller.dwRealTime.resetStream();

    _mainStreamSub = dw.endpointCaller.dwRealTime.stream.listen(_processUpdate);
  }

  Future<void> subscribeToChannel(String channel) async {
    if (_connectionHandler?.status.status !=
        StreamingConnectionStatus.connected) {
      return;
    }

    if (_channelSubs.containsKey(channel)) return;

    final sub = dw.endpointCaller.dwCrud
        .subscribeOnUpdates(channel: channel)
        .listen(
          _processUpdate,
          onDone: () => _channelSubs.remove(channel),
          onError: (_, __) => _channelSubs.remove(channel),
          cancelOnError: true,
        );

    _channelSubs[channel] = sub;
  }

  Future<void> unsubscribeFromChannel(String channel) async {
    final sub = _channelSubs.remove(channel);
    await sub?.cancel();
  }

  Future<void> unsubscribeAllChannels() async {
    final subs = _channelSubs.values.toList();
    _channelSubs.clear();

    for (final sub in subs) {
      await sub.cancel();
    }
  }
}
