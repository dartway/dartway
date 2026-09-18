import 'dart:convert';
import 'dart:io';

import 'package:meta/meta.dart';

/// What Apple answered a form post: its status and its body.
typedef DwAppleAnswer = ({int status, Map<String, Object?> body});

/// Posts a form to one of Apple's endpoints. Replaced in tests, and by a
/// project that wants its own HTTP client.
typedef DwApplePost =
    Future<DwAppleAnswer> Function(Uri uri, Map<String, String> form);

/// Apple's token endpoints: the one that turns a one-time authorization code
/// into a refresh token, and the one that gives that refresh token back when
/// the person leaves.
///
/// Both are `application/x-www-form-urlencoded` and both want the app's
/// **client secret** — a JWT the project signs with its `.p8` key. Nothing
/// here holds a secret of its own; it is minted per call.
@internal
final class DwAppleEndpoint {
  const DwAppleEndpoint({DwApplePost? post}) : _post = post ?? _postOverHttp;

  final DwApplePost _post;

  static final Uri tokenUri = Uri.https('appleid.apple.com', '/auth/token');
  static final Uri revokeUri = Uri.https('appleid.apple.com', '/auth/revoke');

  /// The refresh token for [code], or null when Apple did not give one.
  ///
  /// Throws [DwAppleRefused] when Apple answered a failure: the caller decides
  /// whether that ends a sign-in (it does not — the sign-in is already proved
  /// by the identity token) or is worth retrying.
  Future<String?> refreshTokenFor({
    required String code,
    required String clientId,
    required String clientSecret,
  }) async {
    final answer = await _post(tokenUri, {
      'grant_type': 'authorization_code',
      'code': code,
      'client_id': clientId,
      'client_secret': clientSecret,
    });
    if (answer.status != 200) throw DwAppleRefused(tokenUri, answer);
    final token = answer.body['refresh_token'];
    return token is String && token.isNotEmpty ? token : null;
  }

  /// Tells Apple that [refreshToken] is no longer this app's — what deleting
  /// an account owes a person who signed in with Apple.
  Future<void> revoke({
    required String refreshToken,
    required String clientId,
    required String clientSecret,
  }) async {
    final answer = await _post(revokeUri, {
      'token': refreshToken,
      'token_type_hint': 'refresh_token',
      'client_id': clientId,
      'client_secret': clientSecret,
    });
    // Apple answers 200 with an empty body, and keeps answering 200 for a
    // token it has already forgotten — so a repeat of the job is harmless.
    if (answer.status != 200) throw DwAppleRefused(revokeUri, answer);
  }

  static Future<DwAppleAnswer> _postOverHttp(
    Uri uri,
    Map<String, String> form,
  ) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType(
        'application',
        'x-www-form-urlencoded',
      );
      request.write(
        form.entries
            .map(
              (e) =>
                  '${Uri.encodeQueryComponent(e.key)}='
                  '${Uri.encodeQueryComponent(e.value)}',
            )
            .join('&'),
      );
      final response = await request.close().timeout(
        const Duration(seconds: 15),
      );
      final text = await response
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 15));
      final decoded = text.trim().isEmpty ? null : jsonDecode(text);
      return (
        status: response.statusCode,
        body: decoded is Map<String, Object?> ? decoded : <String, Object?>{},
      );
    } finally {
      client.close(force: true);
    }
  }
}

/// Apple answered a failure. Its `error` is the useful part; the message is
/// for the server's log, never for the app.
final class DwAppleRefused implements Exception {
  const DwAppleRefused(this.uri, this.answer);

  final Uri uri;
  final DwAppleAnswer answer;

  String get error => switch (answer.body['error']) {
    final String code => code,
    _ => 'status ${answer.status}',
  };

  @override
  String toString() => 'Apple refused $uri: $error';
}
