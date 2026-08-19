import 'package:dartway_offline_flutter/src/download/dw_download_consent_policy.dart';
import 'package:dartway_offline_flutter/src/network/dw_network_class.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DwDownloadConsentPolicy', () {
    const digest = 'manifest-v1';

    test('offline waits for network before considering consent', () {
      expect(
        DwDownloadConsentPolicy.evaluate(
          networkClass: DwNetworkClass.offline,
          packageTotalBytes: null,
          manifestDigest: digest,
          consentedManifestDigest: null,
        ),
        DwDownloadConsentDecision.waitingNetwork,
      );
    });

    test('unmetered known-size downloads do not require consent', () {
      expect(
        DwDownloadConsentPolicy.evaluate(
          networkClass: DwNetworkClass.unmetered,
          packageTotalBytes: BigInt.from(101000000),
          manifestDigest: digest,
          consentedManifestDigest: null,
        ),
        DwDownloadConsentDecision.allowed,
      );
    });

    test('metered boundary is inclusive and one byte below is allowed', () {
      final belowBoundary = DwDownloadConsentPolicy.evaluate(
        networkClass: DwNetworkClass.metered,
        packageTotalBytes: BigInt.from(100999999),
        manifestDigest: digest,
        consentedManifestDigest: null,
      );
      final atBoundary = DwDownloadConsentPolicy.evaluate(
        networkClass: DwNetworkClass.metered,
        packageTotalBytes: BigInt.from(101000000),
        manifestDigest: digest,
        consentedManifestDigest: null,
      );

      expect(belowBoundary, DwDownloadConsentDecision.allowed);
      expect(atBoundary, DwDownloadConsentDecision.waitingConsent);
    });

    test('unknown network is handled conservatively as metered', () {
      expect(
        DwDownloadConsentPolicy.evaluate(
          networkClass: DwNetworkClass.unknown,
          packageTotalBytes: BigInt.from(101000000),
          manifestDigest: digest,
          consentedManifestDigest: null,
        ),
        DwDownloadConsentDecision.waitingConsent,
      );
    });

    test('unknown package size requires consent on every online network', () {
      for (final networkClass in const [
        DwNetworkClass.metered,
        DwNetworkClass.unmetered,
        DwNetworkClass.unknown,
      ]) {
        expect(
          DwDownloadConsentPolicy.evaluate(
            networkClass: networkClass,
            packageTotalBytes: null,
            manifestDigest: digest,
            consentedManifestDigest: null,
          ),
          DwDownloadConsentDecision.waitingConsent,
        );
      }
    });

    test('consent is valid only for the exact manifest digest', () {
      final accepted = DwDownloadConsentPolicy.evaluate(
        networkClass: DwNetworkClass.metered,
        packageTotalBytes: BigInt.from(101000000),
        manifestDigest: digest,
        consentedManifestDigest: digest,
      );
      final stale = DwDownloadConsentPolicy.evaluate(
        networkClass: DwNetworkClass.metered,
        packageTotalBytes: BigInt.from(101000000),
        manifestDigest: 'manifest-v2',
        consentedManifestDigest: digest,
      );

      expect(accepted, DwDownloadConsentDecision.allowed);
      expect(stale, DwDownloadConsentDecision.waitingConsent);
    });

    test('invalid sizes and empty manifest digests fail fast', () {
      expect(
        () => DwDownloadConsentPolicy.evaluate(
          networkClass: DwNetworkClass.metered,
          packageTotalBytes: BigInt.from(-1),
          manifestDigest: digest,
          consentedManifestDigest: null,
        ),
        throwsArgumentError,
      );
      expect(
        () => DwDownloadConsentPolicy.evaluate(
          networkClass: DwNetworkClass.metered,
          packageTotalBytes: BigInt.zero,
          manifestDigest: '',
          consentedManifestDigest: null,
        ),
        throwsArgumentError,
      );
    });
  });
}
