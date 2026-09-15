import 'dart:async';
import 'dart:convert';

import 'package:dartway_push_shared/dartway_push_shared.dart';

import 'dw_push_http.dart';
import 'dw_push_provider.dart';
import 'dw_rsa_signer.dart';

/// A Google service account allowed to send through FCM: the JSON file the
/// Firebase console issues (Project settings → Service accounts).
///
/// Read once, at startup: a malformed file, a missing field or a key that is
/// not RSA throws [FormatException] naming what is wrong, before the server
/// takes a call — not at the first send.
final class DwFcmServiceAccount {
  DwFcmServiceAccount._({
    required this.projectId,
    required this.clientEmail,
    required this.privateKeyId,
    required this.tokenUri,
    required DwRsaSigner signer,
  }) : _signer = signer;

  /// Reads the service account [json] (the file's text).
  factory DwFcmServiceAccount.fromJson(String json) {
    final Object? decoded;
    try {
      decoded = jsonDecode(json);
    } on FormatException catch (error) {
      throw FormatException(
        'The FCM service account is not JSON (${error.message}); a truncated '
        'upload or an unquoted YAML value looks like this',
      );
    }
    if (decoded is! Map<String, Object?>) {
      throw const FormatException(
        'The FCM service account is not a JSON object',
      );
    }
    final document = decoded;
    String field(String name) => switch (document[name]) {
      final String value when value.trim().isNotEmpty => value.trim(),
      _ => throw FormatException(
        'The FCM service account has no "$name"; use the file Firebase '
        'issues, unchanged',
      ),
    };
    if (decoded['type'] != 'service_account') {
      throw const FormatException(
        'The FCM credential is not a service account ("type" is not '
        '"service_account")',
      );
    }
    final tokenUri = Uri.tryParse(
      (decoded['token_uri'] as String?) ??
          'https://oauth2.googleapis.com/token',
    );
    if (tokenUri == null || !tokenUri.hasScheme) {
      throw const FormatException(
        'The FCM service account "token_uri" is not a URL',
      );
    }
    return DwFcmServiceAccount._(
      projectId: field('project_id'),
      clientEmail: field('client_email'),
      privateKeyId: field('private_key_id'),
      tokenUri: tokenUri,
      signer: DwRsaSigner.fromPem(field('private_key')),
    );
  }

  final String projectId;
  final String clientEmail;
  final String privateKeyId;

  /// Where an access token is asked for.
  final Uri tokenUri;

  final DwRsaSigner _signer;

  static const String scope =
      'https://www.googleapis.com/auth/firebase.messaging';

  /// A signed OAuth assertion valid for an hour from [now].
  String assertion(DateTime now) {
    String part(Object value) =>
        base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
    final issuedAt = now.toUtc().millisecondsSinceEpoch ~/ 1000;
    final signingInput =
        '${part({'alg': 'RS256', 'typ': 'JWT', 'kid': privateKeyId})}.'
        '${part({'iss': clientEmail, 'scope': scope, 'aud': tokenUri.toString(), 'iat': issuedAt, 'exp': issuedAt + 3600})}';
    final signature = base64Url
        .encode(_signer.sign(utf8.encode(signingInput)))
        .replaceAll('=', '');
    return '$signingInput.$signature';
  }

  @override
  String toString() => 'DwFcmServiceAccount($projectId, $clientEmail)';
}

