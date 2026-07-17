// Single source of truth for recognizing connection-level streaming errors.
//
// Serverpod's StreamingConnectionHandler retries the websocket on a timer; while
// the network is down each attempt throws (WebSocketChannelException, etc.). The
// connection state is already exposed via DwSocketService.statusNotifier, so these
// thrown errors carry no extra signal — they are pure noise from network blips,
// offline periods or tab reloads, and must not reach the app's global error handler.

/// Returns `true` when [error] is a connection-level streaming error (noise to be
/// swallowed) and `false` for any other error (a real bug that must propagate).
bool isStreamingConnectionError(Object error) {
  final text = error.toString();
  return _connectionErrorPatterns.any(text.contains);
}

const _connectionErrorPatterns = <String>[
  'Failed to connect WebSocket',
  'WebSocketChannelException',
  'WebSocketException',
  'SocketException',
  'TimeoutException',
  'Failed to fetch',
  'statusCode = -1',
];
