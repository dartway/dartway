import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'dw_storage_transport.dart';

/// Sends uploads with `XMLHttpRequest`, the browser's default
/// (`dw_storage_transport_web.dart`) because it is the only browser API
/// whose upload carries real progress: `upload.onprogress` fires as the
/// browser's network stack actually accepts bytes, unlike `fetch` —
/// `DwHttpStorageTransport`'s own doc — which reads the whole request body
/// before sending any of it and then gives no signal at all while the real
/// transfer happens (#309).
///
/// A browser cannot stream a request body into `XMLHttpRequest` either, so
/// [put]'s body is read into memory before `send()` — the same limitation
/// `fetch` has. The difference is honesty about it: that read is never
/// reported through [DwStoragePut.reportSent], only `upload.onprogress` is,
/// so the client's progress and its stall watchdog reflect the network, not
/// how fast this transport happened to finish reading.
///
/// Not exported from `dartway_client.dart`: `dartway_core_flutter.dart`
/// re-exports this package wholesale, so anything public here reaches every
/// Flutter app on every platform, not only the web build — the same reason
/// `DwWebSplash` (`dartway_core_flutter`'s own web half of a conditional
/// pair) is not exported either. Reachable only through the conditional
/// default (`dw_storage_transport_stub.dart` / `_web.dart`), which is where
/// it belongs: nothing needs to construct it by hand.
final class DwXhrStorageTransport implements DwStorageTransport {
  const DwXhrStorageTransport();

  @override
  Future<DwStorageReply> put(DwStoragePut put) async {
    // Before reading a byte: an upload cancelled while its (possibly huge)
    // body is still being assembled in memory must stop reading it there,
    // not after the last byte of something it will never send.
    final bytes = await _readAll(put.body, put.abort);

    final xhr = web.XMLHttpRequest();
    final reply = Completer<DwStorageReply>();

    void finish(DwStorageReply value) {
      if (!reply.isCompleted) reply.complete(value);
    }

    void fail(Object error) {
      if (!reply.isCompleted) reply.completeError(error);
    }

    xhr.upload.onprogress = ((web.ProgressEvent event) {
      if (event.lengthComputable) put.reportSent(event.loaded);
    }).toJS;
    xhr.onload = ((web.Event _) {
      finish(DwStorageReply(status: xhr.status, body: xhr.responseText));
    }).toJS;
    xhr.onerror = ((web.Event _) {
      fail(StateError('The upload to storage failed on the network.'));
    }).toJS;
    xhr.onabort = ((web.Event _) {
      fail(StateError('The upload to storage was aborted.'));
    }).toJS;

    // `open` before headers, per the API; listeners above are already
    // attached, since some browsers need that before `open` to fire upload
    // events at all (the binding's own doc on `XMLHttpRequest.upload`).
    xhr.open('PUT', put.url.toString(), true);
    for (final MapEntry(:key, :value) in put.headers.entries) {
      // Never `content-length`: the ticket does not carry it as a header —
      // it is only part of what the presigned URL's signature covers — and
      // a browser sets it itself from the body's real size, which is what
      // the signature expects.
      xhr.setRequestHeader(key, value);
    }
    put.abort.then((_) => xhr.abort()).ignore();
    xhr.send(bytes.toJS);
    return reply.future;
  }

  @override
  void close() {}

  /// Reads [body] into one buffer, cancelling the moment [abort] completes
  /// rather than draining the rest of a body nobody will send — 400 MB read
  /// into memory after the upload was already cancelled is its own kind of
  /// stall. Throws whatever caused the abort, once [body] stops delivering
  /// because of it.
  ///
  /// Not progress — see the class doc — so nothing here calls back to the
  /// client; a slow *source* (unrelated to the network) is still caught by
  /// the attempt's own watchdog, armed as each chunk leaves it.
  static Future<Uint8List> _readAll(
    Stream<List<int>> body,
    Future<void> abort,
  ) async {
    final builder = BytesBuilder(copy: false);
    final done = Completer<void>();
    late final StreamSubscription<List<int>> subscription;
    subscription = body.listen(
      builder.add,
      onError: (Object error, StackTrace stackTrace) {
        if (!done.isCompleted) done.completeError(error, stackTrace);
      },
      onDone: () {
        if (!done.isCompleted) done.complete();
      },
    );
    abort.then((_) {
      if (!done.isCompleted) {
        unawaited(subscription.cancel());
        done.completeError(
          StateError(
            'The upload to storage was aborted while its body was being '
            'read.',
          ),
        );
      }
    }).ignore();
    await done.future;
    return builder.takeBytes();
  }
}
