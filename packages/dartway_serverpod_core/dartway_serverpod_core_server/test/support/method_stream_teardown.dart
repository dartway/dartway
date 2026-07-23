import 'dart:async';

import 'package:serverpod/serverpod.dart';

import 'streaming_session_double.dart';

/// Reproduces how Serverpod tears down a method stream, in the two orders that
/// behave differently.
///
/// The plumbing is copied from `MethodStreamManager` (serverpod 3.4.10): an
/// output controller whose `onCancel` closes the session, a subscription
/// carrying values out to the socket, and `addStream` feeding it from the
/// endpoint method.
class MethodStreamTeardown {
  MethodStreamTeardown(
    this.session,
    Stream<SerializableModel> Function(Session session) callEndpointMethod,
  ) {
    _outputController = StreamController<dynamic>(onCancel: _closeSession);
    _subscription = _outputController.stream.listen(
      (value) => receivedMessages.add(value as SerializableModel),
    );
    _outputController.addStream(callEndpointMethod(session));
  }

  final FakeStreamingSession session;
  final receivedMessages = <SerializableModel>[];

  late final StreamController<dynamic> _outputController;
  late final StreamSubscription<dynamic> _subscription;
  var _sessionClosed = false;

  Future<void> _closeSession() async {
    if (_sessionClosed) return;
    _sessionClosed = true;
    await session.close();
  }

  /// `MethodStreamManager.closeStream`: the client closed one stream while the
  /// socket stays up — the session is closed before the subscription is.
  Future<void> closeSingleStream() async {
    await _outputController.onCancel?.call();
    unawaited(_subscription.cancel());
    await settleStreamEvents();
  }

  /// `MethodStreamManager.closeAllStreams`: the socket went away — the
  /// subscription is cancelled first and the session closes from inside that
  /// cancel chain. This is the path *every* websocket teardown takes, clean or
  /// not, because it runs in the `finally` around the socket's event loop.
  Future<void> closeWithSocket() async {
    await _subscription.cancel();
    await settleStreamEvents();
  }
}
