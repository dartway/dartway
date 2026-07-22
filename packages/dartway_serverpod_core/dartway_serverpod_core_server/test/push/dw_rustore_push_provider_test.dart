import 'dart:convert';

import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

void main() {
  group('DwRuStorePushProvider', () {
    test(
      'builds the RuStore payload without hardcoded Android presentation overrides',
      () async {
        final http = _FakePushHttpClient((request) async {
          expect(request.method, 'POST');
          expect(
            request.uri,
            Uri.parse(
              'https://vkpns.rustore.ru/v1/projects/demo/messages:send',
            ),
          );
          expect(
            request.headers['authorization'],
            'Bearer rustore-service-token',
          );

          final body = jsonDecode(request.body) as Map<String, Object?>;
          expect(body, {
            'message': {
              'token': 'device-token',
              'data': {
                'course_id': '42',
                'push_title': 'Course unlocked',
                'push_body': 'Open the app to continue',
                'image_url': 'https://cdn.example.com/banner.png',
              },
            },
          });

          return const _FakePushHttpResponse(statusCode: 200, body: '{}');
        });

        final provider = DwRuStorePushProvider(
          config: DwRuStorePushProviderConfig(
            projectId: 'demo',
            serviceToken: 'rustore-service-token',
          ),
          httpClient: http,
        );

        final outcome = await provider.send(
          _FakeSession(),
          _request(target: 'device-token'),
        );

        expect(outcome.status, DwPushProviderStatus.accepted);
      },
    );

    test('maps structured NOT_FOUND to invalid target', () async {
      final provider = _providerResponding(
        statusCode: 404,
        body: jsonEncode({
          'error': {
            'code': 404,
            'status': 'NOT_FOUND',
            'message': 'Requested entity was not found.',
          },
        }),
      );

      final outcome = await provider.send(
        _FakeSession(),
        _request(target: 'stale-token'),
      );

      expect(outcome.status, DwPushProviderStatus.invalidTarget);
    });

    test(
      'maps an explicit invalid registration token to invalid target',
      () async {
        final provider = _providerResponding(
          statusCode: 400,
          body: jsonEncode({
            'error': {
              'code': 400,
              'status': 'INVALID_ARGUMENT',
              'message':
                  'The registration token is not a valid FCM registration token',
            },
          }),
        );

        final outcome = await provider.send(
          _FakeSession(),
          _request(target: 'invalid-token'),
        );

        expect(outcome.status, DwPushProviderStatus.invalidTarget);
      },
    );

    test('does not invalidate a target for an unrelated 404', () async {
      final provider = _providerResponding(
        statusCode: 404,
        body: jsonEncode({
          'error': {
            'code': 404,
            'status': 'PROJECT_NOT_FOUND',
            'message': 'Project was not found.',
          },
        }),
      );

      final outcome = await provider.send(
        _FakeSession(),
        _request(target: 'device-token'),
      );

      expect(outcome.status, DwPushProviderStatus.permanentFailure);
    });

    test(
      'builds the native notification payload when no image is present',
      () async {
        final http = _FakePushHttpClient((request) async {
          final body = jsonDecode(request.body) as Map<String, Object?>;
          expect(body, {
            'message': {
              'token': 'device-token',
              'data': {'course_id': '42'},
              'notification': {
                'title': 'Course unlocked',
                'body': 'Open the app to continue',
              },
              'android': {
                'notification': {
                  'title': 'Course unlocked',
                  'body': 'Open the app to continue',
                },
              },
            },
          });
          return const _FakePushHttpResponse(statusCode: 200, body: '{}');
        });
        final provider = DwRuStorePushProvider(
          config: DwRuStorePushProviderConfig(
            projectId: 'demo',
            serviceToken: 'rustore-service-token',
          ),
          httpClient: http,
        );

        await provider.send(
          _FakeSession(),
          _request(target: 'device-token', imageUrl: null),
        );
      },
    );

    test(
      'adds explicit Android presentation overrides to the native payload',
      () async {
        final http = _FakePushHttpClient((request) async {
          final body = jsonDecode(request.body) as Map<String, Object?>;
          expect(body, {
            'message': {
              'token': 'device-token',
              'data': {'course_id': '42'},
              'notification': {
                'title': 'Course unlocked',
                'body': 'Open the app to continue',
              },
              'android': {
                'notification': {
                  'title': 'Course unlocked',
                  'body': 'Open the app to continue',
                  'icon': 'ic_notification',
                  'color': '#102030',
                },
              },
            },
          });
          return const _FakePushHttpResponse(statusCode: 200, body: '{}');
        });
        final provider = DwRuStorePushProvider(
          config: DwRuStorePushProviderConfig(
            projectId: 'demo',
            serviceToken: 'rustore-service-token',
            androidIcon: 'ic_notification',
            androidColor: '#102030',
          ),
          httpClient: http,
        );

        final outcome = await provider.send(
          _FakeSession(),
          _request(target: 'device-token', imageUrl: null),
        );

        expect(outcome.status, DwPushProviderStatus.accepted);
      },
    );

    test('maps 410 to invalid target', () async {
      final provider = _providerResponding(statusCode: 410, body: '{}');

      final outcome = await provider.send(
        _FakeSession(),
        _request(target: 'stale-token'),
      );

      expect(outcome.status, DwPushProviderStatus.invalidTarget);
    });

    test('treats rate limits as retryable and parses retry-after', () async {
      final provider = _providerResponding(
        statusCode: 429,
        body: '{}',
        headers: {'retry-after': '120'},
      );

      final outcome = await provider.send(
        _FakeSession(),
        _request(target: 'device-token'),
      );

      expect(outcome.status, DwPushProviderStatus.retryableFailure);
      expect(outcome.retryAfter, const Duration(minutes: 2));
    });

    test('treats server failures as retryable', () async {
      final provider = _providerResponding(statusCode: 502, body: '{}');

      final outcome = await provider.send(
        _FakeSession(),
        _request(target: 'device-token'),
      );

      expect(outcome.status, DwPushProviderStatus.retryableFailure);
    });

    test('rejects an oversized payload before HTTP', () async {
      var httpCalls = 0;
      final provider = DwRuStorePushProvider(
        config: DwRuStorePushProviderConfig(
          projectId: 'demo-project',
          serviceToken: 'service-token',
        ),
        httpClient: _FakePushHttpClient((_) async {
          httpCalls++;
          return const _FakePushHttpResponse(statusCode: 200, body: '{}');
        }),
      );

      final outcome = await provider.send(
        _FakeSession(),
        DwPushProviderRequest(
          target: 'device-token',
          payload: DwPushPayload(
            messageId: 99,
            category: 'news',
            title: 'Title',
            body: 'Body',
            imageUrl: null,
            data: {'oversized': 'x' * 5000},
            expiresAt: DateTime.utc(2026, 7, 21, 12),
          ),
        ),
      );

      expect(outcome.status, DwPushProviderStatus.permanentFailure);
      expect(outcome.errorCode, 'rustore_payload_too_large');
      expect(httpCalls, 0);
    });

    test('treats other client failures as permanent', () async {
      final provider = _providerResponding(statusCode: 403, body: '{}');

      final outcome = await provider.send(
        _FakeSession(),
        _request(target: 'device-token'),
      );

      expect(outcome.status, DwPushProviderStatus.permanentFailure);
    });
  });
}

