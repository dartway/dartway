import 'dart:async';

import 'package:dartway_serverpod_core_client/dartway_serverpod_core_client.dart';
import 'package:dartway_serverpod_core_flutter/private/dw_singleton.dart';
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../repository/dw_repository.dart';

part 'dw_socket_state.freezed.dart';
part 'dw_socket_state.g.dart';

@freezed
abstract class DwSocketStateModel with _$DwSocketStateModel {
  const factory DwSocketStateModel({
    required StreamingConnectionStatus websocketStatus,
  }) = _DwSocketStateModel;
}

@Riverpod(keepAlive: true)
class DwSocketState extends _$DwSocketState {
  StreamingConnectionHandler? _connectionHandler;
  final Map<String, StreamSubscription<SerializableModel>> _channelSubs = {};
  StreamSubscription<SerializableModel>? _mainStreamSub;

  @override
  DwSocketStateModel build() {
    ref.onDispose(() {
      _mainStreamSub?.cancel();
      unsubscribeAllChannels();
    });

    if (dw.sessionProvider != null) {
      ref.listen(dw.sessionProvider!, (previousState, nextState) {
        if (nextState.signedInUserId != previousState?.signedInUserId) {
          _connectionHandler?.client.closeStreamingConnection();
          unsubscribeAllChannels();
        }
      });
    }

    return DwSocketStateModel(
      websocketStatus: StreamingConnectionStatus.disconnected,
    );
  }

  Future<bool> init({required ServerpodClientShared client}) async {
    _connectionHandler = StreamingConnectionHandler(
      client: client,
      retryEverySeconds: 1,
      listener: (connectionState) async {
        debugPrint('listener called ${connectionState.status}');
        _refresh();
      },
    );

    _connectionHandler!.connect();

    return true;
  }

  _refresh() async {
    if (state.websocketStatus != StreamingConnectionStatus.connected &&
        _connectionHandler?.status.status ==
            StreamingConnectionStatus.connected) {
      _startMainStream();
    }

    state = DwSocketStateModel(
      websocketStatus: _connectionHandler?.status.status ??
          StreamingConnectionStatus.disconnected,
    );
  }

  _processUpdatedModels(List<DwModelWrapper> updatedModels) {
    // debugPrint("Received ${update.className} with id ${update.modelId}");
    // TODO: setup app notifications processing
    // if (update.model is DwAppNotification) {
    //   ref.notifyUser(update.model as DwAppNotification);
    //   // for (var enclosedObject
    //   //     in (update.model as DwAppNotification).updatedModels ?? []) {
    //   //   ref.updateFromStream(enclosedObject);
    //   // }
    // }

    // if (update.modelId != null) {
    DwRepository.updateListeningStates(
        wrappedModelUpdates:
            updatedModels.where((e) => e.modelId != null).toList());
    // }
  }

  _processUpdate(SerializableModel update) {
    if (update is DwModelWrapper) {
      _processUpdatedModels([update]);
    } else if (update is DwUpdatesTransport) {
      // for (var e in update.wrappedModelUpdates) {
      _processUpdatedModels(update.wrappedModelUpdates);
      // }
    }
  }

  Future<void> _startMainStream() async {
    _mainStreamSub?.cancel();

    dw.endpointCaller.dwRealTime.resetStream();

    await for (var update in dw.endpointCaller.dwRealTime.stream) {
      _processUpdate(update);
    }
  }

  Future<void> subscribeToChannel(String channel) async {
    if (_connectionHandler?.status.status !=
        StreamingConnectionStatus.connected) {
      debugPrint("⚠️ Cannot subscribe, not connected yet");
      return;
    }

    if (_channelSubs.containsKey(channel)) {
      debugPrint("Already subscribed to $channel");
      return;
    }

    final sub =
        dw.endpointCaller.dwCrud.subscribeOnUpdates(channel: channel).listen(
      (update) => _processUpdate(update),
      onDone: () {
        // поток завершился (разрыв/переподключение) — освободим слот
        _channelSubs.remove(channel);
      },
      onError: (e, st) {
        debugPrint("Channel $channel error: $e");
        _channelSubs.remove(channel);
      },
      cancelOnError: true,
    );
    _channelSubs[channel] = sub;

    debugPrint("✅ Subscribed to $channel");
  }

  Future<void> unsubscribeFromChannel(String channel) async {
    if (_channelSubs.containsKey(channel)) {
      await _channelSubs[channel]!.cancel();
      _channelSubs.remove(channel);
      debugPrint("❌ Unsubscribed from $channel");
    }
  }

  Future<void> unsubscribeAllChannels() async {
    for (var sub in _channelSubs.values) {
      await sub.cancel();
    }
    _channelSubs.clear();
    debugPrint("❌ Unsubscribed from all channels");
  }
}
