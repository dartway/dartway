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

/// The storage operations the framework needs, over `dart:io` and
/// [DwSigV4Signer], for any bucket of one storage: a presigned PUT and GET for
/// clients, signed requests for the server itself, and an unsigned GET for
/// checking what anyone without keys can read.
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

  /// The authority requests to [bucket] go to, as the `host` header carries
  /// it: with the port only when it is not the scheme's default, which is
  /// what HTTP clients send and therefore what the signature must cover.
  String _host(String bucket) {
    final endpoint = config.endpoint;
    final host = config.pathStyle ? endpoint.host : '$bucket.${endpoint.host}';
    return endpoint.hasPort ? '$host:${endpoint.port}' : host;
  }

  /// The decoded path of [key]'s object in [bucket] (of the bucket itself for
  /// a null key).
  String _path(String bucket, String? key) {
    final prefix = config.pathStyle ? '/$bucket' : '';
    return key == null ? (prefix.isEmpty ? '/' : prefix) : '$prefix/$key';
  }

  /// A URL with the path encoded exactly as it is signed; `Uri.parse` keeps
  /// that encoding.
  Uri _url(String bucket, String path, [String query = '']) => Uri.parse(
    '${config.endpoint.scheme}://${_host(bucket)}'
    '${DwSigV4Signer.encode(path, keepSlash: true)}'
    '${query.isEmpty ? '' : '?$query'}',
  );

  /// The unsigned URL of [key] in [bucket] (of the bucket for a null key),
  /// with [query]: what someone without keys would request.
  Uri urlOf(
    String bucket, {
    String? key,
    List<(String, String)> query = const [],
  }) => _url(bucket, _path(bucket, key), DwSigV4Signer.canonicalQuery(query));

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
    required String bucket,
    required String key,
    required String contentType,
    required int byteSize,
    required Duration expires,
    required DateTime time,
  }) {
    final path = _path(bucket, key);
    final bound = {'content-type': contentType, 'if-none-match': '*'};
    final query = _signer.presignedQuery(
      method: 'PUT',
      path: path,
      headers: [
        ('host', _host(bucket)),
        ('content-length', '$byteSize'),
        for (final MapEntry(:key, :value) in bound.entries) (key, value),
      ],
      expires: expires,
      time: time,
    );
    return (url: _url(bucket, path, query), headers: bound);
  }

  /// A URL anyone holding it can read [key] in [bucket] with until [expires]
  /// passes. [fileName] becomes the name a browser saves the file under.
  Uri presignGet({
    required String bucket,
    required String key,
    required Duration expires,
    required DateTime time,
    String? fileName,
  }) {
    final path = _path(bucket, key);
    final query = _signer.presignedQuery(
      method: 'GET',
      path: path,
      query: [
        if (fileName != null)
          ('response-content-disposition', _inlineDisposition(fileName)),
      ],
      headers: [('host', _host(bucket))],
      expires: expires,
      time: time,
    );
    return _url(bucket, path, query);
  }

  /// `inline` with the name in both forms of RFC 6266: an ASCII fallback for
  /// old clients, and the exact UTF-8 name.
  static String _inlineDisposition(String fileName) {
    final ascii = fileName.replaceAll(RegExp(r'[^\x20-\x7e]|["\\]'), '_');
    return 'inline; filename="$ascii"; '
        "filename*=UTF-8''${DwSigV4Signer.encode(fileName)}";
  }

  /// The object's size and type, or `null` when there is none.
  Future<DwObjectHead?> head(String bucket, String key) async {
    final response = await send('HEAD', bucket: bucket, key: key);
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

  /// The object's bytes, or `null` when there is none. Reads at most
  /// [maxBytes]: more than that is a storage that no longer holds what the
  /// row describes, and it throws rather than buffering it.
  Future<List<int>?> get(
    String bucket,
    String key, {
    required int maxBytes,
  }) async {
    final response = await send('GET', bucket: bucket, key: key);
    if (response.statusCode == HttpStatus.notFound) {
      await response.drain<void>();
      return null;
    }
    if (response.statusCode != HttpStatus.ok) {
      throw DwStorageException(
        'GET',
        response.statusCode,
        await errorCodeOf(response),
      );
    }
    final bytes = <int>[];
    await for (final chunk in response) {
      bytes.addAll(chunk);
      if (bytes.length > maxBytes) {
        throw DwStorageException('GET', response.statusCode, 'TooLarge');
      }
    }
    return bytes;
  }

  /// Stores [bytes] under [key], on the condition that the key is free: the
  /// same `if-none-match: *` a client's upload ticket carries, so a server
  /// write cannot overwrite an object either.
  Future<void> put(
    String bucket,
    String key, {
    required List<int> bytes,
    required String contentType,
  }) async {
    final response = await send(
      'PUT',
      bucket: bucket,
      key: key,
      body: bytes,
      headers: {'content-type': contentType, 'if-none-match': '*'},
    );
    final code = await errorCodeOf(response);
    if (response.statusCode != HttpStatus.ok) {
      throw DwStorageException('PUT', response.statusCode, code);
    }
  }

  /// Deletes the object; an absent one is not an error (S3 answers `204`
  /// either way, and a `404` from a stricter storage means the same).
  Future<void> delete(String bucket, String key) async {
    final response = await send('DELETE', bucket: bucket, key: key);
    final code = await errorCodeOf(response);
    if (response.statusCode != HttpStatus.noContent &&
        response.statusCode != HttpStatus.ok &&
        response.statusCode != HttpStatus.notFound) {
      throw DwStorageException('DELETE', response.statusCode, code);
    }
  }

  /// A signed request to [bucket] or one of its objects, answered raw: for
  /// the operations above, for setting buckets up and for checking them.
  Future<HttpClientResponse> send(
    String method, {
    required String bucket,
    String? key,
    List<(String, String)> query = const [],
    List<int> body = const [],
    Map<String, String> headers = const {},
  }) {
    final path = _path(bucket, key);
    final signed = _signer.authorizationHeaders(
      method: method,
      path: path,
      query: query,
      headers: [
        ('host', _host(bucket)),
        for (final MapEntry(:key, :value) in headers.entries) (key, value),
      ],
      payloadHash: DwSigV4Signer.hexSha256(body),
      time: DateTime.now(),
    );
    Future<HttpClientResponse> run() async {
      final request = await _http.openUrl(
        method,
        _url(bucket, path, DwSigV4Signer.canonicalQuery(query)),
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

  /// A GET of [url] without credentials, as anyone could send it. The body is
  /// kept up to [maxBytes] and the rest drained.
  ///
  /// On a connection of its own, closed after the answer: MinIO at times
  /// drops the connection right after refusing an anonymous read, and a
  /// request that picked it up from the pool would fail with "connection
  /// closed before full header" — a check reporting storage as unreachable
  /// when it only said no.
  Future<({int status, List<int> body})> anonymousGet(
    Uri url, {
    int maxBytes = 64 * 1024,
  }) {
    Future<({int status, List<int> body})> run() async {
      final request = await _http.getUrl(url);
      request.persistentConnection = false;
      final response = await request.close();
      final body = <int>[];
      await for (final chunk in response) {
        if (body.length < maxBytes) body.addAll(chunk);
      }
      return (status: response.statusCode, body: body);
    }

    return run().timeout(requestTimeout);
  }

  /// S3's `<Code>` from an error body, reading at most a few kilobytes; a
  /// successful response is drained and answers `null`.
  static Future<String?> errorCodeOf(HttpClientResponse response) async {
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

  void close() => _http.close(force: true);
}