DwRuStorePushProvider _providerResponding({
  required int statusCode,
  required String body,
  Map<String, String> headers = const {},
}) {
  return DwRuStorePushProvider(
    config: DwRuStorePushProviderConfig(
      projectId: 'demo',
      serviceToken: 'rustore-service-token',
    ),
    httpClient: _FakePushHttpClient(
      (_) async => _FakePushHttpResponse(
        statusCode: statusCode,
        headers: headers,
        body: body,
      ),
    ),
  );
}

DwPushProviderRequest _request({
  required String target,
  String? imageUrl = 'https://cdn.example.com/banner.png',
}) {
  return DwPushProviderRequest(
    target: target,
    payload: DwPushPayload(
      messageId: 99,
      category: 'news',
      title: 'Course unlocked',
      body: 'Open the app to continue',
      imageUrl: imageUrl,
      data: {'course_id': '42'},
      expiresAt: DateTime.utc(2026, 7, 21, 12),
    ),
  );
}

typedef _PushHttpHandler =
    Future<_FakePushHttpResponse> Function(_FakePushHttpRequest request);

final class _FakePushHttpClient implements DwPushHttpClient {
  _FakePushHttpClient(this._handler);

  final _PushHttpHandler _handler;

  @override
  Future<DwPushHttpResponse> send(DwPushHttpRequest request) => _handler(
    _FakePushHttpRequest(
      method: request.method,
      uri: request.uri,
      headers: request.headers,
      body: request.body,
    ),
  );
}

final class _FakePushHttpRequest {
  const _FakePushHttpRequest({
    required this.method,
    required this.uri,
    required this.headers,
    required this.body,
  });

  final String method;
  final Uri uri;
  final Map<String, String> headers;
  final String body;
}

final class _FakePushHttpResponse implements DwPushHttpResponse {
  const _FakePushHttpResponse({
    required this.statusCode,
    this.headers = const {},
    required this.body,
  });

  @override
  final int statusCode;

  @override
  final Map<String, String> headers;

  @override
  final String body;
}

final class _FakeSession implements Session {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
