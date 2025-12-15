import 'dart:convert';
import 'dart:io';

/// Обёртка над [HttpClient] с поддержкой прокси и отправкой JSON-запросов.
class DwTinkoffHttpClient {
  DwTinkoffHttpClient({
    String? proxyAddress,
    String? proxyCredentials,
  }) {
    _client = HttpClient()..badCertificateCallback = (_, __, ___) => true;

    if (proxyAddress != null && proxyCredentials != null) {
      _client.findProxy = (_) => "PROXY $proxyCredentials@$proxyAddress";
    }
  }

  late final HttpClient _client;

  /// Выполняет POST-запрос с JSON-пейлоадом и возвращает [SimpleHttpResponse]
  Future<SimpleHttpResponse> postJson(
    Uri uri,
    Map<String, Object?> body,
  ) async {
    final request = await _client.postUrl(uri);
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode(body));

    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();

    return SimpleHttpResponse(
      statusCode: response.statusCode,
      reasonPhrase: response.reasonPhrase,
      body: responseBody,
    );
  }

  /// Закрывает underlying [HttpClient]
  void close() => _client.close(force: true);
}

/// Упрощённый ответ от клиента
class SimpleHttpResponse {
  final int statusCode;
  final String? reasonPhrase;
  final String body;

  SimpleHttpResponse({
    required this.statusCode,
    required this.reasonPhrase,
    required this.body,
  });
}
