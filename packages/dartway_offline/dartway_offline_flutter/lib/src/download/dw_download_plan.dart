import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../access/dw_offline_lease_policy.dart';

final class DwDownloadAssetPlan {
  DwDownloadAssetPlan({
    required this.assetId,
    required this.assetRevision,
    required this.expectedSizeBytes,
    this.isRequired = true,
  }) {
    if (assetId.isEmpty || assetRevision.isEmpty) {
      throw ArgumentError('Asset identity must not be empty.');
    }
    if (expectedSizeBytes < 0) {
      throw ArgumentError.value(
        expectedSizeBytes,
        'expectedSizeBytes',
        'must not be negative',
      );
    }
  }

  final String assetId;
  final String assetRevision;
  final int expectedSizeBytes;
  final bool isRequired;
}

final class DwDownloadPackagePlan {
  static final BigInt _maximumSqliteInteger = BigInt.parse(
    '9223372036854775807',
  );

  DwDownloadPackagePlan({
    required this.userScopeId,
    required this.packageId,
    required this.manifestRevision,
    required this.manifestDigest,
    required this.priority,
    required Iterable<DwDownloadAssetPlan> assets,
  }) : assets = List.unmodifiable(assets) {
    if (userScopeId.trim().isEmpty ||
        packageId.isEmpty ||
        manifestRevision.isEmpty ||
        manifestDigest.isEmpty) {
      throw ArgumentError('Download plan identity must not be empty.');
    }
    if (priority < 0) {
      throw ArgumentError.value(priority, 'priority', 'must not be negative');
    }
    final identities = <(String, String)>{};
    for (final asset in this.assets) {
      if (!identities.add((asset.assetId, asset.assetRevision))) {
        throw ArgumentError('Download plan contains a duplicate asset.');
      }
    }
    if (BigInt.from(packageTotalBytes) > _maximumSqliteInteger) {
      throw ArgumentError('Download package exceeds SQLite integer range.');
    }
  }

  factory DwDownloadPackagePlan.fromVerifiedManifest(
    DwVerifiedOfflineManifest verifiedManifest, {
    int priority = 0,
  }) {
    final manifest = verifiedManifest.manifest;
    return DwDownloadPackagePlan(
      userScopeId: manifest.userScopeId,
      packageId: manifest.packageId,
      manifestRevision: manifest.manifestRevision,
      manifestDigest: verifiedManifest.payloadDigest,
      priority: priority,
      assets: manifest.assets.map(
        (asset) => DwDownloadAssetPlan(
          assetId: asset.assetId,
          assetRevision: asset.assetRevision,
          expectedSizeBytes: asset.expectedSizeBytes,
          isRequired: asset.isRequired,
        ),
      ),
    );
  }

  final String userScopeId;
  final String packageId;
  final String manifestRevision;
  final String manifestDigest;
  final int priority;
  final List<DwDownloadAssetPlan> assets;

  int get packageTotalBytes => assets.fold(
    0,
    (totalBytes, asset) => totalBytes + asset.expectedSizeBytes,
  );

  String get jobId {
    final identityBytes = utf8.encode(
      jsonEncode([userScopeId, packageId, manifestRevision, manifestDigest]),
    );
    return 'dw_${sha256.convert(identityBytes)}';
  }
}
