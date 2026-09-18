import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:dartway_auth_providers_server/src/dw_apple_client_secret.dart';
import 'package:dartway_auth_providers_server/src/dw_jwt_keys.dart';
import 'package:test/test.dart';

import 'fixtures/provider_tokens.dart';

/// The client secret Apple's own doors ask for: a JWT the project signs with
/// the `.p8` key it downloaded. Signing is the half nobody else checks for
/// us — a wrong signature is simply a refusal from Apple — so it is checked
/// here against the verifier and against `openssl`.
void main() {
  DwAppleClientSecret secret({Duration? lifetime}) => DwAppleClientSecret(
    teamId: 'TEAM123456',
    keyId: 'secret-1',
    clientId: 'com.club.app',
    privateKeyPem: appleSecretKeyPem,
    lifetime: lifetime ?? const Duration(minutes: 30),
  );

  Map<String, Object?> partOf(String token, int index) =>
      jsonDecode(utf8.decode(DwJwtKey.decodeBase64Url(token.split('.')[index])))
          as Map<String, Object?>;

  test('says what Apple reads: its team, its key, the app, and half an hour',
      () {
    final at = DateTime.utc(2026, 9, 18, 10);
    final token = secret().mint(now: at);
    expect(partOf(token, 0), {
      'alg': 'ES256',
      'kid': 'secret-1',
      'typ': 'JWT',
    });
    expect(partOf(token, 1), {
      'iss': 'TEAM123456',
      'iat': at.millisecondsSinceEpoch ~/ 1000,
      'exp': at.add(const Duration(minutes: 30)).millisecondsSinceEpoch ~/ 1000,
      'aud': 'https://appleid.apple.com',
      'sub': 'com.club.app',
    });
  });

  test('is signed by the key it names — read back by the same verifier that '
      'reads Apple\'s own tokens', () {
    final token = secret().mint();
    final parts = token.split('.');
    final key = DwJwtKey.parseSet(appleSecretKeyJwks).single;
    expect(
      key.verifies(
        Uint8List.fromList(ascii.encode('${parts[0]}.${parts[1]}')),
        DwJwtKey.decodeBase64Url(parts[2]),
      ),
      isTrue,
    );
  });

  test('is signed by the key it names — read back by openssl, which shares no '
      'code with us', () {
    final openssl = Process.runSync('openssl', ['version']);
    if (openssl.exitCode != 0) {
      markTestSkipped('openssl is not on this machine');
      return;
    }
    final token = secret().mint();
    final parts = token.split('.');
    final directory = Directory.systemTemp.createTempSync('dw_apple_secret_');
    addTearDown(() => directory.deleteSync(recursive: true));

    final keyFile = File('${directory.path}/key.p8')
      ..writeAsStringSync(appleSecretKeyPem);
    final publicKey = File('${directory.path}/key.pub');
    final extracted = Process.runSync('openssl', [
      'ec',
      '-in',
      keyFile.path,
      '-pubout',
      '-out',
      publicKey.path,
    ]);
    expect(extracted.exitCode, 0, reason: extracted.stderr.toString());

    File('${directory.path}/signed')
        .writeAsBytesSync(ascii.encode('${parts[0]}.${parts[1]}'));
    File('${directory.path}/signature.der')
        .writeAsBytesSync(_derOf(DwJwtKey.decodeBase64Url(parts[2])));
    final verified = Process.runSync('openssl', [
      'dgst',
      '-sha256',
      '-verify',
      publicKey.path,
      '-signature',
      '${directory.path}/signature.der',
      '${directory.path}/signed',
    ]);
    expect(
      verified.stdout.toString().trim(),
      'Verified OK',
      reason: verified.stderr.toString(),
    );
  });

  test('never signs twice the same way: a repeated k would hand the private '
      'key to anyone holding both signatures', () {
    final at = DateTime.utc(2026, 9, 18, 10);
    final signatures = {
      for (var i = 0; i < 20; i++) secret().mint(now: at).split('.').last,
    };
    expect(signatures, hasLength(20));
  });

  test('a signature is 64 bytes, r and s, whatever the numbers turn out to be',
      () {
    for (var seed = 0; seed < 50; seed++) {
      final token = secret().mint(random: Random(seed));
      expect(DwJwtKey.decodeBase64Url(token.split('.').last), hasLength(64));
    }
  });

  test('refuses anything that is not a P-256 private key, by name', () {
    expect(
      () => DwAppleClientSecret(
        teamId: 'T',
        keyId: 'k',
        clientId: 'c',
        privateKeyPem: 'no key here',
      ),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('.p8 file as downloaded'),
        ),
      ),
    );
    expect(
      () => DwAppleClientSecret(
        teamId: 'T',
        keyId: 'k',
        clientId: 'c',
        privateKeyPem:
            '-----BEGIN PRIVATE KEY-----\nnot base64 ~~~\n-----END PRIVATE KEY-----',
      ),
      throwsA(isA<FormatException>()),
    );
  });
}

/// Raw `r || s` as the DER sequence `openssl dgst -verify` expects.
List<int> _derOf(Uint8List raw) {
  List<int> integer(Uint8List value) {
    var bytes = value.toList();
    while (bytes.length > 1 && bytes.first == 0) {
      bytes = bytes.sublist(1);
    }
    if (bytes.first & 0x80 != 0) bytes = [0, ...bytes];
    return [0x02, bytes.length, ...bytes];
  }

  final body = [
    ...integer(Uint8List.sublistView(raw, 0, 32)),
    ...integer(Uint8List.sublistView(raw, 32)),
  ];
  return [0x30, body.length, ...body];
}
