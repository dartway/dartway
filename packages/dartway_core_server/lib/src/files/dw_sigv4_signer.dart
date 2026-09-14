import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:meta/meta.dart';

/// AWS Signature Version 4, as S3 and every S3-compatible storage accept it.
///
/// Written here rather than taken from an S3 SDK: the framework needs four
/// operations (a presigned PUT and GET, a signed HEAD and DELETE), and an SDK
/// is thousands of lines, a release cycle and a platform story for those
/// four. The algorithm is small and fixed, and it is pinned by AWS's
/// published test vectors (`test/files_signing_test.dart`) as well as by
/// real requests against MinIO.
///
/// Paths and query parameters are given **decoded**; the signer encodes them
/// exactly once, the way S3 expects (the generic services of the AWS test
/// suite additionally normalise and double-encode paths, which S3 never
/// does, so only vectors whose path those steps leave unchanged apply).
/// The URLs it builds are built from the same encoding, so what is signed is
/// byte for byte what is sent.
@internal
final class DwSigV4Signer {
  DwSigV4Signer({
    required this.accessKey,
    required String secretKey,
    required this.region,
    this.service = 's3',
  }) : _secretKey = secretKey;

  final String accessKey;
  final String _secretKey;
  final String region;
  final String service;

  static const String algorithm = 'AWS4-HMAC-SHA256';

  /// The payload hash of a presigned request: the body is not known when the
  /// URL is made.
  static const String unsignedPayload = 'UNSIGNED-PAYLOAD';

  /// SHA-256 of the empty body.
  static final String emptyPayloadHash = hexSha256(const []);

  /// The last signing key, by date: it changes once a day, and deriving it
  /// is four HMACs.
  String? _keyDate;
  List<int>? _key;

  static String hexSha256(List<int> bytes) => sha256.convert(bytes).toString();

  /// `20130524T000000Z`.
  static String amzDate(DateTime time) {
    final utc = time.toUtc();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${utc.year.toString().padLeft(4, '0')}${two(utc.month)}'
        '${two(utc.day)}T${two(utc.hour)}${two(utc.minute)}${two(utc.second)}Z';
  }

  /// RFC 3986 encoding as SigV4 defines it: every byte of the UTF-8 form
  /// except the unreserved `A-Z a-z 0-9 - . _ ~` as `%XX` in upper case, and
  /// `/` kept only when [keepSlash] (path segments).
  static String encode(String value, {bool keepSlash = false}) {
    final buffer = StringBuffer();
    for (final byte in utf8.encode(value)) {
      final unreserved =
          (byte >= 0x41 && byte <= 0x5a) ||
          (byte >= 0x61 && byte <= 0x7a) ||
          (byte >= 0x30 && byte <= 0x39) ||
          byte == 0x2d ||
          byte == 0x2e ||
          byte == 0x5f ||
          byte == 0x7e ||
          (keepSlash && byte == 0x2f);
      if (unreserved) {
        buffer.writeCharCode(byte);
      } else {
        buffer
          ..write('%')
          ..write(byte.toRadixString(16).toUpperCase().padLeft(2, '0'));
      }
    }
    return buffer.toString();
  }

  /// Query parameters sorted by encoded name, then encoded value, joined as
  /// the canonical query string — also the query the built URLs carry.
  static String canonicalQuery(List<(String, String)> parameters) {
    final encoded =
        [for (final (name, value) in parameters) (encode(name), encode(value))]
          ..sort((a, b) {
            final byName = a.$1.compareTo(b.$1);
            return byName != 0 ? byName : a.$2.compareTo(b.$2);
          });
    return encoded.map((pair) => '${pair.$1}=${pair.$2}').join('&');
  }

  /// Header names lower-cased and sorted; values trimmed with runs of spaces
  /// collapsed; repeated headers joined with commas in their order.
  static ({String canonical, String signed}) canonicalHeaders(
    List<(String, String)> headers,
  ) {
    final grouped = <String, List<String>>{};
    for (final (name, value) in headers) {
      grouped
          .putIfAbsent(name.toLowerCase(), () => [])
          .add(value.trim().replaceAll(RegExp(r'\s+'), ' '));
    }
    final names = grouped.keys.toList()..sort();
    return (
      canonical: names
          .map((name) => '$name:${grouped[name]!.join(',')}\n')
          .join(),
      signed: names.join(';'),
    );
  }

