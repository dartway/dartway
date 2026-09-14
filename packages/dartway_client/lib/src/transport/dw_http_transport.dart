import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// One call as it leaves the client: `POST <url>` with [headers] and a JSON
/// [body].
final class DwHttpPost {
  const DwHttpPost({
    required this.url,
    required this.headers,
    required this.body,
  });

  final Uri url;

  /// Header names in the framework's spelling (`DwHttpContract`).
  final Map<String, String> headers;

  /// The call's DTO as JSON text.
  final String body;

  @override
  String toString() => 'DwHttpPost($url)';
}

/// What came back for a [DwHttpPost]: the status, the headers (names in
/// lower case) and the body as text.
final class DwHttpReply {
  const DwHttpReply({
    required this.status,
    required this.body,
    this.headers = const {},
  });

  final int status;
  final Map<String, String> headers;
  final String body;

  @override
  String toString() => 'DwHttpReply($status)';
}

/// Sends calls to a DartWay server. The seam between the client and HTTP:
/// `package:http` in an app, memory in a test.
abstract interface class DwHttpTransport {
  /// Sends [post] and completes with whatever the server (or anything between)
  /// answered, whatever the status. Throws when no answer arrived — the
  /// network failed — which the client retries.
  Future<DwHttpReply> post(DwHttpPost post);

  /// Releases the transport's connections. The client calls it only for a
  /// transport it created itself.
  void close();
}

/// Sends calls with `package:http`: `dart:io` on the VM and mobile, the
/// browser's fetch on the web. Keeps connections alive between calls.
final class DwHttpClientTransport implements DwHttpTransport {
  DwHttpClientTransport([http.Client? client])
    : _client = client ?? http.Client();

  final http.Client _client;

  @override
  Future<DwHttpReply> post(DwHttpPost post) async {
    final response = await _client.post(
      post.url,
      headers: post.headers,
      // Bytes, not a string: `package:http` would otherwise pick the charset
      // itself, and the contract says UTF-8.
      body: utf8.encode(post.body),
    );
    return DwHttpReply(
      status: response.statusCode,
      headers: response.headers,
      // Decoded as UTF-8 whatever the content type claims: `response.body`
      // falls back to Latin-1 without a charset, and a proxy's error page
      // is read only to be refused anyway.
      body: utf8.decode(response.bodyBytes, allowMalformed: true),
    );
  }

  @override
  void close() => _client.close();
}

/// A transport whose calls never leave the process: every [post] is handed
/// to [handle], an in-process server — the fake one in `testing.dart`.
///
/// The answer arrives asynchronously, as over a network: never inside the
/// caller's own turn of the event loop. A [handle] that throws is a network
/// failure.
final class DwMemoryHttpTransport implements DwHttpTransport {
  DwMemoryHttpTransport(this.handle);

  final FutureOr<DwHttpReply> Function(DwHttpPost post) handle;

  bool _closed = false;

  @override
  Future<DwHttpReply> post(DwHttpPost post) async {
    if (_closed) throw StateError('The transport is closed.');
    await Future<void>.delayed(Duration.zero);
    final reply = await handle(post);
    await Future<void>.delayed(Duration.zero);
    return reply;
  }

  @override
  void close() => _closed = true;
}
