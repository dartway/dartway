import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:dartway_offline_server/dartway_offline_server.dart';
import 'package:test/test.dart';

void main() {
  late DwOfflineManifestSigner signer;

  setUp(() async {
    signer = await DwOfflineManifestSigner.fromSeed(
      keyId: 'key-v1',
      privateKeySeed: List<int>.generate(32, (index) => index + 1),
    );
  });

  test('signs the generic canonical v2 envelope consumed by clients', () async {
    final envelopeJson = await signer.sign(_claims());
    final envelope = jsonDecode(envelopeJson) as Map<String, dynamic>;
    final payloadBytes = base64Url.decode(
      base64Url.normalize(envelope['payload'] as String),
    );
    final payloadJson = utf8.decode(payloadBytes);
    final payload = jsonDecode(payloadJson) as Map<String, dynamic>;

    expect(envelope['schemaVersion'], 2);
    expect(envelope['algorithm'], 'Ed25519');
    expect(payload.keys.toList(), orderedEquals([...payload.keys]..sort()));
    expect(
      payload['leaseValidUntilUtcEpochUs'],
      DateTime.utc(2026, 9, 12).microsecondsSinceEpoch,
    );
    expect(payload, isNot(contains('leaseAccessKind')));
    expect(payload, isNot(contains('leaseAccessUntilUtcEpochUs')));
    expect(
      payload,
      isNot(contains('leaseInheritedSourceValidUntilUtcEpochUs')),
    );
    expect((payload['assets'] as List).map((asset) => asset['assetId']), [
      'asset-a',
      'asset-b',
    ]);

    final signature = Signature(
      base64Url.decode(base64Url.normalize(envelope['signature'] as String)),
      publicKey: SimplePublicKey(
        signer.publicKeyBytes,
        type: KeyPairType.ed25519,
      ),
    );
    expect(
      await Ed25519().verify(
        _signingBytes('key-v1', payloadBytes),
        signature: signature,
      ),
      isTrue,
    );
  });

  test('rejects insecure assets before signing', () async {
    final insecureAsset = _asset(
      assetId: 'asset-a',
      downloadUrl: 'http://cdn.example.test/a.mp4',
    );

    expect(
      () => signer.sign(_claims(assets: [insecureAsset])),
      throwsArgumentError,
    );
  });

  test('rejects duplicate asset identities', () async {
    final asset = _asset(assetId: 'asset-a');

    expect(
      () => signer.sign(_claims(assets: [asset, asset])),
      throwsArgumentError,
    );
  });
}

DwOfflineManifestClaims _claims({List<DwOfflineManifestAsset>? assets}) =>
    DwOfflineManifestClaims(
      audience: 'example-mobile',
      userScopeId: '42',
      packageId: 'resource:101',
      contentIdentity: 'resource:101',
      manifestRevision: 'revision-1',
      repositoryContentDigest: 'a' * 64,
      leaseId: 'lease-42-resource-10',
      leaseRecordVersion: 1,
      verifiedServerUtc: DateTime.utc(2026, 8, 13),
      leaseValidUntilUtc: DateTime.utc(2026, 9, 12),
      assets:
          assets ?? [_asset(assetId: 'asset-b'), _asset(assetId: 'asset-a')],
    );

DwOfflineManifestAsset _asset({required String assetId, String? downloadUrl}) =>
    DwOfflineManifestAsset(
      assetId: assetId,
      assetRevision: 'r1',
      downloadUrl: downloadUrl ?? 'https://cdn.example.test/$assetId.mp4',
      allowedRedirectHosts: const ['cdn.example.test'],
      expectedSizeBytes: 5,
      sha256Hex:
          '74f81fe167d99b4cb41d6d0ccda82278caee9f3e2f25d5e5a3936ff3dcec60d0',
      mimeType: 'video/mp4',
      logicalRelativePath: 'media/$assetId.mp4',
    );

List<int> _signingBytes(String keyId, List<int> payloadBytes) {
  final output = BytesBuilder(copy: false)
    ..add(ascii.encode('dartway.offline.manifest\u0000'))
    ..add(_unsigned32(2))
    ..add(_lengthPrefixed(utf8.encode('Ed25519')))
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