/// Firebase Cloud Messaging, HTTP v1 API, for Android, iOS and web devices.
///
/// The OAuth access token is asked for with a signed assertion, cached until
/// five minutes before it expires, and shared by concurrent sends (one
/// refresh at a time); a `401` drops it and the send is tried once more with
/// a fresh one.
///
/// Answers are classified by FCM's documented error codes:
///
/// | FCM answer | outcome |
/// |---|---|
/// | `UNREGISTERED` (404), `SENDER_ID_MISMATCH` (403), `INVALID_ARGUMENT` about the registration token | token invalid — the registration is removed |
/// | `QUOTA_EXCEEDED` (429), `UNAVAILABLE` (503), `INTERNAL` (500), 408, `UNAUTHENTICATED` after a fresh token | retry later, after `Retry-After` |
/// | anything else, e.g. `THIRD_PARTY_AUTH_ERROR`, other `INVALID_ARGUMENT` | rejected for this device |
///
/// An `INVALID_ARGUMENT` that is not about the token (a data key FCM
/// reserves, a message too big) keeps the token: deleting live registrations
/// over a malformed message would silence every device at once.
final class DwFcmProvider implements DwPushProvider {
  DwFcmProvider({
    required this.account,
    this.webLinkBase,
    this.androidChannelId,
    this.androidIcon,
    this.androidColor,
    this.webIcon,
    Uri? endpoint,
    Duration requestTimeout = const Duration(seconds: 10),
    DateTime Function()? clock,
  }) : endpoint = endpoint ?? Uri.parse('https://fcm.googleapis.com'),
       _http = DwPushHttp(timeout: requestTimeout),
       _clock = clock ?? DateTime.now {
    if (webLinkBase case final base? when base.scheme != 'https') {
      throw ArgumentError.value(
        base,
        'webLinkBase',
        'FCM opens web links over https only',
      );
    }
  }

  final DwFcmServiceAccount account;

  /// The web app's origin (`https://app.example.com`). With it, a web
  /// notification carries `webpush.fcm_options.link` — the message's link on
  /// this origin — so the browser opens the right page even where the
  /// service worker's click handler does not run.
  final Uri? webLinkBase;

  final String? androidChannelId;
  final String? androidIcon;

  /// `#rrggbb`.
  final String? androidColor;
  final String? webIcon;

  /// FCM's base URL; a test points it at a local fake.
  final Uri endpoint;

  final DwPushHttp _http;
  final DateTime Function() _clock;

  ({String value, DateTime refreshAt})? _accessToken;
  Future<String>? _refreshing;

  @override
  DwPushTransport get transport => DwPushTransport.fcm;

  @override
  Future<DwPushOutcome> send(DwPushRequest request) async {
    final body = jsonEncode(messageOf(request));
    final DwPushHttpAnswer answer;
    try {
      answer = await _post(body, await _token());
      if (answer.status == 401 &&
          _fcmCode(answer) != 'THIRD_PARTY_AUTH_ERROR') {
        _accessToken = null;
        return _classify(await _post(body, await _token()));
      }
    } on DwFcmAuthFailure catch (failure) {
      return DwPushRetryLater(failure.reason);
    }
    return _classify(answer);
  }

  Future<DwPushHttpAnswer> _post(String body, String token) => _http.post(
    endpoint.replace(path: '/v1/projects/${account.projectId}/messages:send'),
    headers: {
      'authorization': 'Bearer $token',
      'content-type': 'application/json; charset=utf-8',
    },
    body: body,
  );

  /// The v1 `message` for [request].
  Map<String, Object?> messageOf(DwPushRequest request) {
    final ttl = request.ttl;
    final image = request.imageUrl;
    final link = switch ((webLinkBase, request.link)) {
      (final base?, final link?) => '${_withoutTrailingSlash(base)}$link',
      _ => null,
    };
    return {
      'message': {
        'token': request.token,
        'notification': {
          'title': request.title,
          'body': ?request.body,
          'image': ?image,
        },
        if (request.data.isNotEmpty) 'data': request.data,
        'android': {
          if (ttl != null) 'ttl': '${ttl.inSeconds}s',
          if (androidChannelId != null ||
              androidIcon != null ||
              androidColor != null)
            'notification': {
              'channel_id': ?androidChannelId,
              'icon': ?androidIcon,
              'color': ?androidColor,
            },
        },
        'apns': {
          if (ttl != null)
            'headers': {
              'apns-expiration':
                  '${_clock().add(ttl).toUtc().millisecondsSinceEpoch ~/ 1000}',
            },
          'payload': {
            'aps': {
              'sound': 'default',
              if (image != null) 'mutable-content': 1,
            },
          },
          if (image != null) 'fcm_options': {'image': image},
        },
        if (ttl != null || link != null || webIcon != null)
          'webpush': {
            if (ttl != null) 'headers': {'TTL': '${ttl.inSeconds}'},
            if (webIcon != null) 'notification': {'icon': webIcon},
            if (link != null) 'fcm_options': {'link': link},
          },
      },
    };
  }

