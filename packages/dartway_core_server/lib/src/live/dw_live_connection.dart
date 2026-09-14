import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:dartway_core_shared/dartway_core_shared.dart';
import 'package:meta/meta.dart';

import '../alerts/dw_server_logger.dart';

/// One live socket (`GET /dw/live`): its session, its subscriptions and its
/// outbound queue.
///
/// The outbound queue writes through `WebSocket.addStream`, whose future
/// completes only when the socket has taken the data, so [queuedBytes] is what
/// the peer has not yet consumed from us — the number the ceiling needs. The
/// raw [socket] is kept because a peer that stops reading also never
/// completes the close handshake, and only the socket can be destroyed.
@internal
final class DwLiveConnection {
  DwLiveConnection({
    required this.id,
    required this.socket,
    required this.webSocket,
    required this.log,
    required this.outboundLimitBytes,
    required this.closeGrace,
  });

  /// Unguessable: a `Dw-Live-Connection` header names a connection by it, and
  /// a guessed id would let a caller filter or suppress someone else's
  /// updates. It is further bound to the account that authenticated it.
  final String id;
  final Socket socket;
  final WebSocket webSocket;
  final DwServerLogger log;
  final int outboundLimitBytes;
  final Duration closeGrace;

  // --- session -------------------------------------------------------------

  int? accountId;
  int? keyId;

  /// Bumped on every change of [accountId]; a subscription check that started
  /// under an older epoch does not take effect.
  int authEpoch = 0;

  /// Completes when the latest authentication has been applied. A
  /// subscription waits for the gate as it was when the message arrived, so a
  /// `sub` sent right after `auth` is checked for the new account.
  Future<void> authGate = Future.value();

  /// Channel wire names this connection is subscribed to.
  final Set<String> subscriptions = {};

  /// Serialises subscribe/unsubscribe per channel, in arrival order.
  final Map<String, Future<void>> channelTails = {};

  // --- outbound -------------------------------------------------------------

  final Queue<String> _queue = Queue();

  /// Characters queued and not yet taken by the socket. Characters rather
  /// than encoded bytes: counting UTF-8 would mean encoding every frame twice,
  /// and the ceiling is a guard against a stalled peer, not a quota.
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
    sendFrame(jsonEncode(message.toJson()));
  }

  /// Queues an already encoded frame (an update encoded once for all
  /// subscribers).
  void sendFrame(String frame) {
    if (isClosing) return;
    // The ceiling is on the backlog already waiting, not on this frame: one
    // large update for a client that reads promptly is not a slow consumer.
    final backlog = queuedBytes;
    _queue.add(frame);
    queuedBytes += frame.length;
    if (backlog > outboundLimitBytes) {
      log.warning(
        'live connection: outbound queue passed $outboundLimitBytes '
        'characters (account $accountId); disconnecting',
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

  /// Closes with [code]: frames already handed over are delivered first. A
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

  /// Completes when the socket is closed, whoever closed it.
  Future<void> get done => webSocket.done.then((_) {}, onError: (_) {});

  /// Called once the socket is done, whoever closed it.
  void markClosed() {
    _closed = true;
    _destroyTimer?.cancel();
    _queue.clear();
  }
}
