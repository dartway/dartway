import 'package:dartway_studio_bridge/dartway_studio_bridge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('studioAccessKeyHash', () {
    test('is stable, hex SHA-256, and secret-dependent', () {
      const secret = 'a-long-random-secret';
      final hash = studioAccessKeyHash(secret);
      expect(hash, studioAccessKeyHash(secret)); // deterministic
      expect(hash, hasLength(64)); // hex sha-256
      expect(hash, isNot(studioAccessKeyHash('different')));
    });
  });

  group('studioHashAccessValidator', () {
    test('accepts the key whose hash matches, rejects others', () async {
      const secret = 'the-project-secret';
      final validator = studioHashAccessValidator(studioAccessKeyHash(secret));
      expect(await validator(secret), isTrue);
      expect(await validator('wrong'), isFalse);
      expect(await validator(''), isFalse);
    });

    test('an empty expected hash accepts any key (local dev)', () async {
      final validator = studioHashAccessValidator('');
      expect(await validator('anything'), isTrue);
      expect(await validator(''), isTrue);
    });
  });
}
