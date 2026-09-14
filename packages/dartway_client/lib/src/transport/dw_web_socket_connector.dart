import 'dart:async';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'dw_live_connection.dart';

/// Opens the live socket over a WebSocket — `dart:io` on the VM and mobile,
/// the browser's socket on the web (`web_socket_channel` picks).
final class DwWebSocketConnector implements DwLiveConnector {
  const DwWebSocketConnector({
    this.connectTimeout = const Duration(seconds: 10),
    this.closeTimeout = const Duration(seconds: 5),
  });

  /// How long opening may take. A blackholed port never refuses; without a
  /// bound the client would wait on it instead of backing off and retrying.
  final Duration connectTimeout;

  /// How long [DwLiveConnection.close] waits for the closing handshake. A
  /// server that has vanished never answers it, and stopping a client must
  /// not hang on that.
  final Duration closeTimeout;

  @override
  Future<DwLiveConnection> connect(Uri url) async {
    final channel = WebSocketChannel.connect(url);
    try {
      await channel.ready.timeout(connectTimeout);
    } catch (_) {
      unawaited(
        channel.sink
            .close()
            .timeout(closeTimeout, onTimeout: () {})
            .catchError((Object _) {}),
      );
      rethrow;
    }
    return _WebSocketConnection(channel, closeTimeout);
  }
}

final class _WebSocketConnection implements DwLiveConnection {
  _WebSocketConnection(this._channel, this._closeTimeout);

  final WebSocketChannel _channel;
  final Duration _closeTimeout;

  @override
  late final Stream<String> messages = _channel.stream.map(
    (frame) => frame is String
        ? frame
        : throw const FormatException(
            'The server sent a binary frame; the DartWay protocol is text.',
          ),
  );

  @override
  void send(String frame) => _channel.sink.add(frame);

  @override
  int? get closeCode => _channel.closeCode;

  @override
  String? get closeReason => _channel.closeReason;

  @override
  Future<void> close([int? code, String? reason]) => _channel.sink
      .close(code, reason)
      .timeout(_closeTimeout, onTimeout: () {});
}
