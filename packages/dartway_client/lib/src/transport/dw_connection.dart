import 'dart:async';

/// Opens connections to a DartWay server. The seam between the client and the
/// wire: a WebSocket in an app, memory in a test.
abstract interface class DwConnector {
  /// Opens a connection, or throws when the server cannot be reached.
  Future<DwConnection> connect(Uri endpoint);
}

/// One open connection carrying JSON text frames both ways.
abstract interface class DwConnection {
  /// Frames from the server. Single-subscription; done when the connection
  /// is over, whichever side ended it.
  Stream<String> get messages;

  /// Sends a frame. Throws when the connection is already closed.
  void send(String frame);

  /// Ends the connection. [messages] completes.
  Future<void> close();
}

/// A connector whose connections never leave the process.
///
/// Every [connect] makes a linked pair and hands the server's end to [accept]
/// before returning the client's end; an [accept] that throws refuses the
/// connection. An in-process server — the fake one in `testing.dart`, or a
/// real one in a widget test — accepts here. Frames still travel as text, so
/// everything that crosses is encoded and decoded exactly as on a socket.
final class DwMemoryConnector implements DwConnector {
  DwMemoryConnector(this.accept);

  final FutureOr<void> Function(DwConnection serverEnd, Uri endpoint) accept;

  @override
  Future<DwConnection> connect(Uri endpoint) async {
    final client = _MemoryEnd();
    final server = _MemoryEnd();
    client._peer = server;
    server._peer = client;
    await accept(server, endpoint);
    return client;
  }
}

final class _MemoryEnd implements DwConnection {
  // Asynchronous delivery, as on a socket: a frame sent now is read in a later
  // microtask, never re-entrantly inside the sender's call.
  final StreamController<String> _incoming = StreamController<String>();
  late final _MemoryEnd _peer;
  bool _closed = false;

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
  Future<void> close() async {
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
