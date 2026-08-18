import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:crypto/crypto.dart' as crypto;

import 'package:dartway_offline/src/access/dw_offline_lease_policy.dart';

final class TestSignedManifestFixture {
  TestSignedManifestFixture._(this._keyPair, this._publicKeyBytes);

  static const String keyId = 'manifest-key-v1';
  static const String algorithmName = 'Ed25519';
  static const int schemaVersion = 2;

  final SimpleKeyPair _keyPair;
  final List<int> _publicKeyBytes;

  Map<String, List<int>> get pinnedPublicKeys => {
    keyId: List<int>.unmodifiable(_publicKeyBytes),
  };

  DwOfflineManifestVerifier createVerifier() =>
      DwOfflineManifestVerifier(pinnedPublicKeys: {keyId: _publicKeyBytes});

  static Future<TestSignedManifestFixture> create() async {
    final keyPair = await Ed25519().newKeyPairFromSeed(
      List<int>.generate(32, (index) => index + 1),
    );
    return TestSignedManifestFixture._(
      keyPair,
      (await keyPair.extractPublicKey()).bytes,
    );
  }

  Future<DwVerifiedOfflineManifest> verify({
    String userScopeId = 'scope-a',
    String packageId = 'package-a',
    String manifestRevision = 'manifest-1',
    String? repositoryContentDigest,
    int leaseRecordVersion = 1,
    String? leaseId,
    DateTime? verifiedServerUtc,
    DateTime? leaseValidUntilUtc,
    bool unboundedLease = false,
    bool leaseIsRevoked = false,
    List<Map<String, Object?>>? assets,
    DwOfflineLeaseRecord previousLeaseRecord =
        const DwOfflineLeaseRecord.missing(),
  }) async {
    final payload = <String, Object?>{
      'assets': assets ?? [assetMap()],
      'audience': 'mobile',
      'contentIdentity': 'content-$packageId',
      'leaseId': leaseId ?? 'lease-$packageId',
      'leaseIsRevoked': leaseIsRevoked,
      'leaseRecordVersion': leaseRecordVersion,
      'leaseValidUntilUtcEpochUs': unboundedLease
          ? null
          : (leaseValidUntilUtc ?? DateTime.utc(2027)).microsecondsSinceEpoch,
      'manifestRevision': manifestRevision,
      'packageId': packageId,
      'repositoryContentDigest':
          repositoryContentDigest ??
          (RegExp(r'^[0-9a-f]{64}$').hasMatch(manifestRevision)
              ? manifestRevision
              : crypto.sha256.convert(utf8.encode('{"models":[]}')).toString()),
      'userScopeId': userScopeId,
      'verifiedServerUtcEpochUs':
          (verifiedServerUtc ?? DateTime.utc(2026)).microsecondsSinceEpoch,
    };
    final payloadBytes = utf8.encode(jsonEncode(payload));
    final signature = await Ed25519().sign(
      _signingBytes(payloadBytes),
      keyPair: _keyPair,
    );
    final envelopeJson = jsonEncode(<String, Object?>{
      'schemaVersion': schemaVersion,
      'algorithm': algorithmName,
      'keyId': keyId,
      'payload': _encodeUnpadded(payloadBytes),
      'signature': _encodeUnpadded(signature.bytes),
    });
    final result =
        await DwOfflineManifestVerifier(
          pinnedPublicKeys: {keyId: _publicKeyBytes},
        ).verify(
          envelopeJson: envelopeJson,
          expectedAudience: 'mobile',
          expectedUserScopeId: userScopeId,
          expectedPackageId: packageId,
          previousLeaseRecord: previousLeaseRecord,
        );
    if (result.verifiedManifest == null) {
      throw StateError('Fixture verification failed: ${result.status}.');
    }
    return result.verifiedManifest!;
  }

  Map<String, Object?> assetMap({
    String assetId = 'asset-a',
    String assetRevision = 'r1',
    List<int> bytes = const [1, 2, 3, 4, 5],
    bool isRequired = true,
  }) {
    const knownDigests = <String, String>{
      '1,2,3,4,5':
          '74f81fe167d99b4cb41d6d0ccda82278caee9f3e2f25d5e5a3936ff3dcec60d0',
      '6,7,8':
          '4387f68386622af940deb007ce713c167e3b981b0bdc47576c6ea2e78b962344',
    };
    final digest = knownDigests[bytes.join(',')];
    if (digest == null) throw ArgumentError.value(bytes, 'bytes');
    return <String, Object?>{
      'allowedRedirectHosts': ['cdn.example.test'],
      'assetId': assetId,
      'assetRevision': assetRevision,
      'downloadUrl': 'https://cdn.example.test/$assetId.bin',
      'expectedSizeBytes': bytes.length,
      'isRequired': isRequired,
      'logicalRelativePath': 'media/$assetId.bin',
      'mimeType': 'application/octet-stream',
      'sha256Hex': digest,
    };
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

  List<int> _lengthPrefixed(List<int> bytes) => [
    ..._unsigned32(bytes.length),
    ...bytes,
  ];

  List<int> _unsigned32(int integer) => [
    (integer >> 24) & 0xff,
    (integer >> 16) & 0xff,
    (integer >> 8) & 0xff,
    integer & 0xff,
  ];

  String _encodeUnpadded(List<int> bytes) =>
      base64Url.encode(bytes).replaceAll('=', '');
}
