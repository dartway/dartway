import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:dartway_core/dartway_core.dart';
import 'package:meta/meta.dart';

import '../alerts/dw_logger.dart';

/// One app WebSocket: its session, its subscriptions and its outbound queue.
///
/// The outbound queue writes through `WebSocket.addStream`, whose future
/// completes only when the socket has taken the data, so [queuedBytes] is what
/// the peer has not yet consumed from us — the number the ceiling needs and
/// relic's `WebSocketUpgrade` cannot provide.
@internal
final class DwConnection {
  DwConnection({
    required this.id,
    required this.socket,
    required this.webSocket,
    required this.protocol,
    required this.log,
    required this.outboundLimitBytes,
    required this.closeGrace,
  });

  final int id;
  final Socket socket;
  final WebSocket webSocket;
  final DwProtocol protocol;
  final DwLogger log;
  final int outboundLimitBytes;
  final Duration closeGrace;

  // --- session -------------------------------------------------------------

  int? accountId;
  int? keyId;

  /// Bumped on every change of [accountId]; a subscription check that started
  /// under an older epoch does not take effect.
  int authEpoch = 0;

  /// Completes when the latest authentication has been applied. Every message
  /// waits for the gate as it was when the message arrived, so a call sent
  /// right after `auth` runs as the new account.
  Future<void> authGate = Future.value();

  /// Channel wire names this connection is subscribed to.
  final Set<String> subscriptions = {};

  /// Serialises subscribe/unsubscribe per channel, in arrival order.
  final Map<String, Future<void>> channelTails = {};

  /// Calls received and not yet answered: running or waiting for a slot.
  int inFlight = 0;
  int _running = 0;
  final Queue<Completer<void>> _waiting = Queue();

  /// Completes when [inFlight] drops to zero (for a graceful stop).
  Completer<void>? _idle;

  /// Registers a received call; `false` when [maxRunning] calls run and
  /// [maxWaiting] more are already queued — a client flooding the server.
  /// Counted at arrival, before the call waits for anything.
  bool admitCall(int maxRunning, int maxWaiting) {
    if (inFlight >= maxRunning + maxWaiting) return false;
    inFlight++;
    return true;
  }

  /// Waits for one of [maxRunning] slots. The socket keeps being read
  /// meanwhile: pausing it would also stop reading the peer's pongs, and a
  /// client with slow calls would be dropped as dead.
  Future<void> callSlot(int maxRunning) {
    if (_running < maxRunning) {
      _running++;
      return Future.value();
    }
    final waiter = Completer<void>();
    _waiting.add(waiter);
    return waiter.future;
  }

  /// Releases the slot of an answered call.
  void callEnded() {
    inFlight--;
    if (_waiting.isNotEmpty) {
      // The slot passes straight to the next waiting call.
      _waiting.removeFirst().complete();
    } else {
      _running--;
    }
    if (inFlight == 0) {
      _idle?.complete();
      _idle = null;
    }
  }

  Future<void> whenIdle() {
    if (inFlight == 0) return Future.value();
    return (_idle ??= Completer<void>()).future;
  }

  // --- outbound -------------------------------------------------------------

  final Queue<String> _queue = Queue();
  int queuedBytes = 0;
  bool _pumping = false;
  Completer<void>? _drained;

  bool get isClosing => _closeCode != null || _closed;
  bool _closed = false;
  int? _closeCode;
  String? _closeReason;
  Timer? _destroyTimer;

  /// Encodes and queues [message].
  void send(DwServerMessage message) {
    if (isClosing) return;
    sendFrame(jsonEncode(message.toJson(protocol)));
  }

  /// Queues an already encoded frame (an update encoded once for all
  /// subscribers).
  void sendFrame(String frame) {
    if (isClosing) return;
    // The ceiling is on the backlog already waiting, not on this frame: one
    // large result for a client that reads promptly is not a slow consumer.
    final backlog = queuedBytes;
    _queue.add(frame);
    queuedBytes += frame.length;
    if (backlog > outboundLimitBytes) {
      log.warning(
        'connection $id: outbound queue passed $outboundLimitBytes bytes '
        '(account $accountId); disconnecting',
      );
      _queue.clear();
      unawaited(close(DwCloseCode.slowConsumer, 'dw.slowConsumer'));
      return;
    }
    if (!_pumping) unawaited(_pump());
  }

  Future<void> _pump() async {
    _pumping = true;
    try {
      while (_queue.isNotEmpty && !_closed) {
        final batch = List.of(_queue);
        _queue.clear();
        try {
          await webSocket.addStream(Stream.fromIterable(batch));
        } catch (_) {
          // The socket is gone; `done` handles the rest.
          _queue.clear();
          break;
        }
        for (final frame in batch) {
          queuedBytes -= frame.length;
        }
      }
    } finally {
      _pumping = false;
      _drained?.complete();
      _drained = null;
    }
  }

  /// Completes when every queued frame has been handed to the socket.
  Future<void> flushed() {
    if (!_pumping) return Future.value();
    return (_drained ??= Completer<void>()).future;
  }

  /// Closes with [code]: frames already handed over are delivered first, the
  /// rest of the queue is dropped when the close was forced by the ceiling. A
  /// peer that does not complete the close within [closeGrace] is cut off.
  Future<void> close(int code, String reason) async {
    if (_closeCode != null || _closed) return;
    _closeCode = code;
    _closeReason = reason;
    _destroyTimer = Timer(closeGrace, () {
      if (!_closed) socket.destroy();
    });
    // `WebSocket.close` cannot run while `addStream` is active.
    await flushed();
    try {
      await webSocket.close(_closeCode, _closeReason);
    } catch (_) {
      socket.destroy();
    }
  }

  /// Called once the socket is done, whoever closed it.
  void markClosed() {
    _closed = true;
    _destroyTimer?.cancel();
    _queue.clear();
  }
}
