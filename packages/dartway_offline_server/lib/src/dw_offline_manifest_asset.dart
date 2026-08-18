final class DwOfflineManifestAsset {
  const DwOfflineManifestAsset({
    required this.assetId,
    required this.assetRevision,
    required this.downloadUrl,
    required this.allowedRedirectHosts,
    required this.expectedSizeBytes,
    required this.sha256Hex,
    required this.mimeType,
    required this.logicalRelativePath,
    this.isRequired = true,
  });

  final String assetId;
  final String assetRevision;
  final String downloadUrl;
  final List<String> allowedRedirectHosts;
  final int expectedSizeBytes;
  final String sha256Hex;
  final String mimeType;
  final String logicalRelativePath;
  final bool isRequired;

  Map<String, Object?> toCanonicalMap() {
    _validate();
    final redirectHosts = [...allowedRedirectHosts]..sort();
    if (redirectHosts.toSet().length != redirectHosts.length) {
      throw ArgumentError.value(
        allowedRedirectHosts,
        'allowedRedirectHosts',
        'must not contain duplicates',
      );
    }
    return <String, Object?>{
      'allowedRedirectHosts': redirectHosts,
      'assetId': assetId,
      'assetRevision': assetRevision,
      'downloadUrl': downloadUrl,
      'expectedSizeBytes': expectedSizeBytes,
      'isRequired': isRequired,
      'logicalRelativePath': logicalRelativePath,
      'mimeType': mimeType,
      'sha256Hex': sha256Hex,
    };
  }

  void _validate() {
    _requireText(assetId, 'assetId');
    _requireText(assetRevision, 'assetRevision');
    _requireText(mimeType, 'mimeType');
    if (expectedSizeBytes < 0) {
      throw ArgumentError.value(expectedSizeBytes, 'expectedSizeBytes');
    }
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(sha256Hex)) {
      throw ArgumentError.value(sha256Hex, 'sha256Hex');
    }
    if (!_isValidHttpsUrl(downloadUrl)) {
      throw ArgumentError.value(downloadUrl, 'downloadUrl');
    }
    if (!_isValidLogicalPath(logicalRelativePath)) {
      throw ArgumentError.value(logicalRelativePath, 'logicalRelativePath');
    }
    for (final host in allowedRedirectHosts) {
      if (!_isValidDnsHost(host)) {
        throw ArgumentError.value(host, 'allowedRedirectHosts');
      }
    }
  }

  static bool _isValidHttpsUrl(String value) {
    final uri = Uri.tryParse(value);
    return value.startsWith('https://') &&
        uri != null &&
        uri.scheme == 'https' &&
        uri.hasAuthority &&
        uri.userInfo.isEmpty &&
        !uri.hasFragment &&
        !uri.hasPort &&
        _isValidDnsHost(uri.host);
  }

  static bool _isValidLogicalPath(String value) {
    if (value.isEmpty ||
        value.trim() != value ||
        value.startsWith('/') ||
        value.contains(r'\')) {
      return false;
    }
    final segments = value.split('/');
    return segments.every(
      (segment) => segment.isNotEmpty && segment != '.' && segment != '..',
    );
  }

  static bool _isValidDnsHost(String value) {
    if (value.isEmpty || value != value.toLowerCase() || value.length > 253) {
      return false;
    }
    final labels = value.split('.');
    return labels.every(
      (label) =>
          label.isNotEmpty &&
          label.length <= 63 &&
          RegExp(r'^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$').hasMatch(label),
    );
  }

  static void _requireText(String value, String name) {
    if (value.isEmpty || value.trim() != value || value.contains('\u0000')) {
      throw ArgumentError.value(value, name);
    }
  }
}
