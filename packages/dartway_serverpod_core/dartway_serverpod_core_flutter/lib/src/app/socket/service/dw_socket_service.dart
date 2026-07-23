// ignore_for_file: deprecated_member_use

import 'dart:async';

import 'package:dartway_serverpod_core_client/dartway_serverpod_core_client.dart';
import 'package:dartway_serverpod_core_flutter/src/private/dw_singleton.dart';
import 'package:flutter/foundation.dart';

import '../../../repository/dw_repository.dart';
import 'dw_channel_subscriptions.dart';
import 'streaming_error_classifier.dart';

// TODO(serverpod-legacy-streams): This service still relies on Serverpod's
// deprecated StreamingConnectionHandler / streaming endpoint API. Keep it for
// compatibility during the current upgrade, then replace it with streaming
// methods.
class DwSocketService {
  DwSocketService({this.onStatusChanged});

  // final ServerpodClientShared client;
  // final dynamic endpointCaller;

  /// Optional outbound hook fired on every streaming status change. Default is
  /// `null` (no-op) — the framework raises no alerts on its own.
  final void Function(StreamingConnectionStatus status)? onStatusChanged;

  StreamingConnectionHandler? _connectionHandler;
  StreamSubscription<SerializableModel>? _mainStreamSub;

  late final _channelSubscriptions = DwChannelSubscriptions(
    openChannelStream: (channel) =>
        dw.endpointCaller.dwCrud.subscribeOnUpdates(channel: channel),
    onUpdate: _processUpdate,
  );

  final ValueNotifier<StreamingConnectionStatus> statusNotifier = ValueNotifier(
    StreamingConnectionStatus.disconnected,
  );

  void init() {
    // Run the handler (and its retry timer) inside a child zone so retry errors
    // inherit this zone instead of the app's root zone from DwAppRunner.
    runZonedGuarded(() {
      // Reconnect delay is left at Serverpod's own default of 5 seconds. The
      // handler retries on a fixed interval with no backoff, so a shorter one
      // turns an unstable network into a reconnect storm: every attempt opens a
      // fresh server-side session, with its own log buffer and websocket.
      _connectionHandler = StreamingConnectionHandler(
        client: dw.client,
        listener: (_) => _refresh(),
      );

      _connectionHandler!.connect();
    }, _onConnectionZoneError);
  }

  void _onConnectionZoneError(Object error, StackTrace stack) {
    if (isStreamingConnectionError(error)) {
      debugPrint(
        '[DwSocketService] swallowed streaming connection error: $error',
      );
      return; // connection-level noise → swallow, never surface it
    }
    // Real error → forward to the parent (app) zone so genuine bugs are not hidden.
    Zone.current.handleUncaughtError(error, stack);
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
      // Channel streams do not survive the connection they were opened on, so
      // every reconnect reopens the ones the app still follows.
      _channelSubscriptions.handleConnected();
    } else {
      _channelSubscriptions.handleDisconnected();
    }

    statusNotifier.value = status;
    onStatusChanged?.call(status);
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

  /// Follows [channel] until told otherwise. Asking while the connection is
  /// down is fine: the channel is opened as soon as it comes back.
  Future<void> subscribeToChannel(String channel) async =>
      _channelSubscriptions.request(channel);

  Future<void> unsubscribeFromChannel(String channel) =>
      _channelSubscriptions.release(channel);

  Future<void> unsubscribeAllChannels() => _channelSubscriptions.releaseAll();
}
