import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:dartway_offline/src/access/dw_offline_lease_policy.dart';

import '../support/signed_manifest_fixture.dart';

void main() {
  late TestSignedManifestFixture manifestFixture;
  final verifiedServerUtc = DateTime.utc(2026, 1, 10, 12);

  setUpAll(() async {
    manifestFixture = await TestSignedManifestFixture.create();
  });

  group('DwOfflineLease signed creation', () {
    test('uses the exact signed validity boundary', () async {
      final validUntilUtc = DateTime.utc(2026, 1, 13, 8);
      final verifiedManifest = await manifestFixture.verify(
        verifiedServerUtc: verifiedServerUtc,
        leaseValidUntilUtc: validUntilUtc,
      );

      expect(
        verifiedManifest.acceptedLeaseRecord.lease!.validUntilUtc,
        validUntilUtc,
      );
    });

    test('an unbounded lease has no hard offline expiry', () async {
      final verifiedManifest = await manifestFixture.verify(
        verifiedServerUtc: verifiedServerUtc,
        unboundedLease: true,
      );

      expect(verifiedManifest.acceptedLeaseRecord.lease!.validUntilUtc, isNull);
    });
  });

  group('DwOfflineLeasePolicy', () {
    test(
      'expires at the exact boundary but is usable one microsecond before',
      () async {
        final verifiedManifest = await manifestFixture.verify(
          verifiedServerUtc: verifiedServerUtc,
          leaseValidUntilUtc: DateTime.utc(2026, 1, 17),
        );
        final acceptedLease = verifiedManifest.acceptedLeaseRecord.lease!;

        expect(
          _LeasePolicyEvaluationFixture.evaluateAt(
            verifiedManifest,
            acceptedLease.validUntilUtc!.subtract(
              const Duration(microseconds: 1),
            ),
          ).decision,
          DwOfflineLeaseDecision.usable,
        );
        expect(
          _LeasePolicyEvaluationFixture.evaluateAt(
            verifiedManifest,
            acceptedLease.validUntilUtc!,
          ).decision,
          DwOfflineLeaseDecision.expired,
        );
      },
    );

    test('revocation wins over expiry', () async {
      final verifiedManifest = await manifestFixture.verify(
        verifiedServerUtc: verifiedServerUtc,
        leaseValidUntilUtc: DateTime.utc(2026, 1, 11),
        leaseIsRevoked: true,
      );

      expect(
        _LeasePolicyEvaluationFixture.evaluateAt(
          verifiedManifest,
          DateTime.utc(2030),
        ).decision,
        DwOfflineLeaseDecision.revoked,
      );
    });

    test('missing and corrupt records fail closed', () async {
      final verifiedManifest = await manifestFixture.verify(
        verifiedServerUtc: verifiedServerUtc,
      );
      final trustedReading = verifiedManifest
          .createTrustedTime(
            timeSource: _LeasePolicyTimeSource(
              wallClockUtcNow: verifiedServerUtc,
              monotonicElapsed: Duration.zero,
            ),
          )
          .read();

      expect(
        DwOfflineLeasePolicy.evaluate(
          leaseRecord: const DwOfflineLeaseRecord.missing(),
          trustedTime: trustedReading,
        ).decision,
        DwOfflineLeaseDecision.needsOnlineValidation,
      );
      expect(
        DwOfflineLeasePolicy.evaluate(
          leaseRecord: const DwOfflineLeaseRecord.corrupt(),
          trustedTime: trustedReading,
        ).decision,
        DwOfflineLeaseDecision.corrupt,
      );
    });

    test('a higher signed lease version unlocks retained content', () async {
      final expiredManifest = await manifestFixture.verify(
        verifiedServerUtc: DateTime.utc(2025),
        leaseValidUntilUtc: DateTime.utc(2025, 1, 2),
      );
      final renewedManifest = await manifestFixture.verify(
        leaseRecordVersion: 2,
        manifestRevision: 'manifest-2',
        verifiedServerUtc: verifiedServerUtc,
        leaseValidUntilUtc: DateTime.utc(2027),
        previousLeaseRecord: expiredManifest.acceptedLeaseRecord,
      );

      expect(
        _LeasePolicyEvaluationFixture.evaluateAt(
          expiredManifest,
          verifiedServerUtc,
        ).decision,
        DwOfflineLeaseDecision.expired,
      );
      expect(
        _LeasePolicyEvaluationFixture.evaluateAt(
          renewedManifest,
          verifiedServerUtc,
        ).decision,
        DwOfflineLeaseDecision.usable,
      );
    });

    test(
      'an unbounded lease remains usable and requests validation when online',
      () async {
        final verifiedManifest = await manifestFixture.verify(
          verifiedServerUtc: verifiedServerUtc,
          unboundedLease: true,
        );
        final offlineEvaluation = _LeasePolicyEvaluationFixture.evaluateAt(
          verifiedManifest,
          DateTime.utc(2035),
        );
        final onlineEvaluation = _LeasePolicyEvaluationFixture.evaluateAt(
          verifiedManifest,
          DateTime.utc(2035),
          connectivityAvailable: true,
        );

        expect(offlineEvaluation.decision, DwOfflineLeaseDecision.usable);
        expect(offlineEvaluation.requiresOnlineValidation, isFalse);
        expect(onlineEvaluation.decision, DwOfflineLeaseDecision.usable);
        expect(onlineEvaluation.requiresOnlineValidation, isTrue);
      },
    );

    test('clock rollback requires validation before protected use', () async {
      final verifiedManifest = await manifestFixture.verify(
        verifiedServerUtc: verifiedServerUtc,
      );
      final initialClock = verifiedManifest.createTrustedTime(
        timeSource: _LeasePolicyTimeSource(
          wallClockUtcNow: verifiedServerUtc.add(const Duration(minutes: 10)),
          monotonicElapsed: Duration.zero,
        ),
      );
      final restoredClock = DwTrustedTime.fromPersistedSnapshot(
        persistedSnapshot: initialClock.persistedSnapshot.toPersistedMap(),
        timeSource: _LeasePolicyTimeSource(
          wallClockUtcNow: verifiedServerUtc,
          monotonicElapsed: Duration.zero,
        ),
      );

      expect(
        DwOfflineLeasePolicy.evaluate(
          leaseRecord: verifiedManifest.acceptedLeaseRecord,
          trustedTime: restoredClock.read(),
        ).decision,
        DwOfflineLeaseDecision.needsOnlineValidation,
      );
    });
  });

  group('DwOfflineLease persistence', () {
    test(
      'round-trips every accepted field exactly after reverification',
      () async {
        final verifiedManifest = await manifestFixture.verify(
          verifiedServerUtc: verifiedServerUtc,
          leaseValidUntilUtc: DateTime.utc(2026, 1, 20),
        );
        final acceptedLease = verifiedManifest.acceptedLeaseRecord.lease!;
        final encodedClaims = jsonDecode(
          jsonEncode(acceptedLease.toPersistedMap()),
        );
        final persistedClaims = DwPersistedOfflineLease.decode(encodedClaims);

        expect(persistedClaims.status, DwPersistedOfflineLeaseStatus.decoded);
        expect(
          verifiedManifest
              .reverifyPersistedLease(persistedClaims: persistedClaims)
              .status,
          DwOfflineLeaseAcceptanceStatus.accepted,
        );
      },
    );

    test('tampered persisted claims cannot extend signed access', () async {
      final verifiedManifest = await manifestFixture.verify(
        verifiedServerUtc: verifiedServerUtc,
        leaseValidUntilUtc: DateTime.utc(2026, 1, 20),
      );
      final persistedMap = verifiedManifest.acceptedLeaseRecord.lease!
          .toPersistedMap();
      final tamperedClaims = DwPersistedOfflineLease.decode({
        ...persistedMap,
        'validUntilUtcEpochUs': DateTime.utc(2030).microsecondsSinceEpoch,
      });

      expect(
        verifiedManifest
            .reverifyPersistedLease(persistedClaims: tamperedClaims)
            .status,
        DwOfflineLeaseAcceptanceStatus.corrupt,
      );
    });

    test('malformed and old millisecond records remain unaccepted', () {
      expect(
        DwPersistedOfflineLease.decode(null).status,
        DwPersistedOfflineLeaseStatus.missing,
      );
      expect(
        DwPersistedOfflineLease.decode({'schemaVersion': 1}).status,
        DwPersistedOfflineLeaseStatus.corrupt,
      );
      expect(
        DwPersistedOfflineLease.decode({
          'schemaVersion': 1,
          'timestampEncoding': 'epochMillisecondsUtc',
        }).status,
        DwPersistedOfflineLeaseStatus.corrupt,
      );
    });
  });
}

final class _LeasePolicyEvaluationFixture {
  const _LeasePolicyEvaluationFixture._();

  static DwOfflineLeaseEvaluation evaluateAt(
    DwVerifiedOfflineManifest verifiedManifest,
    DateTime trustedNowUtc, {
    bool connectivityAvailable = false,
  }) {
    final trustedTime = verifiedManifest.createTrustedTime(
      timeSource: _LeasePolicyTimeSource(
        wallClockUtcNow: trustedNowUtc,
        monotonicElapsed: Duration.zero,
      ),
    );
    return DwOfflineLeasePolicy.evaluate(
      leaseRecord: verifiedManifest.acceptedLeaseRecord,
      trustedTime: trustedTime.read(),
      connectivityAvailable: connectivityAvailable,
    );
  }
}

final class _LeasePolicyTimeSource implements DwTrustedTimeSource {
  const _LeasePolicyTimeSource({
    required this.wallClockUtcNow,
    required this.monotonicElapsed,
  });

  @override
  final DateTime wallClockUtcNow;

  @override
  final Duration monotonicElapsed;
}
