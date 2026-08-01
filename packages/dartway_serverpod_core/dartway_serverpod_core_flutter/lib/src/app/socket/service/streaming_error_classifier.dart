import 'package:serverpod_client/serverpod_client.dart';

// Single source of truth for recognizing connection-level streaming errors.
//
// A channel subscription fails every time the network does: the socket drops, a
// reconnect attempt is refused, a tab is reloaded. `DwChannelSubscriptions`
// reopens what was asked for, and the current state is already on
// `DwSocketService.statusNotifier`, so the thrown errors carry no extra signal —
// they are noise, and must not reach the app's global error handler.
//
// What must *not* be swallowed is a `DwChannelClosed`: the server ending a
// subscription on purpose is an answer, not a blip, and it is handled where it
// lands rather than filtered here.

/// Returns `true` when [error] is a connection-level streaming error (noise to be
/// swallowed) and `false` for any other error (a real bug that must propagate).
bool isStreamingConnectionError(Object error) {
  // Every failure Serverpod's method-stream client raises for the connection
  // itself: failed to connect, listen error, closed, idle timeout.
  if (error is MethodStreamException) return true;

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
