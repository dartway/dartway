import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:meta/meta.dart';

import 'dw_file_storage.dart';
import 'dw_sigv4_signer.dart';

/// What `HEAD` says about a stored object.
@internal
typedef DwObjectHead = ({int byteSize, String contentType});

/// Storage answered a server-side request with an error: a misconfiguration
/// (wrong keys, a missing bucket) or an outage. A failure, never a refusal:
/// the user did nothing wrong.
///
/// The text names the operation, the status and S3's error code, never the
/// key's signature or a credential.
final class DwStorageException implements Exception {
  const DwStorageException(this.operation, this.status, [this.errorCode]);

  /// `HEAD`, `DELETE` …
  final String operation;

  final int status;

  /// S3's `<Code>`, when the body had one (`AccessDenied`, `NoSuchBucket`).
  final String? errorCode;

  @override
  String toString() =>
      'DwStorageException($operation answered $status'
      '${errorCode == null ? '' : ' $errorCode'})';
}

/// The four storage operations the framework needs, over `dart:io` and
/// [DwSigV4Signer]: a presigned PUT and GET for clients, a signed HEAD and
/// DELETE for the server itself.
@internal
final class DwObjectStore {
  DwObjectStore(this.config, {required this.requestTimeout, HttpClient? http})
    : _signer = DwSigV4Signer(
        accessKey: config.accessKey,
        secretKey: config.secretKey,
        region: config.region,
      ),
      _http = http ?? (HttpClient()..idleTimeout = const Duration(seconds: 15));

  final DwFileStorageConfig config;
  final Duration requestTimeout;
  final DwSigV4Signer _signer;
  final HttpClient _http;

  /// The authority requests go to, as the `host` header carries it: with the
  /// port only when it is not the scheme's default, which is what HTTP
  /// clients send and therefore what the signature must cover.
  String get _host {
    final endpoint = config.endpoint;
    final host = config.pathStyle
        ? endpoint.host
        : '${config.bucket}.${endpoint.host}';
    return endpoint.hasPort ? '$host:${endpoint.port}' : host;
  }

  /// The decoded path of [key]'s object (and of the bucket for a null key).
  String _path(String? key) {
    final prefix = config.pathStyle ? '/${config.bucket}' : '';
    return key == null ? (prefix.isEmpty ? '/' : prefix) : '$prefix/$key';
  }

  /// A URL with the path encoded exactly as it is signed; `Uri.parse` keeps
  /// that encoding.
  Uri _url(String path, [String query = '']) => Uri.parse(
    '${config.endpoint.scheme}://$_host'
    '${DwSigV4Signer.encode(path, keepSlash: true)}'
    '${query.isEmpty ? '' : '?$query'}',
  );

  /// A URL a client can PUT one object to until [expires] passes, bound to
  /// the length and headers in the answer.
  ///
  /// `if-none-match: *` makes the upload conditional on the key being free
  /// (S3 conditional writes): the URL cannot overwrite the object once it is
  /// there — not by a second upload of the same ticket, not after the file
  /// was confirmed — and a retry of an upload that did arrive answers `412`,
  /// which the client reads as "already stored". Storage that does not know
  /// the header ignores it and loses only that protection.
  ({Uri url, Map<String, String> headers}) presignPut({
    required String key,
    required String contentType,
    required int byteSize,
    required Duration expires,
    required DateTime time,
  }) {
    final path = _path(key);
    final bound = {'content-type': contentType, 'if-none-match': '*'};
    final query = _signer.presignedQuery(
      method: 'PUT',
      path: path,
      headers: [
        ('host', _host),
        ('content-length', '$byteSize'),
        for (final MapEntry(:key, :value) in bound.entries) (key, value),
      ],
      expires: expires,
      time: time,
    );
    return (url: _url(path, query), headers: bound);
  }

