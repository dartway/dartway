import 'dart:async';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'dw_connection.dart';

/// Connects over a WebSocket — `dart:io` on the VM and mobile, the browser's
/// socket on the web (`web_socket_channel` picks).
final class DwWebSocketConnector implements DwConnector {
  const DwWebSocketConnector({this.closeTimeout = const Duration(seconds: 5)});

  /// How long [DwConnection.close] waits for the closing handshake. A server
  /// that has vanished never answers it, and stopping a client must not hang
  /// on that.
  final Duration closeTimeout;

  @override
  Future<DwConnection> connect(Uri endpoint) async {
    final channel = WebSocketChannel.connect(endpoint);
    await channel.ready;
    return _WebSocketConnection(channel, closeTimeout);
  }
}

final class _WebSocketConnection implements DwConnection {
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
  Future<void> close() =>
      _channel.sink.close().timeout(_closeTimeout, onTimeout: () {});
}
