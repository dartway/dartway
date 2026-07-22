import 'dart:async';
import 'dart:convert';

import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

void main() {
  group('DwFcmPushProvider', () {
    test(
      'builds the FCM HTTP v1 payload without hardcoded presentation overrides',
      () async {
        final http = _FakePushHttpClient((request) async {
          expect(request.method, 'POST');
          expect(
            request.uri,
            Uri.parse(
              'https://fcm.googleapis.com/v1/projects/demo-project/messages:send',
            ),
          );
          expect(
            request.headers['authorization'],
            'Bearer ya29.test-access-token',
          );

          final body = jsonDecode(request.body) as Map<String, Object?>;
          expect(body, {
            'message': {
              'token': 'device-token',
              'notification': {
                'title': 'Course unlocked',
                'body': 'Open the app to continue',
                'image': 'https://cdn.example.com/banner.png',
              },
              'data': {
                'course_id': '42',
                'image_url': 'https://cdn.example.com/banner.png',
              },
              'android': {
                'notification': {'image': 'https://cdn.example.com/banner.png'},
              },
              'apns': {
                'payload': {
                  'aps': {'sound': 'default', 'mutable-content': 1},
                },
                'fcm_options': {'image': 'https://cdn.example.com/banner.png'},
              },
              'webpush': {
                'notification': {'image': 'https://cdn.example.com/banner.png'},
              },
            },
          });

          return const _FakePushHttpResponse(statusCode: 200, body: '{}');
        });

        final provider = DwFcmPushProvider(
          config: DwFcmPushProviderConfig(
            projectId: 'demo-project',
            serviceAccountJson: jsonEncode({
              'type': 'service_account',
              'project_id': 'demo-project',
              'client_email': 'push@example.iam.gserviceaccount.com',
              'private_key':
                  '-----BEGIN PRIVATE KEY-----\\nabc\\n-----END PRIVATE KEY-----\\n',
            }),
          ),
          httpClient: http,
          accessTokenProvider: () async => 'ya29.test-access-token',
        );

        final outcome = await provider.send(
          _FakeSession(),
          _request(target: 'device-token'),
        );

        expect(outcome.status, DwPushProviderStatus.accepted);
      },
    );

    test('adds explicit presentation overrides to the payload', () async {
      final http = _FakePushHttpClient((request) async {
        final body = jsonDecode(request.body) as Map<String, Object?>;
        expect(body, {
          'message': {
            'token': 'device-token',
            'notification': {
              'title': 'Course unlocked',
              'body': 'Open the app to continue',
              'image': 'https://cdn.example.com/banner.png',
            },
            'data': {
              'course_id': '42',
              'image_url': 'https://cdn.example.com/banner.png',
            },
            'android': {
              'notification': {
                'image': 'https://cdn.example.com/banner.png',
                'icon': 'ic_notification',
                'color': '#102030',
              },
            },
            'apns': {
              'payload': {
                'aps': {'sound': 'default', 'mutable-content': 1},
              },
              'fcm_options': {'image': 'https://cdn.example.com/banner.png'},
            },
            'webpush': {
              'notification': {
                'image': 'https://cdn.example.com/banner.png',
                'icon': '/icons/push.png',
              },
            },
          },
        });

        return const _FakePushHttpResponse(statusCode: 200, body: '{}');
      });

      final provider = DwFcmPushProvider(
        config: DwFcmPushProviderConfig(
          projectId: 'demo-project',
          serviceAccountJson: jsonEncode({
            'type': 'service_account',
            'project_id': 'demo-project',
          }),
          webpushIcon: '/icons/push.png',
          androidIcon: 'ic_notification',
          androidColor: '#102030',
        ),
        httpClient: http,
        accessTokenProvider: () async => 'ya29.test-access-token',
      );

      final outcome = await provider.send(
        _FakeSession(),
        _request(target: 'device-token'),
      );

      expect(outcome.status, DwPushProviderStatus.accepted);
    });

    test(
      'maps explicit registration-token mismatch to target not supported',
      () async {
        final provider = _providerResponding(
          statusCode: 400,
          body: jsonEncode({
            'error': {
              'status': 'INVALID_ARGUMENT',
              'message':
                  'The registration token is not a valid FCM registration token',
              'details': [
                {
                  '@type':
                      'type.googleapis.com/google.firebase.fcm.v1.FcmError',
                  'errorCode': 'INVALID_ARGUMENT',
                },
              ],
            },
          }),
        );

        final outcome = await provider.send(
          _FakeSession(),
          _request(target: 'ru-token'),
        );

        expect(outcome.status, DwPushProviderStatus.targetNotSupported);
      },
    );

    test(
      'does not fall back for a payload INVALID_ARGUMENT without FCM token details',
      () async {
        final provider = _providerResponding(
          statusCode: 400,
          body: jsonEncode({
            'error': {
              'status': 'INVALID_ARGUMENT',
              'message': "Invalid value at 'message.data[0].value'",
              'details': [
                {
                  '@type': 'type.googleapis.com/google.rpc.BadRequest',
                  'fieldViolations': [
                    {'field': 'message.data[0].value'},
                  ],
                },
              ],
            },
          }),
        );

        final outcome = await provider.send(
          _FakeSession(),
          _request(target: 'device-token'),
        );

        expect(outcome.status, DwPushProviderStatus.permanentFailure);
      },
    );

    test(
      'requires FCM token details before using registration text for fallback',
      () async {
        final provider = _providerResponding(
          statusCode: 400,
          body: jsonEncode({
            'error': {
              'status': 'INVALID_ARGUMENT',
              'message': 'Invalid registration token value in message data',
              'details': [
                {
                  '@type': 'type.googleapis.com/google.rpc.BadRequest',
                  'fieldViolations': [
                    {'field': 'message.data.registration_token'},
                  ],
                },
              ],
            },
          }),
        );

        final outcome = await provider.send(
          _FakeSession(),
          _request(target: 'device-token'),
        );

        expect(outcome.status, DwPushProviderStatus.permanentFailure);
      },
    );

    test('maps UNREGISTERED to invalid target', () async {
      final provider = _providerResponding(
        statusCode: 404,
        body: jsonEncode({
          'error': {
            'status': 'NOT_FOUND',
            'details': [
              {
                '@type': 'type.googleapis.com/google.firebase.fcm.v1.FcmError',
                'errorCode': 'UNREGISTERED',
              },
            ],
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
      'does not invalidate the target for unrelated not found errors',
      () async {
        final provider = _providerResponding(
          statusCode: 404,
          body: jsonEncode({
            'error': {
              'status': 'NOT_FOUND',
              'message': 'Requested entity was not found.',
            },
          }),
        );

        final outcome = await provider.send(
          _FakeSession(),
          _request(target: 'device-token'),
        );

        expect(outcome.status, DwPushProviderStatus.permanentFailure);
      },
    );

    test(
      'treats rate limits as retryable and honors retry-after with a one minute floor',
      () async {
        final provider = _providerResponding(
          statusCode: 429,
          body: jsonEncode({
            'error': {'status': 'RESOURCE_EXHAUSTED'},
          }),
          headers: {'retry-after': '7'},
        );

        final outcome = await provider.send(
          _FakeSession(),
          _request(target: 'device-token'),
        );

        expect(outcome.status, DwPushProviderStatus.retryableFailure);
        expect(outcome.retryAfter, const Duration(minutes: 1));
      },
    );

    test('treats server failures as retryable', () async {
      final provider = _providerResponding(statusCode: 503, body: '{}');

      final outcome = await provider.send(
        _FakeSession(),
        _request(target: 'device-token'),
      );

      expect(outcome.status, DwPushProviderStatus.retryableFailure);
    });

    test('rejects an oversized payload before OAuth or HTTP', () async {
      var accessTokenCalls = 0;
      var httpCalls = 0;
      final provider = DwFcmPushProvider(
        config: DwFcmPushProviderConfig(
          projectId: 'demo-project',
          serviceAccountJson: '{}',
        ),
        httpClient: _FakePushHttpClient((_) async {
          httpCalls++;
          return const _FakePushHttpResponse(statusCode: 200, body: '{}');
        }),
        accessTokenProvider: () async {
          accessTokenCalls++;
          return 'unused-token';
        },
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
      expect(outcome.errorCode, 'fcm_payload_too_large');
      expect(accessTokenCalls, 0);
      expect(httpCalls, 0);
    });

    test('shares one OAuth refresh across concurrent target sends', () async {
      var accessTokenCalls = 0;
      final provider = DwFcmPushProvider(
        config: DwFcmPushProviderConfig(
          projectId: 'demo-project',
          serviceAccountJson: '{}',
        ),
        httpClient: _FakePushHttpClient(
          (_) async => const _FakePushHttpResponse(statusCode: 200, body: '{}'),
        ),
        accessTokenProvider: () async {
          accessTokenCalls++;
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return 'ya29.shared-token';
        },
      );

      await Future.wait([
        provider.send(_FakeSession(), _request(target: 'token-a')),
        provider.send(_FakeSession(), _request(target: 'token-b')),
      ]);

      expect(accessTokenCalls, 1);
    });

    test('times out while acquiring an OAuth access token', () async {
      final neverCompletes = Completer<String?>();
      var httpCalls = 0;
      final provider = DwFcmPushProvider(
        config: DwFcmPushProviderConfig(
          projectId: 'demo-project',
          serviceAccountJson: '{}',
          requestTimeout: const Duration(milliseconds: 20),
        ),
        httpClient: _FakePushHttpClient((_) async {
          httpCalls++;
          return const _FakePushHttpResponse(statusCode: 200, body: '{}');
        }),
        accessTokenProvider: () => neverCompletes.future,
      );

      final outcome = await provider
          .send(_FakeSession(), _request(target: 'device-token'))
          .timeout(const Duration(seconds: 1));

      expect(outcome.status, DwPushProviderStatus.retryableFailure);
      expect(outcome.errorCode, 'fcm_timeout');
      expect(httpCalls, 0);
    });

    test('shares one timeout budget between OAuth and FCM HTTP', () async {
      var httpCalls = 0;
      final provider = DwFcmPushProvider(
        config: DwFcmPushProviderConfig(
          projectId: 'demo-project',
          serviceAccountJson: '{}',
          requestTimeout: const Duration(milliseconds: 200),
        ),
        httpClient: _FakePushHttpClient((_) async {
          httpCalls++;
          await Future<void>.delayed(const Duration(milliseconds: 130));
          return const _FakePushHttpResponse(statusCode: 200, body: '{}');
        }),
        accessTokenProvider: () async {
          await Future<void>.delayed(const Duration(milliseconds: 130));
          return 'ya29.slow-access-token';
        },
      );

      final outcome = await provider
          .send(_FakeSession(), _request(target: 'device-token'))
          .timeout(const Duration(seconds: 1));

      expect(outcome.status, DwPushProviderStatus.retryableFailure);
      expect(outcome.errorCode, 'fcm_timeout');
      expect(httpCalls, 1);
    });

    test('starts a fresh OAuth refresh after a timed out refresh', () async {
      var accessTokenCalls = 0;
      var httpCalls = 0;
      final provider = DwFcmPushProvider(
        config: DwFcmPushProviderConfig(
          projectId: 'demo-project',
          serviceAccountJson: '{}',
          requestTimeout: const Duration(milliseconds: 20),
        ),
        httpClient: _FakePushHttpClient((_) async {
          httpCalls++;
          return const _FakePushHttpResponse(statusCode: 200, body: '{}');
        }),
        accessTokenProvider: () {
          accessTokenCalls++;
          if (accessTokenCalls == 1) return Completer<String?>().future;
          return Future.value('ya29.recovered-access-token');
        },
      );

      final first = await provider.send(
        _FakeSession(),
        _request(target: 'token-a'),
      );
      final second = await provider.send(
        _FakeSession(),
        _request(target: 'token-b'),
      );

      expect(first.errorCode, 'fcm_timeout');
      expect(second.status, DwPushProviderStatus.accepted);
      expect(accessTokenCalls, 2);
      expect(httpCalls, 1);
    });

    test('ignores a timed out refresh that completes after recovery', () async {
      final firstRefresh = Completer<String?>();
      var accessTokenCalls = 0;
      final authorizationHeaders = <String?>[];
      final provider = DwFcmPushProvider(
        config: DwFcmPushProviderConfig(
          projectId: 'demo-project',
          serviceAccountJson: '{}',
          requestTimeout: const Duration(milliseconds: 20),
        ),
        httpClient: _FakePushHttpClient((request) async {
          authorizationHeaders.add(request.headers['authorization']);
          return const _FakePushHttpResponse(statusCode: 200, body: '{}');
        }),
        accessTokenProvider: () {
          accessTokenCalls++;
          return accessTokenCalls == 1
              ? firstRefresh.future
              : Future.value('ya29.current-access-token');
        },
      );

      await provider.send(_FakeSession(), _request(target: 'token-a'));
      final recovered = await provider.send(
        _FakeSession(),
        _request(target: 'token-b'),
      );
      firstRefresh.complete('ya29.stale-access-token');
      await Future<void>.delayed(Duration.zero);
      final cached = await provider.send(
        _FakeSession(),
        _request(target: 'token-c'),
      );

      expect(recovered.status, DwPushProviderStatus.accepted);
      expect(cached.status, DwPushProviderStatus.accepted);
      expect(accessTokenCalls, 2);
      expect(authorizationHeaders, [
        'Bearer ya29.current-access-token',
        'Bearer ya29.current-access-token',
      ]);
    });
  });
}

DwFcmPushProvider _providerResponding({
  required int statusCode,
  required String body,
  Map<String, String> headers = const {},
}) {
  return DwFcmPushProvider(
    config: DwFcmPushProviderConfig(
      projectId: 'demo-project',
      serviceAccountJson: jsonEncode({
        'type': 'service_account',
        'project_id': 'demo-project',
        'client_email': 'push@example.iam.gserviceaccount.com',
        'private_key':
            '-----BEGIN PRIVATE KEY-----\\nabc\\n-----END PRIVATE KEY-----\\n',
      }),
    ),
    httpClient: _FakePushHttpClient(
      (_) async => _FakePushHttpResponse(
        statusCode: statusCode,
        headers: headers,
        body: body,
      ),
    ),
    accessTokenProvider: () async => 'ya29.test-access-token',
  );
}

DwPushProviderRequest _request({required String target}) {
  return DwPushProviderRequest(
    target: target,
    payload: DwPushPayload(
      messageId: 99,
      category: 'news',
      title: 'Course unlocked',
      body: 'Open the app to continue',
      imageUrl: 'https://cdn.example.com/banner.png',
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
