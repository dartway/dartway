import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dartway_offline/src/access/dw_offline_lease_policy.dart';

void main() {
  late SignedManifestFixture manifestFixture;

  setUpAll(() async {
    manifestFixture = await SignedManifestFixture.create();
  });

  group('DwOfflineManifestVerifier', () {
    test(
      'accepts a canonical payload with a valid Ed25519 signature',
      () async {
        final verification = await manifestFixture.verify();

        expect(
          verification.status,
          DwOfflineManifestVerificationStatus.verified,
        );
        expect(verification.verifiedManifest!.manifest.packageId, 'package-a');
        expect(
          verification.verifiedManifest!.acceptedLeaseRecord.status,
          DwOfflineLeaseRecordStatus.accepted,
        );
      },
    );

    test('rejects a changed Ed25519 signature', () async {
      final envelopeJson = await manifestFixture.envelopeJson();
      final envelope = jsonDecode(envelopeJson) as Map<String, Object?>;
      final signatureBytes = manifestFixture.decodeUnpadded(
        envelope['signature']! as String,
      );
      signatureBytes[0] ^= 1;
      envelope['signature'] = manifestFixture.encodeUnpadded(signatureBytes);

      final verification = await manifestFixture.verify(
        envelopeJson: jsonEncode(envelope),
      );

      expect(
        verification.status,
        DwOfflineManifestVerificationStatus.invalidSignature,
      );
    });

    test(
      'rejects a valid signature over non-canonical payload bytes',
      () async {
        final canonicalPayload = manifestFixture.payloadMap();
        final nonCanonicalPayload = const JsonEncoder.withIndent(
          ' ',
        ).convert(canonicalPayload);

        final verification = await manifestFixture.verify(
          envelopeJson: await manifestFixture.envelopeForPayload(
            nonCanonicalPayload,
          ),
        );

        expect(
          verification.status,
          DwOfflineManifestVerificationStatus.nonCanonicalPayload,
        );
      },
    );

    test('rejects unknown keys and padded base64url', () async {
      final unknownKeyEnvelope =
          jsonDecode(await manifestFixture.envelopeJson())
              as Map<String, Object?>;
      unknownKeyEnvelope['keyId'] = 'unknown-key';
      expect(
        (await manifestFixture.verify(
          envelopeJson: jsonEncode(unknownKeyEnvelope),
        )).status,
        DwOfflineManifestVerificationStatus.unknownKey,
      );

      final paddedEnvelope =
          jsonDecode(await manifestFixture.envelopeJson())
              as Map<String, Object?>;
      paddedEnvelope['payload'] = '${paddedEnvelope['payload']}=';
      expect(
        (await manifestFixture.verify(
          envelopeJson: jsonEncode(paddedEnvelope),
        )).status,
        DwOfflineManifestVerificationStatus.invalidEnvelope,
      );
    });

    test('rejects duplicate signed-envelope fields', () async {
      final envelopeJson = await manifestFixture.envelopeJson();
      final duplicateAlgorithmEnvelope = envelopeJson.replaceFirst(
        '{',
        '{"algorithm":"Ed25519",',
      );

      expect(
        (await manifestFixture.verify(
          envelopeJson: duplicateAlgorithmEnvelope,
        )).status,
        DwOfflineManifestVerificationStatus.invalidEnvelope,
      );
    });

    test(
      'rejects caller binding mismatches only after signature verification',
      () async {
        for (final expectedBinding
            in <({String audience, String scope, String package})>[
              (audience: 'other', scope: 'scope-a', package: 'package-a'),
              (audience: 'mobile', scope: 'scope-b', package: 'package-a'),
              (audience: 'mobile', scope: 'scope-a', package: 'package-b'),
            ]) {
          final verification = await manifestFixture.verify(
            expectedAudience: expectedBinding.audience,
            expectedUserScopeId: expectedBinding.scope,
            expectedPackageId: expectedBinding.package,
          );
          expect(
            verification.status,
            DwOfflineManifestVerificationStatus.bindingMismatch,
          );
        }
      },
    );

    test(
      'enforces lower-version replay and same-version payload binding',
      () async {
        final versionTwo = await manifestFixture.verify(
          payloadOverrides: {'leaseRecordVersion': 2},
        );
        final replay = await manifestFixture.verify(
          previousLeaseRecord: versionTwo.verifiedManifest!.acceptedLeaseRecord,
        );
        expect(
          replay.status,
          DwOfflineManifestVerificationStatus.replayRejected,
        );

        final changedPayload = await manifestFixture.verify(
          payloadOverrides: {'manifestRevision': 'manifest-changed'},
          previousLeaseRecord: (await manifestFixture.verify())
              .verifiedManifest!
              .acceptedLeaseRecord,
        );
        expect(
          changedPayload.status,
          DwOfflineManifestVerificationStatus.corrupt,
        );
      },
    );

    test('rejects insecure URLs and logical path traversal', () async {
      for (final invalidAsset in <Map<String, Object?>>[
        {'downloadUrl': 'http://cdn.example.test/asset.bin'},
        {'downloadUrl': 'https://USER@cdn.example.test/asset.bin'},
        {'downloadUrl': 'https://127.0.0.1/asset.bin'},
        {'downloadUrl': 'https://CDN.example.test/asset.bin'},
        {'logicalRelativePath': '../asset.bin'},
        {'logicalRelativePath': 'folder//asset.bin'},
        {'logicalRelativePath': r'folder\asset.bin'},
        {'logicalRelativePath': 'C:/asset.bin'},
      ]) {
        final verification = await manifestFixture.verify(
          assetOverrides: invalidAsset,
        );
        expect(
          verification.status,
          DwOfflineManifestVerificationStatus.invalidPayload,
          reason: invalidAsset.toString(),
        );
      }
    });

    test('rejects short and relative download URLs without throwing', () async {
      for (final downloadUrl in ['x', '/', 'asset.bin']) {
        final verification = await manifestFixture.verify(
          assetOverrides: {'downloadUrl': downloadUrl},
        );

        expect(
          verification.status,
          DwOfflineManifestVerificationStatus.invalidPayload,
          reason: downloadUrl,
        );
      }
    });

    test('rejects unsorted assets and redirect hosts', () async {
      final secondAsset = manifestFixture.assetMap(
        overrides: {'assetId': 'asset-b'},
      );
      expect(
        (await manifestFixture.verify(
          assets: [secondAsset, manifestFixture.assetMap()],
        )).status,
        DwOfflineManifestVerificationStatus.invalidPayload,
      );
      expect(
        (await manifestFixture.verify(
          assetOverrides: {
            'allowedRedirectHosts': ['media.example.test', 'cdn.example.test'],
          },
        )).status,
        DwOfflineManifestVerificationStatus.invalidPayload,
      );
    });
  });

  group('DwOfflineRedirectPolicy', () {
    test(
      'requires exact runtime and signed redirect hosts with five-hop limit',
      () async {
        final verifiedManifest =
            (await manifestFixture.verify()).verifiedManifest!;
        final assetDescriptor = verifiedManifest.manifest.assets.single;
        final redirectPolicy = DwOfflineRedirectPolicy(
          runtimeAllowedHosts: const {'cdn.example.test', 'media.example.test'},
        );

        expect(
          redirectPolicy.allowsInitialUrl(assetDescriptor.downloadUrl),
          isTrue,
        );
        expect(
          redirectPolicy.allowsRedirect(
            redirectUrl: 'https://media.example.test/next',
            assetDescriptor: assetDescriptor,
            redirectHop: 5,
          ),
          isTrue,
        );
        expect(
          redirectPolicy.allowsRedirect(
            redirectUrl: 'https://evil-media.example.test/next',
            assetDescriptor: assetDescriptor,
            redirectHop: 1,
          ),
          isFalse,
        );
        expect(
          redirectPolicy.allowsRedirect(
            redirectUrl: 'https://media.example.test/next',
            assetDescriptor: assetDescriptor,
            redirectHop: 6,
          ),
          isFalse,
        );
      },
    );
  });
}

