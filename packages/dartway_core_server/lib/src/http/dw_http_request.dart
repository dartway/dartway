import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:meta/meta.dart';

import 'dw_request_body.dart';

/// An HTTP request to a project route: the few things a door needs, over
/// `dart:io`, without exposing it.
final class DwHttpRequest {
  @internal
  DwHttpRequest(this._request, this._body, {required this.maxBodyBytes})
    : headers = _headersOf(_request.headers);

  final HttpRequest _request;
  final DwRequestBody _body;

  /// The server's body limit, used when a read names none.
  final int maxBodyBytes;

  /// Upper case: `GET`, `POST`.
  String get method => _request.method;

  /// The path, without the query.
  String get path => _request.uri.path;

  /// Header values by lower-case name; repeated headers are joined with `,`.
  final Map<String, String> headers;

  /// The query parameters; a repeated one keeps its last value.
  Map<String, String> get query => _request.uri.queryParameters;

  /// Every value of every query parameter.
  Map<String, List<String>> get queryAll => _request.uri.queryParametersAll;

  /// The whole body, at most [maxBytes] (the server's limit by default).
  ///
  /// Throws [DwRequestBodyException]: a route that does not catch it answers
  /// its status — 413 over the limit, 408 when the body is late.
  Future<Uint8List> bytes({int? maxBytes}) =>
      _body.read(maxBytes ?? maxBodyBytes);

  /// The body as UTF-8 text. Throws [DwRequestBodyException] (400) for bytes
  /// that are not UTF-8, as well as the failures of [bytes].
  Future<String> text({int? maxBytes}) async {
    final body = await bytes(maxBytes: maxBytes);
    try {
      return utf8.decode(body);
    } on FormatException {
      throw const DwRequestBodyException.malformed('the body is not UTF-8');
    }
  }

  /// The body as JSON. Throws [DwRequestBodyException] (400) for a body that
  /// is not JSON, as well as the failures of [text].
  Future<Object?> json({int? maxBytes}) async {
    final body = await text(maxBytes: maxBytes);
    try {
      return jsonDecode(body);
    } on FormatException {
      throw const DwRequestBodyException.malformed('the body is not JSON');
    }
  }

  static Map<String, String> _headersOf(HttpHeaders headers) {
    final map = <String, String>{};
    headers.forEach((name, values) => map[name] = values.join(','));
    return Map.unmodifiable(map);
  }
}