  /// A URL anyone holding it can read [key] with until [expires] passes.
  /// [fileName] becomes the name a browser saves the file under.
  Uri presignGet({
    required String key,
    required Duration expires,
    required DateTime time,
    String? fileName,
  }) {
    final path = _path(key);
    final query = _signer.presignedQuery(
      method: 'GET',
      path: path,
      query: [
        if (fileName != null)
          ('response-content-disposition', _inlineDisposition(fileName)),
      ],
      headers: [('host', _host)],
      expires: expires,
      time: time,
    );
    return _url(path, query);
  }

  /// `inline` with the name in both forms of RFC 6266: an ASCII fallback for
  /// old clients, and the exact UTF-8 name.
  static String _inlineDisposition(String fileName) {
    final ascii = fileName.replaceAll(RegExp(r'[^\x20-\x7e]|["\\]'), '_');
    return 'inline; filename="$ascii"; '
        "filename*=UTF-8''${DwSigV4Signer.encode(fileName)}";
  }

  /// The object's size and type, or `null` when there is none.
  Future<DwObjectHead?> head(String key) async {
    final response = await _send('HEAD', _path(key));
    await response.drain<void>();
    if (response.statusCode == HttpStatus.notFound) return null;
    if (response.statusCode != HttpStatus.ok) {
      throw DwStorageException('HEAD', response.statusCode);
    }
    final type = response.headers.contentType;
    return (
      byteSize: response.contentLength,
      contentType: type == null ? '' : type.mimeType.toLowerCase(),
    );
  }

  /// Deletes the object; an absent one is not an error (S3 answers `204`
  /// either way, and a `404` from a stricter storage means the same).
  Future<void> delete(String key) async {
    final response = await _send('DELETE', _path(key));
    final body = await _readError(response);
    if (response.statusCode != HttpStatus.noContent &&
        response.statusCode != HttpStatus.ok &&
        response.statusCode != HttpStatus.notFound) {
      throw DwStorageException('DELETE', response.statusCode, body);
    }
  }

  /// A signed request to the bucket or one of its objects. For the framework
  /// operations above and for tests that set a storage up (a bucket, its
  /// policy); answers the raw response.
  @visibleForTesting
  Future<HttpClientResponse> send(
    String method, {
    String? key,
    List<(String, String)> query = const [],
    List<int> body = const [],
    Map<String, String> headers = const {},
  }) => _send(method, _path(key), query: query, body: body, headers: headers);

  Future<HttpClientResponse> _send(
    String method,
    String path, {
    List<(String, String)> query = const [],
    List<int> body = const [],
    Map<String, String> headers = const {},
  }) async {
    final payloadHash = DwSigV4Signer.hexSha256(body);
    final signed = _signer.authorizationHeaders(
      method: method,
      path: path,
      query: query,
      headers: [
        ('host', _host),
        for (final MapEntry(:key, :value) in headers.entries) (key, value),
      ],
      payloadHash: payloadHash,
      time: DateTime.now(),
    );
    Future<HttpClientResponse> run() async {
      final request = await _http.openUrl(
        method,
        _url(path, DwSigV4Signer.canonicalQuery(query)),
      );
      // `openUrl` has set the host header from the URL — the signed value,
      // port rule included.
      for (final MapEntry(:key, :value) in {...headers, ...signed}.entries) {
        request.headers.set(key, value, preserveHeaderCase: true);
      }
      request.contentLength = body.length;
      if (body.isNotEmpty) request.add(body);
      return request.close();
    }

    return run().timeout(requestTimeout);
  }

  /// S3's `<Code>` from an error body, reading at most a few kilobytes.
  static Future<String?> _readError(HttpClientResponse response) async {
    if (response.statusCode < 300) {
      await response.drain<void>();
      return null;
    }
    final text = await utf8.decoder
        .bind(response)
        .fold<String>(
          '',
          (all, chunk) => all.length > 4096 ? all : all + chunk,
        );
    return RegExp(r'<Code>([^<]+)</Code>').firstMatch(text)?.group(1);
  }

  /// Reads an error code the way [delete] does — for tests of storage setup.
  @visibleForTesting
  static Future<String?> errorCodeOf(HttpClientResponse response) =>
      _readError(response);

  void close() => _http.close(force: true);
}
