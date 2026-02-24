import 'dart:async';

import 'package:dartway_serverpod_core_client/dartway_serverpod_core_client.dart';

import '../../../repository/dw_repository.dart';

class DwSocketService {
  DwSocketService({
    required this.client,
    required this.endpointCaller,
    required this.onStatusChanged,
  });

  final ServerpodClientShared client;
  final dynamic
  endpointCaller; // dartway.Caller, чтобы не тащить зависимость выше
  final void Function(StreamingConnectionStatus status) onStatusChanged;

  StreamingConnectionHandler? _connectionHandler;
  StreamSubscription<SerializableModel>? _mainStreamSub;
  final Map<String, StreamSubscription<SerializableModel>> _channelSubs = {};

  void init() {
    _connectionHandler = StreamingConnectionHandler(
      client: client,
      retryEverySeconds: 1,
      listener: (_) => _refresh(),
    );

    _connectionHandler!.connect();
  }

  void dispose() async {
    await _mainStreamSub?.cancel();
    await unsubscribeAllChannels();
    _connectionHandler?.client.closeStreamingConnection();
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

    onStatusChanged(status);
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

    endpointCaller.dwRealTime.resetStream();

    _mainStreamSub = endpointCaller.dwRealTime.stream.listen(_processUpdate);
  }

  Future<void> subscribeToChannel(String channel) async {
    if (_connectionHandler?.status.status !=
        StreamingConnectionStatus.connected) {
      return;
    }

    if (_channelSubs.containsKey(channel)) return;

    final sub = endpointCaller.dwCrud
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
