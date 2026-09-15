import 'dart:convert';

import 'package:dartway_push_shared/dartway_push_shared.dart';

import 'dw_push_http.dart';
import 'dw_push_provider.dart';

/// RuStore push (VK Push), for Android devices with RuStore:
/// `POST /v1/projects/<projectId>/messages:send` with the project's service
/// token.
///
/// Answers are classified by RuStore's documented codes:
///
/// | RuStore answer | outcome |
/// |---|---|
/// | 404 `NOT_FOUND` ("wrong push token"), 400 `INVALID_ARGUMENT` about the token | token invalid — the registration is removed |
/// | 429, 5xx, 408, 401/403 (a service token being replaced) | retry later |
/// | any other 400 | rejected for this device |
final class DwRuStoreProvider implements DwPushProvider {
  DwRuStoreProvider({
    required this.projectId,
    required String serviceToken,
    this.androidChannelId,
    this.androidIcon,
    this.androidColor,
    Uri? endpoint,
    Duration requestTimeout = const Duration(seconds: 10),
    DateTime Function()? clock,
  }) : _serviceToken = serviceToken.trim(),
       endpoint = endpoint ?? Uri.parse('https://vkpns.rustore.ru'),
       _http = DwPushHttp(timeout: requestTimeout),
       _clock = clock ?? DateTime.now {
    if (projectId.trim().isEmpty) {
      throw ArgumentError.value(projectId, 'projectId', 'must not be empty');
    }
    if (_serviceToken.isEmpty) {
      throw ArgumentError('the RuStore service token must not be empty');
    }
  }

  final String projectId;
  final String _serviceToken;
  final String? androidChannelId;
  final String? androidIcon;

  /// `#rrggbb`.
  final String? androidColor;

  /// RuStore's base URL; a test points it at a local fake.
  final Uri endpoint;

  final DwPushHttp _http;
  final DateTime Function() _clock;

  @override
  DwPushTransport get transport => DwPushTransport.rustore;

  /// The `message` for [request].
  ///
  /// RuStore does not show an image given in its notification block, so a
  /// message with a picture is sent as data only, with its text and image
  /// under `DwPushData.titleKey`, `bodyKey` and `imageKey` — and
  /// `dartway_push_rustore` draws it on the device, text first and the
  /// picture once fetched.
  Map<String, Object?> messageOf(DwPushRequest request) {
    final image = request.imageUrl;
    return {
      'message': {
        'token': request.token,
        if (image == null && request.data.isNotEmpty) 'data': request.data,
        if (image != null)
          'data': {
            ...request.data,
            DwPushData.titleKey: request.title,
            DwPushData.bodyKey: ?request.body,
            DwPushData.imageKey: image,
          },
        if (image == null)
          'notification': {'title': request.title, 'body': ?request.body},
        'android': {
          if (request.ttl case final ttl?) 'ttl': '${ttl.inSeconds}s',
          if (image == null &&
              (androidChannelId != null ||
                  androidIcon != null ||
                  androidColor != null))
            'notification': {
              'channel_id': ?androidChannelId,
              'icon': ?androidIcon,
              'color': ?androidColor,
            },
        },
      },
    };
  }

  @override
  Future<DwPushOutcome> send(DwPushRequest request) async {
    final answer = await _http.post(
      endpoint.replace(path: '/v1/projects/$projectId/messages:send'),
      headers: {
        'authorization': 'Bearer $_serviceToken',
        'content-type': 'application/json; charset=utf-8',
      },
      body: jsonEncode(messageOf(request)),
    );
    if (answer.status == 200) return const DwPushAccepted();
    final reason = answer.describe('rustore');
    final message = switch (answer.json?['error']) {
      {'message': final String message} => message.toLowerCase(),
      _ => '',
    };
    if (answer.status == 404 ||
        (answer.status == 400 && message.contains('token'))) {
      return DwPushTokenInvalid(reason);
    }
    if (answer.status == 408 ||
        answer.status == 429 ||
        answer.status == 401 ||
        answer.status == 403 ||
        answer.status >= 500) {
      return DwPushRetryLater(reason, retryAfter: answer.retryAfter(_clock()));
    }
    return DwPushRejected(reason);
  }

  @override
  Future<void> close() async => _http.close();
}
