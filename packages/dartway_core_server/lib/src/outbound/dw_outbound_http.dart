import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:meta/meta.dart';

import '../alerts/dw_server_logger.dart';

/// Requests from the server to somebody else's HTTP API — an SMS gateway, a
/// CRM, a model provider — as `ctx.http`, in handlers, jobs, routes and
/// startup steps alike.
///
/// ```dart
/// final response = await ctx.http.post(
///   Uri.parse('https://api.example.com/v1/messages'),
///   headers: {'authorization': 'Bearer ${env.crm.token}'},
///   json: {'phone': phone, 'text': text},
/// );
/// if (!response.isSuccess) throw CrmException(response.statusCode);
/// final id = (response.json as Map<String, Object?>)['id'];
/// ```
///
/// - **Every exchange is bounded**: the whole of it — connecting, sending,
///   the answer's last byte — by `DwServerSettings.outboundTimeout` unless
///   the call names its own `timeout`;
/// - **every exchange is logged** through the server's log, scoped like
///   `ctx.log`: the method, the origin, the status and how long it took. Not
///   the path, the query, the headers or a body — that is where tokens
///   travel (`/bot<token>/sendMessage`, `?psw=`);
/// - **an answer is an answer, whatever its status**: a 404 or a 503 is a
///   [DwOutboundResponse] to read. What throws is not getting one —
///   [DwOutboundException], timed out or unreachable;
/// - **a test scripts it**: a `DwTestServer` answers every outbound request
///   from its `DwFakeOutboundHttp` and records it, and refuses one no rule
///   answers — no test reaches the network by accident.
///
/// No external request inside a transaction: the transaction holds its locks
/// and its connection for as long as the other side takes to answer. Commit
/// first (`transactional: false`, a job), then call out.
final class DwOutboundHttp {
  @internal
  DwOutboundHttp(
    this._transport, {
    required DwServerLogger log,
    required Duration timeout,
  }) : _log = log,
       _timeout = timeout;

  final DwOutboundTransport _transport;
  final DwServerLogger _log;
  final Duration _timeout;

  /// `GET` [url].
  Future<DwOutboundResponse> get(
    Uri url, {
    Map<String, String> headers = const {},
    Duration? timeout,
    bool followRedirects = true,
  }) => send(
    'GET',
    url,
    headers: headers,
    timeout: timeout,
    followRedirects: followRedirects,
  );

  /// `POST` [url] — see [send] for [body] and [json].
  Future<DwOutboundResponse> post(
    Uri url, {
    Map<String, String> headers = const {},
    Object? body,
    Object? json,
    Duration? timeout,
    bool followRedirects = true,
  }) => send(
    'POST',
    url,
    headers: headers,
    body: body,
    json: json,
    timeout: timeout,
    followRedirects: followRedirects,
  );

  /// `PUT` [url] — see [send] for [body] and [json].
  Future<DwOutboundResponse> put(
    Uri url, {
    Map<String, String> headers = const {},
    Object? body,
    Object? json,
    Duration? timeout,
    bool followRedirects = true,
  }) => send(
    'PUT',
    url,
    headers: headers,
    body: body,
    json: json,
    timeout: timeout,
    followRedirects: followRedirects,
  );

  /// `PATCH` [url] — see [send] for [body] and [json].
  Future<DwOutboundResponse> patch(
    Uri url, {
    Map<String, String> headers = const {},
    Object? body,
    Object? json,
    Duration? timeout,
    bool followRedirects = true,
  }) => send(
    'PATCH',
    url,
    headers: headers,
    body: body,
    json: json,
    timeout: timeout,
    followRedirects: followRedirects,
  );

  /// `DELETE` [url] — see [send] for [body] and [json].
  Future<DwOutboundResponse> delete(
    Uri url, {
    Map<String, String> headers = const {},
    Object? body,
    Object? json,
    Duration? timeout,
    bool followRedirects = true,
  }) => send(
    'DELETE',
    url,
    headers: headers,
    body: body,
    json: json,
    timeout: timeout,
    followRedirects: followRedirects,
  );

