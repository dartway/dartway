import 'dart:convert';
import 'dart:io';

import 'package:dartway_push_server/dartway_push_server.dart';
import 'package:dartway_push_server/src/providers/dw_rsa_signer.dart';
import 'package:test/test.dart';

import 'package:dartway_push_server/testing.dart';

import 'support/test_key.dart';

const request = DwPushRequest(
  token: 'device-token',
  title: 'Pool closed',
  body: 'Maintenance day.',
  data: {'dw_link': '/news/12'},
  link: '/news/12',
  ttl: Duration(hours: 2),
);

void main() {
  group('RS256', () {
    test('signs as OpenSSL does, from a PKCS #8 and a PKCS #1 key', () {
      for (final pem in [dwFakePushPrivateKey, testPrivateKeyPkcs1]) {
        final signature = DwRsaSigner.fromPem(
          pem,
        ).sign(utf8.encode(referenceMessage));
        expect(base64Encode(signature), referenceSignature);
      }
    });

    test('refuses what is not an RSA private key', () {
      expect(() => DwRsaSigner.fromPem('not a key'), throwsFormatException);
      expect(
        () => DwRsaSigner.fromPem(
          '-----BEGIN PRIVATE KEY-----\nAAAA\n-----END PRIVATE KEY-----',
        ),
        throwsFormatException,
      );
    });
  });

  group('DwFcmServiceAccount', () {
    Map<String, Object?> valid() => {
      'type': 'service_account',
      'project_id': 'p',
      'private_key_id': 'k',
      'private_key': dwFakePushPrivateKey,
      'client_email': 'push@p.iam.gserviceaccount.com',
    };

    test('reads the file Firebase issues', () {
      final account = DwFcmServiceAccount.fromJson(jsonEncode(valid()));
      expect(account.projectId, 'p');
      expect(
        account.tokenUri,
        Uri.parse('https://oauth2.googleapis.com/token'),
      );
      expect(account.toString(), isNot(contains('PRIVATE')));
    });

    test('says what is wrong with a file that is not one', () {
      Matcher says(String text) => throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains(text),
        ),
      );
      expect(() => DwFcmServiceAccount.fromJson('{"type": '), says('not JSON'));
      expect(
        () => DwFcmServiceAccount.fromJson('[]'),
        says('not a JSON object'),
      );
      expect(
        () => DwFcmServiceAccount.fromJson(
          jsonEncode(valid()..remove('client_email')),
        ),
        says('no "client_email"'),
      );
      expect(
        () => DwFcmServiceAccount.fromJson(
          jsonEncode(valid()..['type'] = 'authorized_user'),
        ),
        says('not a service account'),
      );
    });
  });

  group('DwFcmProvider', () {
    late DwFakePushService fcm;
    late DwFcmProvider provider;
    var now = DateTime.utc(2026, 9, 15, 12);

    setUp(() async {
      fcm = await DwFakePushService.start();
      now = DateTime.utc(2026, 9, 15, 12);
      provider = DwFcmProvider(
        account: DwFcmServiceAccount.fromJson(fcm.serviceAccountJson()),
        endpoint: fcm.endpoint,
        webLinkBase: Uri.parse('https://app.example.com/'),
        androidChannelId: 'news',
        clock: () => now,
      );
    });

    tearDown(() async {
      await provider.close();
      await fcm.close();
    });

    test('asks for an access token once and shares it', () async {
      final outcomes = await Future.wait([
        for (var i = 0; i < 5; i++) provider.send(request),
      ]);
      expect(outcomes, everyElement(isA<DwPushAccepted>()));
      expect(fcm.tokenRequests, hasLength(1));
      expect(
        fcm.tokenRequests.single['grant_type'],
        'urn:ietf:params:oauth:grant-type:jwt-bearer',
      );
      final claims = fcm.assertions.single;
      expect(claims['iss'], 'push@test-project.iam.gserviceaccount.com');
      expect(
        claims['scope'],
        'https://www.googleapis.com/auth/firebase.messaging',
      );
      expect(claims['aud'], fcm.endpoint.replace(path: '/token').toString());
      expect((claims['exp']! as int) - (claims['iat']! as int), 3600);
      expect(claims['iat'], now.millisecondsSinceEpoch ~/ 1000);
      expect(fcm.sends.map((s) => s.authorization).toSet(), {
        'Bearer access-1',
      });

      // Still fresh 50 minutes later; refreshed within five minutes of expiry.
      now = now.add(const Duration(minutes: 50));
      await provider.send(request);
      expect(fcm.tokenRequests, hasLength(1));
      now = now.add(const Duration(minutes: 6));
      await provider.send(request);
      expect(fcm.tokenRequests, hasLength(2));
      expect(fcm.sends.last.authorization, 'Bearer access-2');
    });

    test(
      'a 401 drops the token and tries once more with a fresh one',
      () async {
        var first = true;
        fcm.answer = (send) {
          if (first) {
            first = false;
            return DwFakePushAnswer.fcmError(
              401,
              'UNAUTHENTICATED',
              'Request had invalid authentication credentials.',
            );
          }
          return const DwFakePushAnswer.ok();
        };
        expect(await provider.send(request), isA<DwPushAccepted>());
        expect(fcm.tokenRequests, hasLength(2));
        expect(fcm.sends.map((s) => s.authorization), [
          'Bearer access-1',
          'Bearer access-2',
        ]);
      },
    );

    test(
      'a refused service account is a retryable failure with Google\'s words',
      () async {
        fcm.refuseTokens = true;
        final outcome = await provider.send(request);
        expect(
          outcome,
          isA<DwPushRetryLater>().having(
            (o) => o.reason,
            'reason',
            'fcm oauth 400 invalid_grant: Invalid JWT Signature.',
          ),
        );
        expect(fcm.sends, isEmpty);
        fcm.refuseTokens = false;
        expect(await provider.send(request), isA<DwPushAccepted>());
      },
    );

    test('builds the v1 message', () async {
      await provider.send(
        const DwPushRequest(
          token: 't',
          title: 'Title',
          imageUrl: 'https://cdn.example.com/a.png',
          data: {'dw_link': '/x'},
          link: '/x',
          ttl: Duration(seconds: 90),
        ),
      );
      final message = fcm.sends.single.message;
      expect(message, {
        'token': 't',
        'notification': {
          'title': 'Title',
          'image': 'https://cdn.example.com/a.png',
        },
        'data': {'dw_link': '/x'},
        'android': {
          'ttl': '90s',
          'notification': {'channel_id': 'news'},
        },
        'apns': {
          'headers': {
            'apns-expiration':
                '${now.add(const Duration(seconds: 90)).millisecondsSinceEpoch ~/ 1000}',
          },
          'payload': {
            'aps': {'sound': 'default', 'mutable-content': 1},
          },
          'fcm_options': {'image': 'https://cdn.example.com/a.png'},
        },
        'webpush': {
          'headers': {'TTL': '90'},
          'fcm_options': {'link': 'https://app.example.com/x'},
        },
      });
    });

    test('an https web link base is required', () {
      expect(
        () => DwFcmProvider(
          account: DwFcmServiceAccount.fromJson(fcm.serviceAccountJson()),
          webLinkBase: Uri.parse('http://app.example.com'),
        ),
        throwsArgumentError,
      );
    });

    test('classifies FCM\'s documented errors', () async {
      final cases = <DwFakePushAnswer, Matcher>{
        DwFakePushAnswer.fcmError(
          404,
          'NOT_FOUND',
          'Requested entity was not found.',
          fcmCode: 'UNREGISTERED',
        ): isA<DwPushTokenInvalid>().having(
          (o) => o.reason,
          'reason',
          'fcm 404 NOT_FOUND: Requested entity was not found. (UNREGISTERED)',
        ),
        DwFakePushAnswer.fcmError(
          403,
          'PERMISSION_DENIED',
          'SenderId mismatch',
          fcmCode: 'SENDER_ID_MISMATCH',
        ): isA<DwPushTokenInvalid>(),
        DwFakePushAnswer.fcmError(
          400,
          'INVALID_ARGUMENT',
          'The registration token is not a valid FCM registration token',
          fcmCode: 'INVALID_ARGUMENT',
        ): isA<DwPushTokenInvalid>(),
        DwFakePushAnswer.fcmError(
          400,
          'INVALID_ARGUMENT',
          'Invalid JSON payload received. Unknown name "from" at data',
          fcmCode: 'INVALID_ARGUMENT',
        ): isA<DwPushRejected>().having(
          (o) => o.reason,
          'reason',
          contains('Unknown name "from"'),
        ),
        DwFakePushAnswer.fcmError(
          429,
          'RESOURCE_EXHAUSTED',
          'Quota exceeded.',
          fcmCode: 'QUOTA_EXCEEDED',
          headers: {'retry-after': '30'},
        ): isA<DwPushRetryLater>().having(
          (o) => o.retryAfter,
          'retryAfter',
          const Duration(seconds: 30),
        ),
        DwFakePushAnswer.fcmError(
          503,
          'UNAVAILABLE',
          'The service is unavailable.',
          fcmCode: 'UNAVAILABLE',
        ): isA<DwPushRetryLater>(),
        DwFakePushAnswer.fcmError(
          500,
          'INTERNAL',
          'Internal error.',
          fcmCode: 'INTERNAL',
        ): isA<DwPushRetryLater>(),
        DwFakePushAnswer.fcmError(
          401,
          'UNAUTHENTICATED',
          'APNs certificate invalid',
          fcmCode: 'THIRD_PARTY_AUTH_ERROR',
        ): isA<DwPushRejected>(),
        const DwFakePushAnswer(
          502,
          '<html>Bad gateway</html>',
        ): isA<DwPushRetryLater>().having(
          (o) => o.reason,
          'reason',
          'fcm 502 <html>Bad gateway</html>',
        ),
      };
      for (final MapEntry(key: answer, value: matcher) in cases.entries) {
        fcm.answer = (_) => answer;
        expect(await provider.send(request), matcher, reason: answer.body);
      }
    });

    test('reads Retry-After as an HTTP date too', () async {
      fcm.answer = (_) => DwFakePushAnswer.fcmError(
        503,
        'UNAVAILABLE',
        'Later.',
        headers: {
          'retry-after': HttpDate.format(now.add(const Duration(minutes: 2))),
        },
      );
      final outcome = await provider.send(request) as DwPushRetryLater;
      expect(outcome.retryAfter, const Duration(minutes: 2));
    });
  });

  group('DwRuStoreProvider', () {
    late DwFakePushService rustore;
    late DwRuStoreProvider provider;

    setUp(() async {
      rustore = await DwFakePushService.start();
      provider = DwRuStoreProvider(
        projectId: 'rs-project',
        serviceToken: ' service-token ',
        endpoint: rustore.endpoint,
        androidColor: '#112233',
      );
    });

    tearDown(() async {
      await provider.close();
      await rustore.close();
    });

    test('sends the documented request', () async {
      rustore.answer = (_) => const DwFakePushAnswer(200, '{}');
      expect(await provider.send(request), isA<DwPushAccepted>());
      final send = rustore.sends.single;
      expect(send.path, '/v1/projects/rs-project/messages:send');
      expect(send.authorization, 'Bearer service-token');
      expect(send.message, {
        'token': 'device-token',
        'data': {'dw_link': '/news/12'},
        'notification': {'title': 'Pool closed', 'body': 'Maintenance day.'},
        'android': {
          'ttl': '7200s',
          'notification': {'color': '#112233'},
        },
      });
    });

    test('sends a picture as data only, for the device to draw', () async {
      await provider.send(
        const DwPushRequest(
          token: 't',
          title: 'Title',
          body: 'Body',
          imageUrl: 'https://cdn.example.com/a.png',
          data: {'dw_link': '/x'},
        ),
      );
      expect(rustore.sends.single.message, {
        'token': 't',
        'data': {
          'dw_link': '/x',
          'dw_title': 'Title',
          'dw_body': 'Body',
          'dw_image': 'https://cdn.example.com/a.png',
        },
        'android': <String, Object?>{},
      });
    });

    test('classifies RuStore\'s documented errors', () async {
      final cases = <DwFakePushAnswer, Matcher>{
        DwFakePushAnswer.ruStoreError(
          404,
          'NOT_FOUND',
          'push token not found',
        ): isA<DwPushTokenInvalid>().having(
          (o) => o.reason,
          'reason',
          'rustore 404 NOT_FOUND: push token not found',
        ),
        DwFakePushAnswer.ruStoreError(
          400,
          'INVALID_ARGUMENT',
          'invalid push token',
        ): isA<DwPushTokenInvalid>(),
        DwFakePushAnswer.ruStoreError(
          400,
          'INVALID_ARGUMENT',
          'ttl is malformed',
        ): isA<DwPushRejected>(),
        DwFakePushAnswer.ruStoreError(
          401,
          'PERMISSION_DENIED',
          'invalid service key',
        ): isA<DwPushRetryLater>(),
        DwFakePushAnswer.ruStoreError(429, 'TOO_MANY_REQUESTS', 'slow down'):
            isA<DwPushRetryLater>(),
        DwFakePushAnswer.ruStoreError(500, 'INTERNAL', 'oops'):
            isA<DwPushRetryLater>(),
      };
      for (final MapEntry(key: answer, value: matcher) in cases.entries) {
        rustore.answer = (_) => answer;
        expect(await provider.send(request), matcher, reason: answer.body);
      }
    });
  });
}
