import 'dart:async';

import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:serverpod/serverpod.dart';

/// Opens a stream of the messages posted to [channelName] on this server.
///
/// Deliberately does not use `session.messages.createStream`. That helper
/// registers a cleanup callback in a map keyed by the session
/// (`MessageCentral._sessionToCleanupCallbacksLookup`), and on the teardown
/// path every websocket takes, the entry outlives the session: closing a
/// connection cancels the method stream *before* the session is closed
/// (`MethodStreamManager.closeAllStreams`), so `removeListenersForSession`
/// finds no channels left for the session and returns early, never reaching
/// the callback map. The session stays reachable from that map for the lifetime
/// of the process, and with it the request, the buffered session log and the
/// socket it arrived on. Measured against serverpod 3.4.10 and 3.4.11.
///
/// Subscribing by hand keeps the bookkeeping to `addListener`/`removeListener`,
/// which do clean up after themselves, and makes teardown explicit: the channel
/// listener is dropped both when the stream is cancelled and when the session
/// closes underneath a stream that is still open.
/// [openChannelStream], refused unless [canListen] says the caller belongs in
/// the channel's audience.
///
/// The rule itself lives in `DwChannelConfig`, and which rule applies is
/// `DwCore.canListenTo` — passed in rather than read off the `dw` singleton so
/// that guarding and the stream bookkeeping underneath it can be tested apart
/// from each other, and from a booted Serverpod.
Stream<T> guardedChannelStream<T extends SerializableModel>(
  Session session,
  String channelName, {
  required Future<bool> Function(Session session, String channel) canListen,
}) {
  // Opened before the check, and deliberately: the check is asynchronous, and
  // opening after it awaited raced with session close. A socket that died
  // during the check left a channel listener behind that nothing would ever
  // remove — the exact leak [openChannelStream] exists to avoid, reintroduced
  // one layer up. Registering first costs a refused caller a listener for the
  // length of the check; whatever it buffers is dropped with the subscription
  // and never yielded, because the gate throws before the first `yield`.
  final source = openChannelStream<T>(session, channelName);

  return _yieldIfAllowed(source, session, channelName, canListen);
}

Stream<T> _yieldIfAllowed<T extends SerializableModel>(
  Stream<T> source,
  Session session,
  String channelName,
  Future<bool> Function(Session session, String channel) canListen,
) async* {
  if (!await canListen(session, channelName)) {
    // Cancelling is what detaches the channel listener — see the controller's
    // `onCancel` below. Without it a refused subscription would leak exactly
    // what an accepted one does not.
    await source.listen(null).cancel();
    throw DwChannelClosed(
      channel: channelName,
      reason: DwChannelClosedReason.notAllowed,
    );
  }

  yield* source;
}

Stream<T> openChannelStream<T extends SerializableModel>(
  Session session,
  String channelName,
) {
  late final StreamController<T> controller;
  late final WillCloseListener sessionCloseListener;
  late final MessageCentralListenerCallback revocationListener;
  var detached = false;

  // A websocket resolves its authentication once, when it opens, so a stream
  // that outlives the token it was opened with would keep delivering to a
  // banned or deleted account until the client itself went away. Ordinary
  // requests need no such handling — `dwAuthenticationHandler` reads the key
  // from the database every time.
  //
  // Serverpod ends its *own* method streams on revocation, but only for
  // endpoints that declare `requireLogin` or scopes
  // (`_RevokedAuthenticationHandler.createIfAuthenticationIsRequired`), and
  // `DwCrudEndpoint` can declare neither: one endpoint serves the public
  // catalogue and the private order list alike. So the framework listens for
  // itself, and every channel stream is covered whatever the endpoint says.
  final authentication = session.authenticated;
  final revokedAuthenticationChannel = authentication == null
      ? null
      : MessageCentralServerpodChannels.revokedAuthentication(
          authentication.userIdentifier,
        );

  void channelListener(SerializableModel message) {
    // postMessage broadcasts over a snapshot of the listener set, so a listener
    // that detached mid-broadcast can still be called. Adding to a closed
    // controller would throw out of postMessage and break delivery for every
    // other subscriber of the channel.
    if (controller.isClosed) return;

    try {
      controller.add(message as T);
    } catch (error) {
      controller.addError(error);
    }
  }

  void detachFromChannel() {
    if (detached) return;
    detached = true;

    session.removeWillCloseListener(sessionCloseListener);
    session.messages.removeListener(channelName, channelListener);

    if (revokedAuthenticationChannel != null) {
      session.messages.removeListener(
        revokedAuthenticationChannel,
        revocationListener,
      );
    }
  }

  /// Whether [message] revokes the authentication this stream was opened with.
  ///
  /// `RevokedAuthenticationScope` cannot: `dwAuthenticationHandler`
  /// authenticates with an empty scope set, so a DartWay session holds no scope
  /// to lose. Roles live in the app, and the app's own rule is re-read whenever
  /// a channel is opened.
  bool revokesThisStream(SerializableModel message) => switch (message) {
    RevokedAuthenticationUser _ => true,
    RevokedAuthenticationAuthId revoked =>
      revoked.authId == authentication!.authId,
    _ => false,
  };

  revocationListener = (message) {
    if (!revokesThisStream(message)) return;

    if (!controller.isClosed) {
      // A serializable error rather than a bare one: it is the only way the
      // client can tell "the server ended this on purpose" from "the network
      // dropped", and it must not reconnect its way back in.
      controller.addError(
        DwChannelClosed(
          channel: channelName,
          reason: DwChannelClosedReason.authenticationRevoked,
        ),
      );
    }

    detachFromChannel();
    // Not awaited, for the same reason as in the close listener below.
    unawaited(controller.close());
  };

  sessionCloseListener = (_) {
    detachFromChannel();
    // Not awaited: closing a controller nobody listens to returns a future that
    // never completes, and this runs inside Session.close().
    unawaited(controller.close());
  };

  controller = StreamController<T>(onCancel: detachFromChannel);

  session.messages.addListener(channelName, channelListener);
  if (revokedAuthenticationChannel != null) {
    session.messages.addListener(
      revokedAuthenticationChannel,
      revocationListener,
    );
  }
  session.addWillCloseListener(sessionCloseListener);

  return controller.stream;
}
