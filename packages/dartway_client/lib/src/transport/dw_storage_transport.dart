import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// The bytes of one upload, and how to read them — again, for a retry.
sealed class DwUploadSource {
  const DwUploadSource._();

  /// Bytes in memory: what a picker hands over for a photo.
  factory DwUploadSource.bytes(Uint8List bytes) = _DwBytesSource;

  /// A stream of exactly [byteSize] bytes, opened by [open] for every
  /// attempt: a retry after a network failure starts from the first byte, so
  /// [open] must return a fresh stream each time (a file read, say — not one
  /// stream kept in a variable).
  factory DwUploadSource.stream(
    Stream<List<int>> Function() open, {
    required int byteSize,
  }) = _DwStreamSource;

  /// The exact length; the upload is signed for it.
  int get byteSize;

  /// A new stream of the bytes.
  Stream<List<int>> open();
}

final class _DwBytesSource extends DwUploadSource {
  const _DwBytesSource(this.bytes) : super._();

  final Uint8List bytes;

  /// Chunks this size, so progress has something to report between the first
  /// byte and the last.
  static const int _chunk = 64 << 10;

  @override
  int get byteSize => bytes.length;

  @override
  Stream<List<int>> open() async* {
    for (var offset = 0; offset < bytes.length; offset += _chunk) {
      yield Uint8List.sublistView(
        bytes,
        offset,
        min(offset + _chunk, bytes.length),
      );
    }
  }
}

final class _DwStreamSource extends DwUploadSource {
  _DwStreamSource(this._open, {required this.byteSize}) : super._() {
    if (byteSize < 0) {
      throw ArgumentError.value(byteSize, 'byteSize', 'is negative');
    }
  }

  final Stream<List<int>> Function() _open;

  @override
  final int byteSize;

  @override
  Stream<List<int>> open() => _open();
}

/// One upload as it leaves the client: `PUT <url>` with [headers], a body of
/// [byteSize] bytes.
final class DwStoragePut {
  const DwStoragePut({
    required this.url,
    required this.headers,
    required this.byteSize,
    required this.body,
    required this.abort,
    this.reportSent = _ignoreSent,
  });

  /// A presigned URL: a credential for one object, never logged.
  final Uri url;

  /// Exactly the ticket's headers.
  final Map<String, String> headers;

  final int byteSize;

  /// Read once. Reading a chunk is not the same as sending it — see
  /// [reportSent] — but a transport still has to read every one to hand the
  /// bytes over at all, and doing so keeps the attempt's watchdog convinced
  /// the pipeline is alive even before anything reaches the network: a slow
  /// source (a big file read off disk, say) is not a stalled connection.
  final Stream<List<int>> body;

  /// Completes when the client gives up on the attempt (a stalled network,
  /// a stopped client): the transport stops sending and throws.
  final Future<void> abort;

  /// Tells the client how many bytes have actually left for the network so
  /// far — cumulative, not a delta, and never decreasing. Call it as often as
  /// the transport can measure that; it re-arms the client's stall watchdog
  /// on every call, same as reading [body] does on its own, and drives the
  /// client's progress callback instead of a plain read once it has been
  /// called at all.
  ///
  /// Streaming [body] at the network's pace (the socket's backpressure)
  /// means every chunk read from it qualifies, since reading and sending
  /// happen together — `DwHttpStorageTransport` calls it that way.
  /// `XMLHttpRequest.upload.onprogress` in a browser is a transport-specific
  /// source of the same fact, needed there because a browser cannot stream a
  /// request body into `XMLHttpRequest` at all: the whole body is read into
  /// memory before anything is sent, and reporting *that* as progress is
  /// exactly the bug this callback exists to avoid — a browser's `fetch`
  /// does the same thing, silently, which is why it cannot be trusted for
  /// uploads of any size (`DwHttpStorageTransport`'s own doc).
  ///
  /// A transport that never calls this loses nothing but precision: reading
  /// [body] already keeps the watchdog alive and (until this is called for
  /// the first time) reports progress on its own — this callback only lets a
  /// transport speak for the network more exactly than "I am still reading
  /// the body" can.
  final void Function(int sentBytes) reportSent;

