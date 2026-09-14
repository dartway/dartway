import 'dart:async';

/// Opens the live socket (`GET /dw/live`). The seam between the client and
/// the WebSocket: a real socket in an app, memory in a test.
abstract interface class DwLiveConnector {
  /// Opens a connection to [url], or throws when the server cannot be
  /// reached.
  Future<DwLiveConnection> connect(Uri url);
}

/// One open live connection carrying JSON text frames both ways.
abstract interface class DwLiveConnection {
  /// Frames from the server. Single-subscription; done when the connection
  /// is over, whichever side ended it.
  Stream<String> get messages;

  /// Sends a frame. Throws when the connection is already closed.
  void send(String frame);

  /// The close code the other side ended the connection with, once
  /// [messages] is done; `null` while open, and when the connection ended
  /// without one (a dropped network). The client decides by it whether to
  /// reconnect — see `DwCloseCode`.
  int? get closeCode;

  /// The reason that came with [closeCode].
  String? get closeReason;

  /// Ends the connection, with [code] and [reason] when given (a server end
  /// closing as the server would). [messages] completes.
  Future<void> close([int? code, String? reason]);
}

/// A connector whose connections never leave the process.
///
/// Every [connect] makes a linked pair and hands the server's end to [accept]
/// before returning the client's end; an [accept] that throws refuses the
/// connection. Frames still travel as text, so everything that crosses is
/// encoded and decoded exactly as on a socket.
final class DwMemoryLiveConnector implements DwLiveConnector {
  DwMemoryLiveConnector(this.accept);

  final FutureOr<void> Function(DwLiveConnection serverEnd, Uri url) accept;

  @override
  Future<DwLiveConnection> connect(Uri url) async {
    final client = _MemoryEnd();
    final server = _MemoryEnd();
    client._peer = server;
    server._peer = client;
    await accept(server, url);
    return client;
  }
}

final class _MemoryEnd implements DwLiveConnection {
  // Asynchronous delivery, as on a socket: a frame sent now is read in a later
  // microtask, never re-entrantly inside the sender's call.
  final StreamController<String> _incoming = StreamController<String>();
  late final _MemoryEnd _peer;
  bool _closed = false;

  @override
  int? closeCode;

  @override
  String? closeReason;

  @override
  Stream<String> get messages => _incoming.stream;

  @override
  void send(String frame) {
    if (_closed) throw StateError('The connection is closed.');
    _peer._deliver(frame);
  }

  void _deliver(String frame) {
    // A frame sent into a connection the other side already closed is lost,
    // as it would be on a socket.
    if (!_closed) _incoming.add(frame);
  }

  @override
  Future<void> close([int? code, String? reason]) async {
    if (_closed) return;
    // Both ends learn the code, as both sides of a WebSocket closing
    // handshake do.
    for (final end in [this, _peer]) {
      end
        ..closeCode ??= code
        ..closeReason ??= reason;
    }
    _shutdown();
    _peer._shutdown();
  }

  void _shutdown() {
    if (_closed) return;
    _closed = true;
    // Not awaited: a single-subscription controller completes its close only
    // once listened to, and frames already added are still delivered first.
    unawaited(_incoming.close());
  }
}
