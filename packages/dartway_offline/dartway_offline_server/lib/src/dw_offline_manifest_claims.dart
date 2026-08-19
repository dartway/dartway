import 'dw_offline_manifest_asset.dart';

final class DwOfflineManifestClaims {
  const DwOfflineManifestClaims({
    required this.audience,
    required this.userScopeId,
    required this.packageId,
    required this.contentIdentity,
    required this.manifestRevision,
    required this.repositoryContentDigest,
    required this.leaseId,
    required this.leaseRecordVersion,
    required this.verifiedServerUtc,
    required this.assets,
    this.leaseValidUntilUtc,
    this.leaseIsRevoked = false,
  });

  final String audience;
  final String userScopeId;
  final String packageId;
  final String contentIdentity;
  final String manifestRevision;
  final String repositoryContentDigest;
  final String leaseId;
  final int leaseRecordVersion;
  final DateTime verifiedServerUtc;
  final DateTime? leaseValidUntilUtc;
  final bool leaseIsRevoked;
  final List<DwOfflineManifestAsset> assets;

  Map<String, Object?> toCanonicalMap() {
    _validate();
    final sortedAssets = [...assets]
      ..sort((left, right) {
        final byId = left.assetId.compareTo(right.assetId);
        return byId != 0
            ? byId
            : left.assetRevision.compareTo(right.assetRevision);
      });
    final assetMaps = sortedAssets
        .map((asset) => asset.toCanonicalMap())
        .toList(growable: false);
    for (var index = 1; index < sortedAssets.length; index++) {
      final previous = sortedAssets[index - 1];
      final current = sortedAssets[index];
      if (previous.assetId == current.assetId &&
          previous.assetRevision == current.assetRevision) {
        throw ArgumentError('Offline assets must have unique identities.');
      }
    }
    return <String, Object?>{
      'assets': assetMaps,
      'audience': audience,
      'contentIdentity': contentIdentity,
      'leaseId': leaseId,
      'leaseIsRevoked': leaseIsRevoked,
      'leaseRecordVersion': leaseRecordVersion,
      'leaseValidUntilUtcEpochUs': leaseValidUntilUtc
          ?.toUtc()
          .microsecondsSinceEpoch,
      'manifestRevision': manifestRevision,
      'packageId': packageId,
      'repositoryContentDigest': repositoryContentDigest,
      'userScopeId': userScopeId,
      'verifiedServerUtcEpochUs': verifiedServerUtc
          .toUtc()
          .microsecondsSinceEpoch,
    };
  }

  void _validate() {
    for (final entry in <String, String>{
      'audience': audience,
      'userScopeId': userScopeId,
      'packageId': packageId,
      'contentIdentity': contentIdentity,
      'manifestRevision': manifestRevision,
      'repositoryContentDigest': repositoryContentDigest,
      'leaseId': leaseId,
    }.entries) {
      if (entry.value.isEmpty ||
          entry.value.trim() != entry.value ||
          entry.value.contains('\u0000')) {
        throw ArgumentError.value(entry.value, entry.key);
      }
    }
    if (leaseRecordVersion <= 0) {
      throw ArgumentError.value(leaseRecordVersion, 'leaseRecordVersion');
    }
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(repositoryContentDigest)) {
      throw ArgumentError.value(
        repositoryContentDigest,
        'repositoryContentDigest',
      );
    }
  }
}
