part of '../access/dw_offline_lease_policy.dart';

/// Immutable integrity and transport metadata for one manifest asset.
final class DwOfflineAssetDescriptor {
  const DwOfflineAssetDescriptor._({
    required this.assetId,
    required this.assetRevision,
    required this.downloadUrl,
    required this.allowedRedirectHosts,
    required this.expectedSizeBytes,
    required this.sha256Hex,
    required this.mimeType,
    required this.logicalRelativePath,
    required this.isRequired,
  });

  /// Reconstructs already-verified metadata during store reconciliation.
  factory DwOfflineAssetDescriptor.internalForStorage({
    required String assetId,
    required String assetRevision,
    required String downloadUrl,
    required List<String> allowedRedirectHosts,
    required int expectedSizeBytes,
    required String sha256Hex,
    required String mimeType,
    required String logicalRelativePath,
    required bool isRequired,
  }) {
    return DwOfflineAssetDescriptor._(
      assetId: assetId,
      assetRevision: assetRevision,
      downloadUrl: downloadUrl,
      allowedRedirectHosts: List<String>.unmodifiable(allowedRedirectHosts),
      expectedSizeBytes: expectedSizeBytes,
      sha256Hex: sha256Hex,
      mimeType: mimeType,
      logicalRelativePath: logicalRelativePath,
      isRequired: isRequired,
    );
  }

  final String assetId;
  final String assetRevision;
  final String downloadUrl;
  final List<String> allowedRedirectHosts;
  final int expectedSizeBytes;
  final String sha256Hex;
  final String mimeType;
  final String logicalRelativePath;
  final bool isRequired;
}

/// Exact-host redirect checks for a transport with automatic redirects off.
final class DwOfflineRedirectPolicy {
  DwOfflineRedirectPolicy({required Set<String> runtimeAllowedHosts})
    : _runtimeAllowedHosts = Set<String>.unmodifiable(runtimeAllowedHosts);

  static const int maximumRedirectHops = 5;

  final Set<String> _runtimeAllowedHosts;

  bool allowsInitialUrl(String downloadUrl) {
    final parsedUrl = _DwOfflineManifestSyntax.validHttpsUrl(downloadUrl);
    return parsedUrl != null && _runtimeAllowedHosts.contains(parsedUrl.host);
  }

  bool allowsRedirect({
    required String redirectUrl,
    required DwOfflineAssetDescriptor assetDescriptor,
    required int redirectHop,
  }) {
    if (redirectHop < 1 || redirectHop > maximumRedirectHops) return false;
    final parsedUrl = _DwOfflineManifestSyntax.validHttpsUrl(redirectUrl);
    return parsedUrl != null &&
        _runtimeAllowedHosts.contains(parsedUrl.host) &&
        assetDescriptor.allowedRedirectHosts.contains(parsedUrl.host);
  }
}
