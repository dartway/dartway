import 'package:http/http.dart' as http;

/// Minimal HTTP request used by built-in server-side push providers.
final class DwPushHttpRequest {
  DwPushHttpRequest({
    required this.method,
    required this.uri,
    required Map<String, String> headers,
    required this.body,
  }) : headers = Map.unmodifiable({
         for (final entry in headers.entries)
           entry.key.toLowerCase(): entry.value,
       });

  final String method;
  final Uri uri;
  final Map<String, String> headers;
  final String body;
}

/// Minimal HTTP response exposed for deterministic provider tests.
abstract interface class DwPushHttpResponse {
  int get statusCode;
  Map<String, String> get headers;
  String get body;
}

/// Injectable HTTP boundary for built-in push providers.
abstract interface class DwPushHttpClient {
  Future<DwPushHttpResponse> send(DwPushHttpRequest request);
}

final class DwPushDefaultHttpClient implements DwPushHttpClient {
  DwPushDefaultHttpClient({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  @override
  Future<DwPushHttpResponse> send(DwPushHttpRequest request) async {
    if (request.method != 'POST') {
      throw ArgumentError.value(
        request.method,
        'request.method',
        'Built-in push providers support POST requests only',
      );
    }
    final response = await _client.post(
      request.uri,
      headers: request.headers,
      body: request.body,
    );
    return _DwPushHttpResponse(
      statusCode: response.statusCode,
      headers: response.headers,
      body: response.body,
    );
  }
}

final class _DwPushHttpResponse implements DwPushHttpResponse {
  _DwPushHttpResponse({
    required this.statusCode,
    required Map<String, String> headers,
    required this.body,
  }) : headers = Map.unmodifiable({
         for (final entry in headers.entries)
           entry.key.toLowerCase(): entry.value,
       });

  @override
  final int statusCode;

  @override
  final Map<String, String> headers;

  @override
  final String body;
}
