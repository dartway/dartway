import 'dart:convert';
import 'dart:typed_data';

import 'package:dartway_auth_providers_server/src/dw_jwt_keys.dart';
import 'package:test/test.dart';

import 'fixtures/provider_tokens.dart';

/// The signature check, against tokens `openssl` signed: the half where a
/// mistake is silent — a forged token accepted, and nothing said about it.
void main() {
  DwJwtKey keyOf(Map<String, Object?> jwks) =>
      DwJwtKey.parseSet(jwks).single;

  ({Uint8List signed, Uint8List signature}) partsOf(String token) {
    final parts = token.split('.');
    return (
      signed: Uint8List.fromList(ascii.encode('${parts[0]}.${parts[1]}')),
      signature: DwJwtKey.decodeBase64Url(parts[2]),
    );
  }

  bool accepts(DwJwtKey key, String token) {
    final parts = partsOf(token);
    return key.verifies(parts.signed, parts.signature);
  }

  group('a key set', () {
    test('reads the keys it can check and skips the rest', () {
      expect(keyOf(appleJwks), isA<DwEcJwtKey>().having((k) => k.kid, 'kid', 'ec-1'));
      expect(
        keyOf(googleJwks),
        isA<DwRsaJwtKey>().having((k) => k.kid, 'kid', 'rsa-1'),
      );
      expect(
        DwJwtKey.parseSet({
          'keys': [
            {'kty': 'oct', 'k': 'AAAA'},
            {'kty': 'EC', 'crv': 'P-384', 'x': 'AA', 'y': 'AA'},
            {'kty': 'RSA', 'use': 'enc', 'n': 'AA', 'e': 'AQAB'},
            {'kty': 'RSA', 'n': 'not base64url!!', 'e': 'AQAB'},
            ...(googleJwks['keys']! as List),
          ],
        }).map((k) => k.kid),
        ['rsa-1'],
        reason: 'one unreadable key must not take the readable one with it',
      );
      expect(DwJwtKey.parseSet('not a document'), isEmpty);
      expect(DwJwtKey.parseSet(const {'keys': 'not a list'}), isEmpty);
    });
  });

  group('ES256, as Apple signs', () {
    test('accepts the provider\'s own signature', () {
      expect(accepts(keyOf(appleJwks), appleToken), isTrue);
      expect(accepts(keyOf(appleJwks), appleTokenOtherSubject), isTrue);
    });

    test('refuses a signature of other claims — the one place a forgery '
        'would get in', () {
      final key = keyOf(appleJwks);
      final signed = partsOf(appleToken).signed;
      final other = partsOf(appleTokenOtherSubject).signature;
      expect(
        key.verifies(signed, other),
        isFalse,
        reason: 'a signature of one token must not pass for another',
      );
    });

    test('refuses a signature with a byte changed, in r and in s', () {
      final key = keyOf(appleJwks);
      final parts = partsOf(appleToken);
      for (final index in [0, 31, 32, 63]) {
        final broken = Uint8List.fromList(parts.signature);
        broken[index] ^= 1;
        expect(
          key.verifies(parts.signed, broken),
          isFalse,
          reason: 'byte $index of the signature changed',
        );
      }
    });

    test('refuses a signature of the wrong length, and r or s out of range', () {
      final key = keyOf(appleJwks);
      final parts = partsOf(appleToken);
      expect(key.verifies(parts.signed, Uint8List(64)), isFalse);
      expect(
        key.verifies(parts.signed, Uint8List.sublistView(parts.signature, 1)),
        isFalse,
      );
      expect(
        key.verifies(parts.signed, Uint8List(65)..setAll(0, parts.signature)),
        isFalse,
      );
    });

    test('refuses a key that is not a point of the curve', () {
      final real = keyOf(appleJwks) as DwEcJwtKey;
      final parts = partsOf(appleToken);
      final moved = DwEcJwtKey('ec-1', x: real.x, y: real.y + BigInt.one);
      expect(moved.verifies(parts.signed, parts.signature), isFalse);
    });

    test('refuses another key of the same curve', () {
      final parts = partsOf(appleToken);
      // The curve's base point as a public key: a real point, another key.
      final other = DwJwtKey.parse({
        'kty': 'EC',
        'crv': 'P-256',
        'kid': 'ec-2',
        'x': 'axfR8uEsQkf4vOblY6RA8ncDfYEt6zOg9KE5RdiYwpY',
        'y': 'T-NC4v4af5uO5-tKfA-eFivOM1drMV7Oy7ZAaDe_UfU',
      })!;
      expect(other.verifies(parts.signed, parts.signature), isFalse);
    });
  });

  group('RS256, as Google signs', () {
    test('accepts the provider\'s own signature', () {
      expect(accepts(keyOf(googleJwks), googleToken), isTrue);
    });

    test('refuses a signature with a byte changed', () {
      final key = keyOf(googleJwks);
      final parts = partsOf(googleToken);
      for (final index in [0, 128, 255]) {
        final broken = Uint8List.fromList(parts.signature);
        broken[index] ^= 1;
        expect(key.verifies(parts.signed, broken), isFalse);
      }
    });

    test('refuses a signature of other bytes', () {
      final key = keyOf(googleJwks);
      final parts = partsOf(googleToken);
      final otherPayload = Uint8List.fromList([...parts.signed]..[10] ^= 1);
      expect(key.verifies(otherPayload, parts.signature), isFalse);
    });

    test('refuses a modulus too short to be a signing key', () {
      final parts = partsOf(googleToken);
      final small = DwRsaJwtKey(
        'rsa-2',
        modulus: BigInt.two.pow(1024) - BigInt.one,
        exponent: BigInt.from(65537),
      );
      expect(small.verifies(parts.signed, parts.signature), isFalse);
    });

    test('refuses a signature that is not a number below the modulus', () {
      final key = keyOf(googleJwks) as DwRsaJwtKey;
      final parts = partsOf(googleToken);
      final tooLarge = Uint8List(parts.signature.length)
        ..fillRange(0, parts.signature.length, 0xff);
      expect(key.verifies(parts.signed, tooLarge), isFalse);
    });
  });
}
