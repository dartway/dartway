import 'package:dartway_push_server/dartway_push_server.dart';
import 'package:test/test.dart';

void main() {
  group('DwPushTarget', () {
    test('trims the token and normalizes a blank provider to null', () {
      final target = DwPushTarget(token: '  token  ', provider: '   ');

      expect(target.token, 'token');
      expect(target.provider, isNull);
    });

    test('trims the provider identifier', () {
      expect(DwPushTarget(token: 't', provider: ' fcm ').provider, 'fcm');
    });
  });

  group('DwPushRecipient', () {
    test('keeps one target per token', () {
      // Two rows can disagree about a device's transport — a probe wrote one,
      // a re-registration the other. Sending twice would deliver twice.
      final recipient = DwPushRecipient([
        DwPushTarget(token: 'token', provider: DwPushProviders.fcm),
        DwPushTarget(token: 'token', provider: DwPushProviders.ruStore),
      ]);

      expect(recipient.targets, hasLength(1));
      expect(recipient.targets.single.provider, DwPushProviders.fcm);
    });

    test('drops empty tokens', () {
      final recipient = DwPushRecipient([
        DwPushTarget(token: '   '),
        DwPushTarget(token: 'real'),
      ]);

      expect(recipient.tokens, ['real']);
    });

    test('accepts bare tokens as targets of unknown provenance', () {
      final recipient = DwPushRecipient.tokens(['a', ' b ', '']);

      expect(recipient.tokens, ['a', 'b']);
      expect(
        recipient.targets.map((target) => target.provider),
        everyElement(isNull),
      );
    });
  });
}
