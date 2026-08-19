import '../network/dw_network_class.dart';

enum DwDownloadConsentDecision { allowed, waitingNetwork, waitingConsent }

abstract final class DwDownloadConsentPolicy {
  static final BigInt meteredConfirmationThresholdBytes = BigInt.from(
    101000000,
  );

  static DwDownloadConsentDecision evaluate({
    required DwNetworkClass networkClass,
    required BigInt? packageTotalBytes,
    required String manifestDigest,
    required String? consentedManifestDigest,
  }) {
    if (packageTotalBytes != null && packageTotalBytes.isNegative) {
      throw ArgumentError.value(
        packageTotalBytes,
        'packageTotalBytes',
        'must not be negative',
      );
    }
    if (manifestDigest.isEmpty) {
      throw ArgumentError.value(
        manifestDigest,
        'manifestDigest',
        'must not be empty',
      );
    }
    if (networkClass == DwNetworkClass.offline) {
      return DwDownloadConsentDecision.waitingNetwork;
    }

    final requiresConsent =
        packageTotalBytes == null ||
        (networkClass != DwNetworkClass.unmetered &&
            packageTotalBytes >= meteredConfirmationThresholdBytes);
    if (!requiresConsent || consentedManifestDigest == manifestDigest) {
      return DwDownloadConsentDecision.allowed;
    }
    return DwDownloadConsentDecision.waitingConsent;
  }
}
