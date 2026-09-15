import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:meta/meta.dart';

/// What a provider's service answered.
@internal
final class DwPushHttpAnswer {
  const DwPushHttpAnswer(this.status, this.headers, this.body);

  final int status;
  final HttpHeaders headers;
  final String body;

  /// `Retry-After` as a delay: whole seconds or an HTTP date.
  Duration? retryAfter(DateTime now) {
    final value = headers.value(HttpHeaders.retryAfterHeader)?.trim();
    if (value == null || value.isEmpty) return null;
    final seconds = int.tryParse(value);
    if (seconds != null) return Duration(seconds: seconds < 0 ? 0 : seconds);
    try {
      final delay = HttpDate.parse(value).difference(now.toUtc());
      return delay.isNegative ? Duration.zero : delay;
    } on FormatException {
      return null;
    }
  }

  /// The body as a JSON object, or `null`.
  Map<String, Object?>? get json {
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, Object?> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  /// The service's words for a failure: `404 NOT_FOUND: <message>`, from the
  /// Google-style `{"error": {"status", "message"}}` body both providers
  /// answer with, or the start of the raw body when it is not that.
  String describe(String service) {
    final error = json?['error'];
    final text = switch (error) {
      {'status': final Object? status, 'message': final Object? message} =>
        '${status ?? ''}: ${message ?? ''}',
      {'message': final Object? message} => '$message',
      final String code => '$code${_description()}',
      _ => body.length > 300 ? '${body.substring(0, 300)}…' : body,
    };
    return '$service $status $text'.trim();
  }

  String _description() => switch (json?['error_description']) {
    final String description => ': $description',
    _ => '',
  };
}

/// A small HTTP client for provider APIs over `dart:io`.
@internal
final class DwPushHttp {
  DwPushHttp({required this.timeout})
    : _client = HttpClient()
        ..connectionTimeout = timeout
        ..idleTimeout = const Duration(seconds: 30);

  final Duration timeout;
  final HttpClient _client;

  /// Answers are small; anything longer is a proxy's error page.
  static const int maxAnswerBytes = 64 << 10;

  Future<DwPushHttpAnswer> post(
    Uri uri, {
    required Map<String, String> headers,
    required String body,
  }) async {
    final request = await _client.postUrl(uri).timeout(timeout);
    final bytes = utf8.encode(body);
    headers.forEach(request.headers.set);
    request.contentLength = bytes.length;
    request.add(bytes);
    final response = await request.close().timeout(timeout);
    final buffer = BytesBuilder(copy: false);
    await for (final chunk in response.timeout(timeout)) {
      if (buffer.length < maxAnswerBytes) buffer.add(chunk);
    }
    final taken = buffer.takeBytes();
    return DwPushHttpAnswer(
      response.statusCode,
      response.headers,
      utf8.decode(
        taken.length > maxAnswerBytes
            ? taken.sublist(0, maxAnswerBytes)
            : taken,
        allowMalformed: true,
      ),
    );
  }

  void close() => _client.close(force: true);
}
