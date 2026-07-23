import 'dart:async';

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
Stream<T> openChannelStream<T extends SerializableModel>(
  Session session,
  String channelName,
) {
  late final StreamController<T> controller;
  late final WillCloseListener sessionCloseListener;
  var detached = false;

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
  }

  sessionCloseListener = (_) {
    detachFromChannel();
    // Not awaited: closing a controller nobody listens to returns a future that
    // never completes, and this runs inside Session.close().
    unawaited(controller.close());
  };

  controller = StreamController<T>(onCancel: detachFromChannel);

  session.messages.addListener(channelName, channelListener);
  session.addWillCloseListener(sessionCloseListener);

  return controller.stream;
}