final class SignedManifestFixture {
  SignedManifestFixture._({
    required this.keyPair,
    required this.publicKeyBytes,
  });

  static const String keyId = 'manifest-key-v2';
  static const String algorithmName = 'Ed25519';
  static const int schemaVersion = 2;

  final SimpleKeyPair keyPair;
  final List<int> publicKeyBytes;

  static Future<SignedManifestFixture> create() async {
    final signatureAlgorithm = Ed25519();
    final keyPair = await signatureAlgorithm.newKeyPairFromSeed(
      List<int>.generate(32, (index) => index + 1),
    );
    final publicKey = await keyPair.extractPublicKey();
    return SignedManifestFixture._(
      keyPair: keyPair,
      publicKeyBytes: publicKey.bytes,
    );
  }

  Future<DwOfflineManifestVerificationResult> verify({
    String? envelopeJson,
    String expectedAudience = 'mobile',
    String expectedUserScopeId = 'scope-a',
    String expectedPackageId = 'package-a',
    Map<String, Object?> payloadOverrides = const {},
    Map<String, Object?> assetOverrides = const {},
    List<Map<String, Object?>>? assets,
    DwOfflineLeaseRecord previousLeaseRecord =
        const DwOfflineLeaseRecord.missing(),
  }) async {
    final effectiveEnvelope =
        envelopeJson ??
        await this.envelopeJson(
          payloadOverrides: payloadOverrides,
          assetOverrides: assetOverrides,
          assets: assets,
        );
    return DwOfflineManifestVerifier(
      pinnedPublicKeys: {keyId: publicKeyBytes},
    ).verify(
      envelopeJson: effectiveEnvelope,
      expectedAudience: expectedAudience,
      expectedUserScopeId: expectedUserScopeId,
      expectedPackageId: expectedPackageId,
      previousLeaseRecord: previousLeaseRecord,
    );
  }