  /// Sends [method] to [url] and answers the response, whatever its status.
  ///
  /// The body is [json] — encoded, `content-type: application/json` — or
  /// [body]: a `String` (UTF-8, `text/plain` unless [headers] name a type),
  /// bytes (`List<int>`), or a `Map<String, String>` sent as a form
  /// (`application/x-www-form-urlencoded`). Not both.
  ///
  /// [followRedirects] `false` answers a redirect as it is, rather than
  /// following it — for a request whose headers carry a credential, which a
  /// redirect would carry to wherever it points.
  ///
  /// Throws [DwOutboundException] when no response arrives within [timeout]
  /// (`DwServerSettings.outboundTimeout` by default), or at all.
  Future<DwOutboundResponse> send(
    String method,
    Uri url, {
    Map<String, String> headers = const {},
    Object? body,
    Object? json,
    Duration? timeout,
    bool followRedirects = true,
  }) async {
    final request = DwOutboundRequest.encode(
      method,
      url,
      headers: headers,
      body: body,
      json: json,
      followRedirects: followRedirects,
    );
    final limit = timeout ?? _timeout;
    final watch = Stopwatch()..start();
    try {
      final response = await _transport
          .exchange(request, limit)
          .timeout(
            limit,
            onTimeout: () =>
                throw DwOutboundException(request, timedOutAfter: limit),
          );
      _log.info(
        'outbound ${request.method} ${request.origin} → '
        '${response.statusCode} in ${watch.elapsedMilliseconds} ms',
      );
      return response;
    } on DwOutboundException catch (error) {
      _log.warning(
        'outbound ${request.method} ${request.origin} failed after '
        '${watch.elapsedMilliseconds} ms: ${error.reason}',
      );
      rethrow;
    }
  }
}

/// A request [DwOutboundHttp] sent — what a `DwFakeOutboundHttp` records and
/// matches its rules against.
final class DwOutboundRequest {
  DwOutboundRequest(
    this.method,
    this.url, {
    Map<String, String> headers = const {},
    List<int> bodyBytes = const [],
    this.followRedirects = true,
  }) : headers = Map.unmodifiable({
         for (final MapEntry(:key, :value) in headers.entries)
           key.toLowerCase(): value,
       }),
       bodyBytes = List.unmodifiable(bodyBytes);

  /// The request [DwOutboundHttp.send] makes of its arguments.
  @internal
  factory DwOutboundRequest.encode(
    String method,
    Uri url, {
    required Map<String, String> headers,
    required Object? body,
    required Object? json,
    required bool followRedirects,
  }) {
    if (body != null && json != null) {
      throw ArgumentError('Send either a body or json, not both');
    }
    final named = {
      for (final MapEntry(:key, :value) in headers.entries)
        key.toLowerCase(): value,
    };
    final (bytes, type) = _encodeBody(body, json);
    if (type != null) named.putIfAbsent('content-type', () => type);
    return DwOutboundRequest(
      method.toUpperCase(),
      url,
      headers: named,
      bodyBytes: bytes,
      followRedirects: followRedirects,
    );
  }

  final String method;
  final Uri url;

  /// The headers, names in lower case.
  final Map<String, String> headers;

  final List<int> bodyBytes;

  /// Whether a redirect is followed rather than answered.
  final bool followRedirects;

  /// The body as text (UTF-8).
  String get body => utf8.decode(bodyBytes, allowMalformed: true);

  /// The body decoded as JSON; throws [FormatException] when it is not.
  Object? get json => jsonDecode(body);

  /// A form body as its fields.
  Map<String, String> get form => Uri.splitQueryString(body);

  /// Scheme, host and port: what the log names, since a path or a query may
  /// hold a credential.
  String get origin => url.hasAuthority ? url.origin : '$url';

  @override
  String toString() => 'DwOutboundRequest($method $origin)';
}

/// The answer to a [DwOutboundRequest], whatever its status.
final class DwOutboundResponse {
  /// The body is [json] — encoded, `content-type: application/json` — or
  /// [body], a `String` or bytes, as [DwOutboundHttp.send] takes them: what a
  /// test answers a `DwFakeOutboundHttp` rule with.
  factory DwOutboundResponse(
    int statusCode, {
    Object? body,
    Object? json,
    Map<String, String> headers = const {},
  }) {
    if (body != null && json != null) {
      throw ArgumentError('Answer either a body or json, not both');
    }
    final (bytes, type) = _encodeBody(body, json);
    return DwOutboundResponse._(
      statusCode,
      headers: {
        'content-type': ?type,
        for (final MapEntry(:key, :value) in headers.entries)
          key.toLowerCase(): value,
      },
      bodyBytes: bytes,
    );
  }