  static void _ignoreSent(int sentBytes) {}

  @override
  String toString() => 'DwStoragePut(${url.host}, $byteSize bytes)';
}

/// What storage answered to a [DwStoragePut].
final class DwStorageReply {
  const DwStorageReply({required this.status, this.body = ''});

  final int status;

  /// The body, for an error's code; empty for a success.
  final String body;

  @override
  String toString() => 'DwStorageReply($status)';
}

/// Sends uploads to storage. The seam between the client and HTTP for file
/// bytes, apart from the `DwHttpTransport` of calls: different hosts,
/// streamed bodies, no DartWay envelope.
abstract interface class DwStorageTransport {
  /// Sends [put] and completes with whatever storage answered, whatever the
  /// status. Throws when no answer arrived — the network failed, or the put
  /// was aborted — which the client retries.
  Future<DwStorageReply> put(DwStoragePut put);

  /// Releases the transport's connections. The client calls it only for a
  /// transport it created itself.
  void close();
}

/// Sends uploads with `package:http`: a streamed body on `dart:io`, reported
/// through [DwStoragePut.reportSent] as each chunk `send` pulls from it is
/// handed to the socket. That is *a* signal, not a guarantee of delivery —
/// a body that fits the OS's own send buffer can be handed over in one go
/// long before the network has taken it anywhere, which is exactly why the
/// client no longer trusts "the whole body was handed to the socket" as
/// proof the connection is alive (D-088) — but it is still the best signal
/// this transport has, and spread over a real transfer of any size it
/// tracks the socket closely enough.
///
/// In a browser the fetch-based client reads the whole body before sending
/// it: the upload works, but every chunk is pulled at once, so
/// [DwStoragePut.reportSent] jumps to the end immediately and the transfer
/// itself happens without any further progress — use
/// `DwXhrStorageTransport` there instead (`DwAppClient`'s default on the
/// web, D-088) — not linked: it is deliberately not part of this package's
/// public library (see its own doc for why).
final class DwHttpStorageTransport implements DwStorageTransport {
  DwHttpStorageTransport([http.Client? client])
    : _client = client ?? http.Client();

  final http.Client _client;

  @override
  Future<DwStorageReply> put(DwStoragePut put) async {
    var sent = 0;
    final body = put.body.map((chunk) {
      sent += chunk.length;
      put.reportSent(sent);
      return chunk;
    });
    final request = _PutRequest(put.url, body, put.abort)
      ..contentLength = put.byteSize
      ..headers.addAll(put.headers);
    final response = await _client.send(request);
    // An error body is a few hundred bytes of XML; a success has none. Read
    // with the abort in force, so a stalled answer ends too.
    final responseBody = await response.stream.bytesToString(utf8);
    return DwStorageReply(status: response.statusCode, body: responseBody);
  }

  @override
  void close() => _client.close();
}

/// A request whose body is the given stream as it is, so the transport's
/// backpressure reaches the source and progress counts what was taken.
final class _PutRequest extends http.BaseRequest with http.Abortable {
  _PutRequest(Uri url, this._body, this.abortTrigger) : super('PUT', url);

  final Stream<List<int>> _body;

  @override
  final Future<void> abortTrigger;

  @override
  http.ByteStream finalize() {
    super.finalize();
    return http.ByteStream(_body);
  }
}

/// A transport whose uploads never leave the process: every [put] is handed
/// to [handle] — a fake storage in tests. A [handle] that throws is a
/// network failure.
final class DwMemoryStorageTransport implements DwStorageTransport {
  DwMemoryStorageTransport(this.handle);

  final FutureOr<DwStorageReply> Function(DwStoragePut put) handle;

  bool _closed = false;

  @override
  Future<DwStorageReply> put(DwStoragePut put) async {
    if (_closed) throw StateError('The transport is closed.');
    await Future<void>.delayed(Duration.zero);
    return handle(put);
  }

  @override
  void close() => _closed = true;
}