  Future<String> envelopeJson({
    Map<String, Object?> payloadOverrides = const {},
    Map<String, Object?> assetOverrides = const {},
    List<Map<String, Object?>>? assets,
  }) {
    final payload = payloadMap(
      payloadOverrides: payloadOverrides,
      assetOverrides: assetOverrides,
      assets: assets,
    );
    return envelopeForPayload(jsonEncode(payload));
  }

  Future<String> envelopeForPayload(String payloadJson) async {
    final payloadBytes = utf8.encode(payloadJson);
    final signature = await Ed25519().sign(
      signingBytes(payloadBytes),
      keyPair: keyPair,
    );
    return jsonEncode(<String, Object?>{
      'schemaVersion': schemaVersion,
      'algorithm': algorithmName,
      'keyId': keyId,
      'payload': encodeUnpadded(payloadBytes),
      'signature': encodeUnpadded(signature.bytes),
    });
  }

  Map<String, Object?> payloadMap({
    Map<String, Object?> payloadOverrides = const {},
    Map<String, Object?> assetOverrides = const {},
    List<Map<String, Object?>>? assets,
  }) {
    final payload = <String, Object?>{
      'assets': assets ?? [assetMap(overrides: assetOverrides)],
      'audience': 'mobile',
      'contentIdentity': 'content-a',
      'leaseId': 'lease-a',
      'leaseIsRevoked': false,
      'leaseRecordVersion': 1,
      'leaseValidUntilUtcEpochUs': DateTime.utc(2026, 3).microsecondsSinceEpoch,
      'manifestRevision': 'manifest-1',
      'packageId': 'package-a',
      'repositoryContentDigest': 'a' * 64,
      'userScopeId': 'scope-a',
      'verifiedServerUtcEpochUs': DateTime.utc(2026, 2).microsecondsSinceEpoch,
    };
    for (final payloadOverride in payloadOverrides.entries) {
      payload[payloadOverride.key] = payloadOverride.value;
    }
    return payload;
  }

  Map<String, Object?> assetMap({Map<String, Object?> overrides = const {}}) {
    final asset = <String, Object?>{
      'allowedRedirectHosts': ['cdn.example.test', 'media.example.test'],
      'assetId': 'asset-a',
      'assetRevision': 'r1',
      'downloadUrl': 'https://cdn.example.test/asset.bin',
      'expectedSizeBytes': 5,
      'isRequired': true,
      'logicalRelativePath': 'media/asset.bin',
      'mimeType': 'application/octet-stream',
      'sha256Hex':
          '74f81fe167d99b4cb41d6d0ccda82278caee9f3e2f25d5e5a3936ff3a4523804',
    };
    for (final assetOverride in overrides.entries) {
      asset[assetOverride.key] = assetOverride.value;
    }
    return asset;
  }

  List<int> signingBytes(List<int> payloadBytes) {
    final output = BytesBuilder(copy: false)
      ..add(ascii.encode('dartway.offline.manifest\u0000'))
      ..add(unsigned32(schemaVersion))
      ..add(lengthPrefixed(utf8.encode(algorithmName)))
      ..add(lengthPrefixed(utf8.encode(keyId)))
      ..add(lengthPrefixed(payloadBytes));
    return output.takeBytes();
  }

  List<int> lengthPrefixed(List<int> bytes) => [
    ...unsigned32(bytes.length),
    ...bytes,
  ];

  List<int> unsigned32(int integer) => [
    (integer >> 24) & 0xff,
    (integer >> 16) & 0xff,
    (integer >> 8) & 0xff,
    integer & 0xff,
  ];

  String encodeUnpadded(List<int> bytes) =>
      base64Url.encode(bytes).replaceAll('=', '');

  List<int> decodeUnpadded(String encoded) =>
      base64Url.decode(base64Url.normalize(encoded));
}
