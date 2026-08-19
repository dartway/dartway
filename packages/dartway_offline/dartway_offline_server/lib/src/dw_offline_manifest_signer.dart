import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:dartway_offline_shared/dartway_offline_shared.dart';

import 'dw_offline_manifest_claims.dart';

final class DwOfflineManifestSigner {
  DwOfflineManifestSigner._({
    required this.keyId,
    required SimpleKeyPair keyPair,
    required this.publicKeyBytes,
  }) : _keyPair = keyPair;

  static const schemaVersion = DwOfflineManifestEnvelope.schemaVersion;
  static const algorithmName = DwOfflineManifestEnvelope.algorithmName;

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
      DwOfflineManifestEnvelope.signingBytes(
        schemaVersion: schemaVersion,
        algorithm: algorithmName,
        keyId: keyId,
        payloadBytes: payloadBytes,
      ),
      keyPair: _keyPair,
    );
    return jsonEncode(<String, Object?>{
      'schemaVersion': schemaVersion,
      'algorithm': algorithmName,
      'keyId': keyId,
      'payload': DwOfflineManifestEnvelope.encodeUnpadded(payloadBytes),
      'signature': DwOfflineManifestEnvelope.encodeUnpadded(signature.bytes),
    });
  }
}