  static String _withoutTrailingSlash(Uri base) {
    final text = base.toString();
    return text.endsWith('/') ? text.substring(0, text.length - 1) : text;
  }

  DwPushOutcome _classify(DwPushHttpAnswer answer) {
    if (answer.status == 200) return const DwPushAccepted();
    final reason = _describe(answer);
    final code = _fcmCode(answer);
    final message = switch (answer.json?['error']) {
      {'message': final String message} => message.toLowerCase(),
      _ => '',
    };
    final aboutToken =
        (code == 'INVALID_ARGUMENT' || answer.status == 400) &&
        message.contains('registration token');
    if (code == 'UNREGISTERED' || code == 'SENDER_ID_MISMATCH' || aboutToken) {
      return DwPushTokenInvalid(reason);
    }
    if (answer.status == 408 ||
        answer.status == 429 ||
        (answer.status == 401 && code != 'THIRD_PARTY_AUTH_ERROR') ||
        answer.status >= 500) {
      return DwPushRetryLater(reason, retryAfter: answer.retryAfter(_clock()));
    }
    return DwPushRejected(reason);
  }

  String _describe(DwPushHttpAnswer answer) {
    final code = _fcmCode(answer);
    final text = answer.describe('fcm');
    return code == null || text.contains(code) ? text : '$text ($code)';
  }

  /// The `errorCode` of FCM's own error detail, when the answer has one.
  static String? _fcmCode(DwPushHttpAnswer answer) {
    final details = switch (answer.json?['error']) {
      {'details': final List<Object?> details} => details,
      _ => const <Object?>[],
    };
    for (final detail in details) {
      if (detail case {
        '@type': 'type.googleapis.com/google.firebase.fcm.v1.FcmError',
        'errorCode': final String code,
      }) {
        return code;
      }
    }
    return null;
  }

  Future<String> _token() {
    final cached = _accessToken;
    if (cached != null && _clock().isBefore(cached.refreshAt)) {
      return Future.value(cached.value);
    }
    return _refreshing ??= _fetchToken().whenComplete(() => _refreshing = null);
  }

  Future<String> _fetchToken() async {
    final now = _clock();
    final answer = await _http.post(
      account.tokenUri,
      headers: {'content-type': 'application/x-www-form-urlencoded'},
      body:
          'grant_type=${Uri.encodeQueryComponent('urn:ietf:params:oauth:grant-type:jwt-bearer')}'
          '&assertion=${account.assertion(now)}',
    );
    final json = answer.json;
    final value = json?['access_token'];
    if (answer.status != 200 || value is! String) {
      throw DwFcmAuthFailure('fcm oauth ${answer.describe('').trim()}');
    }
    final seconds = switch (json?['expires_in']) {
      final num value => value.toInt(),
      _ => 3600,
    };
    _accessToken = (
      value: value,
      refreshAt: now.add(Duration(seconds: seconds - 300)),
    );
    return value;
  }

  @override
  Future<void> close() async => _http.close();
}

/// The OAuth token endpoint refused the service account or failed.
final class DwFcmAuthFailure implements Exception {
  const DwFcmAuthFailure(this.reason);

  final String reason;

  @override
  String toString() => 'DwFcmAuthFailure: $reason';
}
