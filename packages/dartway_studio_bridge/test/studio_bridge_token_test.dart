import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:dartway_studio_bridge/dartway_studio_bridge.dart';
import 'package:flutter_test/flutter_test.dart';

/// Studio's half of the contract, written out here rather than imported: the
/// app never signs, so the package ships no signer, and the issuer lives in
/// another repository. Keeping an independent implementation of the format in
/// the test is what makes the test worth having — it fails when the verifier
/// drifts from the format the doc comment on [verifyStudioBridgeToken]
/// promises, instead of drifting along with it.
Future<String> _signToken({
  required SimpleKeyPair signingKeyPair,
  required String origin,
  required DateTime expiresAt,
}) async {
  final payload = _base64UrlSegment(
    utf8.encode(
      jsonEncode({
        'origin': origin,
        'exp': expiresAt.toUtc().millisecondsSinceEpoch ~/ 1000,
      }),
    ),
  );
  final signature = await Ed25519().sign(
    ascii.encode(payload),
    keyPair: signingKeyPair,
  );
  return '$payload.${_base64UrlSegment(signature.bytes)}';
}

String _base64UrlSegment(List<int> bytes) =>
    base64Url.encode(bytes).replaceAll('=', '');

Future<String> _publicKeyOf(SimpleKeyPair keyPair) async =>
    base64.encode((await keyPair.extractPublicKey()).bytes);

void main() {
  const appOrigin = 'https://app.example.com';

  late SimpleKeyPair studioKeyPair;
  late String studioPublicKey;
  late String validToken;

  setUpAll(() async {
    studioKeyPair = await Ed25519().newKeyPair();
    studioPublicKey = await _publicKeyOf(studioKeyPair);
    validToken = await _signToken(
      signingKeyPair: studioKeyPair,
      origin: appOrigin,
      expiresAt: DateTime.now().add(const Duration(minutes: 10)),
    );
  });

  group('studioSigningPublicKey', () {
    test('is a 32-byte Ed25519 public key', () {
      expect(base64.decode(studioSigningPublicKey), hasLength(32));
    });
  });

  group('verifyStudioBridgeToken', () {
    test('accepts a live token signed for this origin', () async {
      expect(
        await verifyStudioBridgeToken(
          validToken,
          appOrigin: appOrigin,
          publicKey: studioPublicKey,
        ),
        isTrue,
      );
    });

    test('accepts the same origin written differently', () async {
      expect(
        await verifyStudioBridgeToken(
          validToken,
          appOrigin: 'https://App.Example.com/',
          publicKey: studioPublicKey,
        ),
        isTrue,
      );
    });

    test('rejects a token issued for another origin', () async {
      final foreignToken = await _signToken(
        signingKeyPair: studioKeyPair,
        origin: 'https://someone-else.example.com',
        expiresAt: DateTime.now().add(const Duration(minutes: 10)),
      );
      expect(
        await verifyStudioBridgeToken(
          foreignToken,
          appOrigin: appOrigin,
          publicKey: studioPublicKey,
        ),
        isFalse,
      );
    });

    test('rejects an expired token', () async {
      final expiredToken = await _signToken(
        signingKeyPair: studioKeyPair,
        origin: appOrigin,
        expiresAt: DateTime.now().subtract(const Duration(seconds: 1)),
      );
      expect(
        await verifyStudioBridgeToken(
          expiredToken,
          appOrigin: appOrigin,
          publicKey: studioPublicKey,
        ),
        isFalse,
      );
    });

    test('rejects a token whose claims were edited after signing', () async {
      final forgedPayload = _base64UrlSegment(
        utf8.encode(
          jsonEncode({
            'origin': appOrigin,
            'exp':
                DateTime.now()
                    .add(const Duration(days: 365))
                    .millisecondsSinceEpoch ~/
                1000,
          }),
        ),
      );
      final forgedToken = '$forgedPayload.${validToken.split('.').last}';
      expect(
        await verifyStudioBridgeToken(
          forgedToken,
          appOrigin: appOrigin,
          publicKey: studioPublicKey,
        ),
        isFalse,
      );
    });

    test('rejects a token signed by another key', () async {
      final impostorToken = await _signToken(
        signingKeyPair: await Ed25519().newKeyPair(),
        origin: appOrigin,
        expiresAt: DateTime.now().add(const Duration(minutes: 10)),
      );
      expect(
        await verifyStudioBridgeToken(
          impostorToken,
          appOrigin: appOrigin,
          publicKey: studioPublicKey,
        ),
        isFalse,
      );
    });

    test('rejects garbage instead of throwing', () async {
      for (final malformed in ['', 'not-a-token', 'a.b.c', 'aGk=.###']) {
        expect(
          await verifyStudioBridgeToken(
            malformed,
            appOrigin: appOrigin,
            publicKey: studioPublicKey,
          ),
          isFalse,
          reason: 'accepted $malformed',
        );
      }
    });

    test('a build that names no origin verifies nothing', () async {
      expect(
        await verifyStudioBridgeToken(
          validToken,
          appOrigin: '',
          publicKey: studioPublicKey,
        ),
        isFalse,
      );
    });
  });

  group('studioSignedAccessValidator', () {
    test('lets a valid token in and keeps everything else out', () async {
      final validator = studioSignedAccessValidator(
        appOrigin,
        publicKey: studioPublicKey,
      );
      expect(await validator(validToken), isTrue);
      expect(await validator('forged'), isFalse);
      expect(await validator(''), isFalse);
    });

    test('rejects a token that would pass against Studio\'s real key '
        'but was not signed by the key this build trusts', () async {
      final validator = studioSignedAccessValidator(appOrigin);
      expect(await validator(validToken), isFalse);
    });

    test('a build with no origin named accepts any connection (local dev)',
        () async {
      final validator = studioSignedAccessValidator('');
      expect(await validator(''), isTrue);
      expect(await validator('anything at all'), isTrue);
    });
  });
}
