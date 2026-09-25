import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:meta/meta.dart';

/// A request body that could not be read. A project route that lets it
/// propagate answers [status]; a call answers it as a malformed call (400).
final class DwRequestBodyException implements Exception {
  const DwRequestBodyException._(this.status, this.message);

  /// The body is over its limit: 413.
  const DwRequestBodyException.tooLarge(int limit)
    : this._(413, 'the body is over $limit bytes');

  /// The body is not what the route reads (not JSON, not UTF-8): 400.
  const DwRequestBodyException.malformed(String message) : this._(400, message);

  /// The body did not arrive in time: 408.
  const DwRequestBodyException.timedOut() : this._(408, 'the body timed out');

  /// The HTTP status a route answers this with.
  final int status;
  final String message;

  @override
  String toString() => 'DwRequestBodyException($status: $message)';
}

/// The body of one incoming request, read at most once.
///
/// Every request's body is consumed before its response is written — read by
/// the handler, or discarded by the server. `dart:io` destroys a keep-alive
/// connection whose request body was left unread, and a peer whose unread
/// bytes are still in the server's buffer gets a reset instead of the answer
/// it was sent (a `426` for an old app, a `400` for an oversized body).
@internal
final class DwRequestBody {
  DwRequestBody(this._request, {required this.timeout});

  final HttpRequest _request;
  final Duration timeout;
  Future<Uint8List>? _read;

  /// The whole body. Throws [DwRequestBodyException] when it is over [limit]
  /// bytes or does not arrive within [timeout]; a second call answers the
  /// first read (with its own limit).
  Future<Uint8List> read(int limit) => _read ??= _collect(limit);

  /// Consumes a body nobody read, keeping none of it.
  Future<void> discard() async {
    if (_read != null) return;
    try {
      await read(0);
    } on DwRequestBodyException {
      // Discarding is the point; an oversized or late body changes nothing.
    }
  }

  Future<Uint8List> _collect(int limit) {
    // Past the limit the rest is drained, so the peer can read the refusal —
    // but only so far: a body far over any limit is cut off with the
    // connection instead of being received in full for nothing.
    final drainCap = limit + (1 << 20);
    final declared = _request.contentLength;
    if (declared > drainCap) {
      return Future.error(DwRequestBodyException.tooLarge(limit));
    }
    final completer = Completer<Uint8List>();
    final builder = BytesBuilder(copy: false);
    var received = 0;
    late final StreamSubscription<List<int>> subscription;
    void fail(Object error) {
      if (completer.isCompleted) return;
      unawaited(subscription.cancel());
      completer.completeError(error);
    }

    final timer = Timer(
      timeout,
      () => fail(const DwRequestBodyException.timedOut()),
    );
    subscription = _request.listen(
      (chunk) {
        received += chunk.length;
        if (received <= limit) {
          builder.add(chunk);
        } else if (received > drainCap) {
          timer.cancel();
          fail(DwRequestBodyException.tooLarge(limit));
        }
      },
      onError: (Object error) {
        timer.cancel();
        fail(error);
      },
      onDone: () {
        timer.cancel();
        if (completer.isCompleted) return;
        if (received > limit) {
          completer.completeError(DwRequestBodyException.tooLarge(limit));
        } else {
          completer.complete(builder.takeBytes());
        }
      },
      cancelOnError: true,
    );
    return completer.future;
  }
}