  DwOutboundResponse._(
    this.statusCode, {
    required Map<String, String> headers,
    required List<int> bodyBytes,
  }) : headers = Map.unmodifiable(headers),
       bodyBytes = List.unmodifiable(bodyBytes);

  final int statusCode;

  /// The headers, names in lower case.
  final Map<String, String> headers;

  final List<int> bodyBytes;

  /// A 2xx status.
  bool get isSuccess => statusCode >= 200 && statusCode < 300;

  /// The body as text (UTF-8).
  String get body => utf8.decode(bodyBytes, allowMalformed: true);

  /// The body decoded as JSON; throws [FormatException] when it is not.
  Object? get json => jsonDecode(body);

  @override
  String toString() => 'DwOutboundResponse($statusCode)';
}

/// No response arrived: the exchange timed out, or the other side could not
/// be reached (DNS, a refused connection, TLS, a connection dropped midway).
///
/// Names the request by its method and origin only — the path and the query
/// may carry a credential.
final class DwOutboundException implements Exception {
  DwOutboundException(this.request, {this.timedOutAfter, String? cause})
    : reason = timedOutAfter != null
          ? 'timed out after ${timedOutAfter.inMilliseconds} ms'
          : cause ?? 'no response';

  final DwOutboundRequest request;

  /// The limit it ran out of; `null` when it failed another way.
  final Duration? timedOutAfter;

  bool get timedOut => timedOutAfter != null;

  /// What went wrong, for the log.
  final String reason;

  @override
  String toString() =>
      'DwOutboundException: ${request.method} ${request.origin}: $reason';
}

/// What carries a [DwOutboundRequest] and brings its response back: the
/// network in a running server, a `DwFakeOutboundHttp` in a test.
@internal
abstract interface class DwOutboundTransport {
  /// Throws [DwOutboundException] when no response arrives within [timeout].
  Future<DwOutboundResponse> exchange(
    DwOutboundRequest request,
    Duration timeout,
  );

  void close();
}

/// The network, through `package:http`: one client for the server's life,
/// its connections reused.
@internal
final class DwNetworkTransport implements DwOutboundTransport {
  DwNetworkTransport({required Duration connectionTimeout})
    : _client = IOClient(HttpClient()..connectionTimeout = connectionTimeout);

  final http.Client _client;

  @override
  Future<DwOutboundResponse> exchange(
    DwOutboundRequest request,
    Duration timeout,
  ) async {
    final abort = Completer<void>();
    final timer = Timer(timeout, abort.complete);
    try {
      final outgoing =
          http.AbortableRequest(
              request.method,
              request.url,
              abortTrigger: abort.future,
            )
            ..followRedirects = request.followRedirects
            ..headers.addAll(request.headers)
            ..bodyBytes = request.bodyBytes;
      final streamed = await _client.send(outgoing);
      final bytes = await streamed.stream.toBytes();
      return DwOutboundResponse._(
        streamed.statusCode,
        headers: streamed.headers,
        bodyBytes: bytes,
      );
    } on http.RequestAbortedException {
      throw DwOutboundException(request, timedOutAfter: timeout);
    } on http.ClientException catch (error) {
      throw DwOutboundException(request, cause: error.message);
    } on IOException catch (error) {
      throw DwOutboundException(request, cause: '$error');
    } finally {
      timer.cancel();
    }
  }

  @override
  void close() => _client.close();
}

(List<int>, String?) _encodeBody(Object? body, Object? json) => switch ((
  body,
  json,
)) {
  (null, null) => (const <int>[], null),
  (null, final value) => (
    utf8.encode(jsonEncode(value)),
    'application/json; charset=utf-8',
  ),
  (final String text, _) => (utf8.encode(text), 'text/plain; charset=utf-8'),
  (final List<int> bytes, _) => (bytes, null),
  (final Map<String, String> form, _) => (
    utf8.encode(Uri(queryParameters: form).query),
    'application/x-www-form-urlencoded; charset=utf-8',
  ),
  (final other, _) => throw ArgumentError.value(
    other.runtimeType,
    'body',
    'A body is a String, bytes or a Map<String, String> form',
  ),
};