  /// The canonical request of SigV4 step 1.
  static String canonicalRequest({
    required String method,
    required String path,
    required List<(String, String)> query,
    required List<(String, String)> headers,
    required String payloadHash,
  }) {
    final canonical = canonicalHeaders(headers);
    return [
      method,
      encode(path, keepSlash: true),
      canonicalQuery(query),
      canonical.canonical,
      canonical.signed,
      payloadHash,
    ].join('\n');
  }

  String scope(DateTime time) =>
      '${amzDate(time).substring(0, 8)}/$region/$service/aws4_request';

  /// The string to sign of SigV4 step 2.
  String stringToSign(DateTime time, String canonicalRequest) => [
    algorithm,
    amzDate(time),
    scope(time),
    hexSha256(utf8.encode(canonicalRequest)),
  ].join('\n');

  /// The signature of SigV4 steps 3 and 4.
  String signature(DateTime time, String stringToSign) {
    final date = amzDate(time).substring(0, 8);
    if (_keyDate != date) {
      List<int> hmac(List<int> key, String data) =>
          Hmac(sha256, key).convert(utf8.encode(data)).bytes;
      final dateKey = hmac(utf8.encode('AWS4$_secretKey'), date);
      final regionKey = hmac(dateKey, region);
      final serviceKey = hmac(regionKey, service);
      _key = hmac(serviceKey, 'aws4_request');
      _keyDate = date;
    }
    return Hmac(sha256, _key!).convert(utf8.encode(stringToSign)).toString();
  }

  /// Signs a request with the `Authorization` header.
  ///
  /// [headers] must hold `host` and every header to be signed; the answer is
  /// the headers to send in addition: `x-amz-date`, the payload hash (S3
  /// requires `x-amz-content-sha256` on every header-signed request) and
  /// `authorization`.
  Map<String, String> authorizationHeaders({
    required String method,
    required String path,
    List<(String, String)> query = const [],
    required List<(String, String)> headers,
    required String payloadHash,
    required DateTime time,
    bool includeContentHash = true,
  }) {
    final date = amzDate(time);
    final all = [
      ...headers,
      ('x-amz-date', date),
      if (includeContentHash) ('x-amz-content-sha256', payloadHash),
    ];
    final canonical = canonicalRequest(
      method: method,
      path: path,
      query: query,
      headers: all,
      payloadHash: payloadHash,
    );
    final signed = canonicalHeaders(all).signed;
    final signatureValue = signature(time, stringToSign(time, canonical));
    return {
      'x-amz-date': date,
      if (includeContentHash) 'x-amz-content-sha256': payloadHash,
      'authorization':
          '$algorithm Credential=$accessKey/${scope(time)}, '
          'SignedHeaders=$signed, Signature=$signatureValue',
    };
  }

  /// The query of a presigned request, signature included, in canonical
  /// order: append it to the encoded path.
  ///
  /// [headers] must hold `host` and every header the caller will be bound
  /// to send with these values.
  String presignedQuery({
    required String method,
    required String path,
    List<(String, String)> query = const [],
    required List<(String, String)> headers,
    required Duration expires,
    required DateTime time,
  }) {
    final signed = canonicalHeaders(headers).signed;
    final parameters = [
      ...query,
      ('X-Amz-Algorithm', algorithm),
      ('X-Amz-Credential', '$accessKey/${scope(time)}'),
      ('X-Amz-Date', amzDate(time)),
      ('X-Amz-Expires', '${expires.inSeconds}'),
      ('X-Amz-SignedHeaders', signed),
    ];
    final canonical = canonicalRequest(
      method: method,
      path: path,
      query: parameters,
      headers: headers,
      payloadHash: unsignedPayload,
    );
    final signatureValue = signature(time, stringToSign(time, canonical));
    return '${canonicalQuery(parameters)}&X-Amz-Signature=$signatureValue';
  }
}
