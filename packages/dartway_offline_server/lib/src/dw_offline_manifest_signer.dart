import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'dw_offline_manifest_claims.dart';

final class DwOfflineManifestSigner {
  DwOfflineManifestSigner._({
    required this.keyId,
    required SimpleKeyPair keyPair,
    required this.publicKeyBytes,
  }) : _keyPair = keyPair;

  static const schemaVersion = 2;
  static const algorithmName = 'Ed25519';

  final String keyId;
  final SimpleKeyPair _keyPair;
  final List<int> publicKeyBytes;

  static Future<DwOfflineManifestSigner> fromSeed({
    required String keyId,
    required List<int> privateKeySeed,
  }) async {
    if (keyId.isEmpty || keyId.trim() != keyId) {
      throw ArgumentError.value(keyId, 'keyId');
    }
    if (privateKeySeed.length != 32) {
      throw ArgumentError.value(privateKeySeed, 'privateKeySeed');
    }
    final keyPair = await Ed25519().newKeyPairFromSeed(privateKeySeed);
    final publicKey = await keyPair.extractPublicKey();
    return DwOfflineManifestSigner._(
      keyId: keyId,
      keyPair: keyPair,
      publicKeyBytes: List<int>.unmodifiable(publicKey.bytes),
    );
  }

  Future<String> sign(DwOfflineManifestClaims claims) async {
    final payloadBytes = utf8.encode(jsonEncode(claims.toCanonicalMap()));
    final signature = await Ed25519().sign(
      _signingBytes(payloadBytes),
      keyPair: _keyPair,
    );
    return jsonEncode(<String, Object?>{
      'schemaVersion': schemaVersion,
      'algorithm': algorithmName,
      'keyId': keyId,
      'payload': _encodeUnpadded(payloadBytes),
      'signature': _encodeUnpadded(signature.bytes),
    });
  }

  List<int> _signingBytes(List<int> payloadBytes) {
    final output = BytesBuilder(copy: false)
      ..add(ascii.encode('dartway.offline.manifest\u0000'))
      ..add(_unsigned32(schemaVersion))
      ..add(_lengthPrefixed(utf8.encode(algorithmName)))
      ..add(_lengthPrefixed(utf8.encode(keyId)))
      ..add(_lengthPrefixed(payloadBytes));
    return output.takeBytes();
  }

  static List<int> _lengthPrefixed(List<int> bytes) => [
    ..._unsigned32(bytes.length),
    ...bytes,
  ];

  static List<int> _unsigned32(int integer) => [
    (integer >> 24) & 0xff,
    (integer >> 16) & 0xff,
    (integer >> 8) & 0xff,
    integer & 0xff,
  ];

  static String _encodeUnpadded(List<int> bytes) =>
      base64Url.encode(bytes).replaceAll('=', '');
}
