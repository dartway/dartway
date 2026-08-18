import 'dart:async';

import 'package:dartway_push_flutter/dartway_push_flutter.dart';
import 'package:dartway_push_flutter/src/logic/dw_push_token_sync.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DwPushTokenSync', () {
    test(
      'waits until there is both a token and somebody to attach it to',
      () async {
        final registrar = _RecordingRegistrar();
        final sync = DwPushTokenSync(register: registrar.call);

        await sync.sync(recipientId: 7);
        expect(registrar.calls, isEmpty, reason: 'no token yet');

        sync.onToken(token: 'token-a', provider: DwPushProviderIds.fcm);
        await sync.sync(recipientId: null);
        expect(registrar.calls, isEmpty, reason: 'nobody signed in');

        await sync.sync(recipientId: 7);
        expect(registrar.calls, [('token-a', DwPushProviderIds.fcm)]);
      },
    );

    test('sends the same token to the same user only once', () async {
      final registrar = _RecordingRegistrar();
      final sync = DwPushTokenSync(register: registrar.call);

      sync.onToken(token: 'token-a', provider: DwPushProviderIds.fcm);
      await sync.sync(recipientId: 7);
      await sync.sync(recipientId: 7);
      await sync.sync(recipientId: 7);

      expect(registrar.calls, hasLength(1));
    });

    test('sends again after the platform refreshes the token', () async {
      final registrar = _RecordingRegistrar();
      final sync = DwPushTokenSync(register: registrar.call);

      sync.onToken(token: 'token-a', provider: DwPushProviderIds.fcm);
      await sync.sync(recipientId: 7);
      sync.onToken(token: 'token-b', provider: DwPushProviderIds.fcm);
      await sync.sync(recipientId: 7);

      expect(registrar.calls, [
        ('token-a', DwPushProviderIds.fcm),
        ('token-b', DwPushProviderIds.fcm),
      ]);
    });

    test('sends again when another user signs in on the same device', () async {
      final registrar = _RecordingRegistrar();
      final sync = DwPushTokenSync(register: registrar.call);

      sync.onToken(token: 'token-a', provider: DwPushProviderIds.fcm);
      await sync.sync(recipientId: 7);
      await sync.sync(recipientId: 8);

      expect(registrar.calls, hasLength(2));
    });

    test('sends again for the next user after a sign-out', () async {
      final registrar = _RecordingRegistrar();
      final sync = DwPushTokenSync(register: registrar.call);

      sync.onToken(token: 'token-a', provider: DwPushProviderIds.fcm);
      await sync.sync(recipientId: 7);
      sync.forgetRegistration();
      await sync.sync(recipientId: 7);

      expect(
        registrar.calls,
        hasLength(2),
        reason: 'the same user signing back in must be registered again',
      );
    });

    test('catches up with the user who arrived mid-flight', () async {
      var calls = 0;
      late DwPushTokenSync sync;
      sync = DwPushTokenSync(
        register: ({required token, required provider}) async {
          calls++;
          // User 8 signs in while the call for user 7 is still in flight. That
          // second attempt is suppressed by the in-flight guard, and if it were
          // simply dropped the new user would stay unreachable until the app
          // restarted.
          if (calls == 1) unawaited(sync.sync(recipientId: 8));
          return true;
        },
      );

      sync.onToken(token: 'token-a', provider: DwPushProviderIds.fcm);
      await sync.sync(recipientId: 7);
      await Future<void>.delayed(Duration.zero);

      expect(calls, 2);
    });

    test('retries after the server declined the token', () async {
      final registrar = _RecordingRegistrar(accept: false);
      final sync = DwPushTokenSync(register: registrar.call);

      sync.onToken(token: 'token-a', provider: DwPushProviderIds.fcm);
      await sync.sync(recipientId: 7);
      await sync.sync(recipientId: 7);

      expect(registrar.calls, hasLength(2));
    });

    test('survives a failing call and retries next time', () async {
      var attempts = 0;
      final sync = DwPushTokenSync(
        register: ({required token, required provider}) async {
          attempts++;
          if (attempts == 1) throw StateError('offline');
          return true;
        },
      );

      sync.onToken(token: 'token-a', provider: DwPushProviderIds.fcm);
      await sync.sync(recipientId: 7);
      await sync.sync(recipientId: 7);

      expect(attempts, 2);
    });
  });
}

class _RecordingRegistrar {
  _RecordingRegistrar({this.accept = true});

  final bool accept;
  final List<(String, String)> calls = [];

  Future<bool> call({required String token, required String provider}) async {
    calls.add((token, provider));
    return accept;
  }
}
