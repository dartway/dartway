import 'dart:convert';
import 'dart:typed_data';

/// An HTTP response from a project route.
final class DwHttpResponse {
  /// A response with raw [body] bytes. Header names are case-insensitive;
  /// `Content-Length` is the server's to write.
  DwHttpResponse(
    this.status, {
    Map<String, String> headers = const {},
    List<int>? body,
  }) : headers = Map.unmodifiable(headers),
       body = switch (body) {
         null => Uint8List(0),
         Uint8List() => body,
         _ => Uint8List.fromList(body),
       } {
    if (status < 100 || status > 599) {
      throw ArgumentError.value(status, 'status', 'is not an HTTP status');
    }
  }

  /// [value] encoded as JSON.
  factory DwHttpResponse.json(
    Object? value, {
    int status = 200,
    Map<String, String> headers = const {},
  }) => DwHttpResponse(
    status,
    headers: {'content-type': _json, ...headers},
    body: _jsonUtf8.convert(value),
  );

  /// Plain text.
  factory DwHttpResponse.text(
    String text, {
    int status = 200,
    Map<String, String> headers = const {},
  }) => DwHttpResponse(
    status,
    headers: {'content-type': 'text/plain; charset=utf-8', ...headers},
    body: utf8.encode(text),
  );

  /// No body: `204` by default.
  factory DwHttpResponse.empty({
    int status = 204,
    Map<String, String> headers = const {},
  }) => DwHttpResponse(status, headers: headers);

  static const _json = 'application/json; charset=utf-8';

  static final JsonUtf8Encoder _jsonUtf8 = JsonUtf8Encoder();

  final int status;
  final Map<String, String> headers;
  final Uint8List body;

  @override
  String toString() => 'DwHttpResponse($status, ${body.length} bytes)';
}
