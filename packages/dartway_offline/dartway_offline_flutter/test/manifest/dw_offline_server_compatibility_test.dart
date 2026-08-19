import 'package:dartway_offline_flutter/src/access/dw_offline_lease_policy.dart';
import 'package:dartway_offline_server/dartway_offline_server.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'server signer produces a manifest accepted by the mobile verifier',
    () async {
      final signer = await DwOfflineManifestSigner.fromSeed(
        keyId: 'key-v1',
        privateKeySeed: List<int>.generate(32, (index) => index + 1),
      );
      final envelope = await signer.sign(
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
          assets: const [
            DwOfflineManifestAsset(
              assetId: 'material:7',
              assetRevision: 'r1',
              downloadUrl: 'https://cdn.example.test/video.mp4',
              allowedRedirectHosts: ['cdn.example.test'],
              expectedSizeBytes: 5,
              sha256Hex:
                  '74f81fe167d99b4cb41d6d0ccda82278caee9f3e2f25d5e5a3936ff3dcec60d0',
              mimeType: 'video/mp4',
              logicalRelativePath: 'media/video.mp4',
            ),
          ],
        ),
      );

      final result =
          await DwOfflineManifestVerifier(
            pinnedPublicKeys: {'key-v1': signer.publicKeyBytes},
          ).verify(
            envelopeJson: envelope,
            expectedAudience: 'example-mobile',
            expectedUserScopeId: '42',
            expectedPackageId: 'resource:101',
          );

      expect(result.status, DwOfflineManifestVerificationStatus.verified);
    },
  );
}
