import 'dart:async';

import 'package:serverpod/serverpod.dart';

/// Test doubles that drive the *real* [MessageCentral] without booting a
/// Serverpod instance or a database.
///
/// This works because message central reaches for exactly one thing on a
/// session besides its identity — `serverpod.redisController` — and identity is
/// all its bookkeeping uses the session for. Delivery, broadcast snapshots and
/// per-session cleanup are therefore Serverpod's own behaviour here, not a
/// re-implementation of it.

class FakeServerpodInstance implements Serverpod {
  /// `redisController` is the only member ever read; null is the answer message
  /// central expects when Redis is off.
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Forwards to a real [MessageCentral] and records the channel subscriptions,
/// so a test can assert that every listener a stream adds is taken back.
class RecordingSessionMessages implements MessageCentralAccess {
  RecordingSessionMessages(this._messageCentral, this._session);

  final MessageCentral _messageCentral;
  final Session _session;
  final List<MessageCentralListenerCallback> _activeListeners = [];

  /// Channel listeners added and not yet removed.
  int get activeListenerCount => _activeListeners.length;

  @override
  void addListener(
    String channelName,
    MessageCentralListenerCallback listener,
  ) {
    _activeListeners.add(listener);
    _messageCentral.addListener(_session, channelName, listener);
  }

  @override
  void removeListener(
    String channelName,
    MessageCentralListenerCallback listener,
  ) {
    _activeListeners.remove(listener);
    _messageCentral.removeListener(_session, channelName, listener);
  }

  @override
  Future<bool> postMessage(
    String channelName,
    SerializableModel message, {
    bool global = false,
  }) => _messageCentral.postMessage(channelName, message, global: global);

  /// Serverpod's own channel-to-stream helper, which the framework must not
  /// use: it registers a cleanup callback in a map keyed by the session, and on
  /// the teardown path every websocket takes that entry outlives the session.
  /// See `openChannelStream`.
  @override
  Stream<T> createStream<T>(String channelName) => throw UnsupportedError(
    'session.messages.createStream leaks the session in serverpod 3.4.x — '
    'use openChannelStream instead.',
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// A session carrying the part of the lifecycle streaming teardown depends on:
/// the will-close listeners and [close], copied from `Session.close()`.
class FakeStreamingSession implements Session {
  FakeStreamingSession(this.sessionLabel, MessageCentral messageCentral)
    : _messageCentral = messageCentral {
    channelMessages = RecordingSessionMessages(messageCentral, this);
  }

  final String sessionLabel;
  final MessageCentral _messageCentral;
  final _serverpod = FakeServerpodInstance();
  final List<WillCloseListener> _willCloseListeners = [];
  var _closed = false;

  /// The recording double [messages] resolves to.
  late final RecordingSessionMessages channelMessages;

  @override
  MessageCentralAccess get messages => channelMessages;

  @override
  Serverpod get serverpod => _serverpod;

  /// Will-close listeners that have not run yet. They live on the session, so
  /// anything left here dies with it — but a teardown that never ran is still a
  /// teardown that did not happen.
  int get pendingWillCloseListenerCount => _willCloseListeners.length;

  @override
  void addWillCloseListener(WillCloseListener listener) =>
      _willCloseListeners.add(listener);

  @override
  void removeWillCloseListener(WillCloseListener listener) =>
      _willCloseListeners.remove(listener);

  @override
  Future<int?> close({dynamic error, StackTrace? stackTrace}) async {
    if (_closed) return null;
    _closed = true;

    final willCloseListeners = _willCloseListeners.toList();
    _willCloseListeners.clear();
    for (final listener in willCloseListeners) {
      await listener(this);
    }

    _messageCentral.removeListenersForSession(this);
    return null;
  }

  @override
  void log(
    String message, {
    LogLevel? level,
    dynamic exception,
    StackTrace? stackTrace,
  }) {}

  @override
  String toString() => 'FakeStreamingSession($sessionLabel)';

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// A trivial payload to broadcast over a channel.
class ChannelPing implements SerializableModel {
  @override
  Map<String, dynamic> toJson() => {'ping': true};
}

/// A payload of a different type, for the type-mismatch case.
class ChannelPong implements SerializableModel {
  @override
  Map<String, dynamic> toJson() => {'pong': true};
}

/// Lets pending microtasks and stream events settle.
Future<void> settleStreamEvents() async {
  for (var tick = 0; tick < 10; tick++) {
    await Future<void>.delayed(Duration.zero);
  }
}
