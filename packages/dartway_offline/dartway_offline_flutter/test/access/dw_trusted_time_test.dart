import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:dartway_offline_flutter/src/access/dw_offline_lease_policy.dart';

import '../support/signed_manifest_fixture.dart';

void main() {
  setUpAll(() async {
    TrustedTimeFixtures.manifestFixture =
        await TestSignedManifestFixture.create();
  });
  group('DwTrustedTime same process', () {
    test(
      'advances only from monotonic elapsed time across wall changes',
      () async {
        final source = MutableTrustedTimeSource(
          wallClockUtcNow: DateTime.utc(2026, 3, 29, 1),
          monotonicElapsed: const Duration(hours: 4),
        );
        final trustedTime = (await TrustedTimeFixtures.verifiedManifest(
          verifiedServerUtc: DateTime.utc(2026, 3, 29, 1),
        )).createTrustedTime(timeSource: source);

        source
          ..wallClockUtcNow = DateTime.utc(2026, 3, 28, 1)
          ..monotonicElapsed = const Duration(hours: 5);
        expect(trustedTime.read().trustedNowUtc, DateTime.utc(2026, 3, 29, 2));

        source
          ..wallClockUtcNow = DateTime.utc(2030)
          ..monotonicElapsed = const Duration(hours: 6);
        expect(trustedTime.read().trustedNowUtc, DateTime.utc(2026, 3, 29, 3));
      },
    );

    test('never decreases when monotonic elapsed time is unchanged', () async {
      final source = MutableTrustedTimeSource(
        wallClockUtcNow: DateTime.utc(2026, 1, 1),
        monotonicElapsed: Duration.zero,
      );
      final trustedTime = (await TrustedTimeFixtures.verifiedManifest(
        verifiedServerUtc: DateTime.utc(2026, 1, 1),
      )).createTrustedTime(timeSource: source);

      source.monotonicElapsed = const Duration(seconds: 30);
      final firstReading = trustedTime.read();
      final secondReading = trustedTime.read();

      expect(firstReading, secondReading);
    });

    test('a regressed runtime monotonic clock is corrupt', () async {
      final source = MutableTrustedTimeSource(
        wallClockUtcNow: DateTime.utc(2026, 1, 1),
        monotonicElapsed: const Duration(hours: 2),
      );
      final trustedTime = (await TrustedTimeFixtures.verifiedManifest(
        verifiedServerUtc: DateTime.utc(2026, 1, 1),
      )).createTrustedTime(timeSource: source);

      source.monotonicElapsed = const Duration(hours: 1);

      expect(trustedTime.read().status, DwTrustedTimeStatus.corrupt);
    });

    test(
      'persisted watermark retains monotonic progress across restart',
      () async {
        final frozenWallUtc = DateTime.utc(2026, 1, 1);
        final source = MutableTrustedTimeSource(
          wallClockUtcNow: frozenWallUtc,
          monotonicElapsed: Duration.zero,
        );
        final trustedTime = (await TrustedTimeFixtures.verifiedManifest(
          verifiedServerUtc: frozenWallUtc,
        )).createTrustedTime(timeSource: source);
        source.monotonicElapsed = const Duration(days: 6);

        expect(trustedTime.read().trustedNowUtc, DateTime.utc(2026, 1, 7));
        final restored = DwTrustedTime.fromPersistedSnapshot(
          persistedSnapshot: trustedTime.persistedSnapshot.toPersistedMap(),
          timeSource: MutableTrustedTimeSource(
            wallClockUtcNow: frozenWallUtc,
            monotonicElapsed: Duration.zero,
          ),
        );

        expect(restored.read().trustedNowUtc, DateTime.utc(2026, 1, 7));
      },
    );
  });

  group('DwTrustedTime restart', () {
    final verifiedServerUtc = DateTime.utc(2026, 6, 1, 12);

    test(
      'normal offline relaunch anchors at the conservative current time',
      () async {
        final snapshot = await TrustedTimeFixtures.snapshot(
          verifiedServerUtc: verifiedServerUtc,
          wallClockUtc: verifiedServerUtc,
        );
        final restartSource = MutableTrustedTimeSource(
          wallClockUtcNow: DateTime.utc(2026, 6, 1, 12, 40),
          monotonicElapsed: const Duration(minutes: 2),
        );

        final restored = DwTrustedTime.fromPersistedSnapshot(
          persistedSnapshot: snapshot.toPersistedMap(),
          timeSource: restartSource,
        );

        expect(restored.read().trustedNowUtc, DateTime.utc(2026, 6, 1, 12, 40));
      },
    );

    test(
      'rollback of exactly five minutes is allowed without decreasing',
      () async {
        final snapshot = await TrustedTimeFixtures.snapshot(
          verifiedServerUtc: verifiedServerUtc,
          wallClockUtc: DateTime.utc(2026, 6, 1, 12, 10),
        );
        final restartSource = MutableTrustedTimeSource(
          wallClockUtcNow: DateTime.utc(2026, 6, 1, 12, 5),
          monotonicElapsed: const Duration(days: 3),
        );

        final restored = DwTrustedTime.fromPersistedSnapshot(
          persistedSnapshot: snapshot.toPersistedMap(),
          timeSource: restartSource,
        );

        expect(restored.read().trustedNowUtc, DateTime.utc(2026, 6, 1, 12, 10));
      },
    );

    test('rollback beyond five minutes requires online validation', () async {
      final snapshot = await TrustedTimeFixtures.snapshot(
        verifiedServerUtc: verifiedServerUtc,
        wallClockUtc: DateTime.utc(2026, 6, 1, 12, 10),
      );
      final restartSource = MutableTrustedTimeSource(
        wallClockUtcNow: DateTime.utc(2026, 6, 1, 12, 4, 59, 999),
        monotonicElapsed: Duration.zero,
      );

      final restored = DwTrustedTime.fromPersistedSnapshot(
        persistedSnapshot: snapshot.toPersistedMap(),
        timeSource: restartSource,
      );

      expect(restored.read().status, DwTrustedTimeStatus.needsOnlineValidation);
    });

    test('a forward wall jump can move trusted time forward only', () async {
      final snapshot = await TrustedTimeFixtures.snapshot(
        verifiedServerUtc: verifiedServerUtc,
        wallClockUtc: verifiedServerUtc,
      );
      final restartSource = MutableTrustedTimeSource(
        wallClockUtcNow: DateTime.utc(2027, 1, 1),
        monotonicElapsed: const Duration(minutes: 8),
      );

      final restored = DwTrustedTime.fromPersistedSnapshot(
        persistedSnapshot: snapshot.toPersistedMap(),
        timeSource: restartSource,
      );

      expect(restored.read().trustedNowUtc, DateTime.utc(2027, 1, 1));
    });
  });

  group('DwTrustedTime UTC and persistence', () {
    test(
      'equivalent timezone and DST instants produce equal snapshots',
      () async {
        final utcSource = MutableTrustedTimeSource(
          wallClockUtcNow: DateTime.parse('2026-10-25T01:30:00Z'),
          monotonicElapsed: const Duration(minutes: 30),
        );
        final offsetSource = MutableTrustedTimeSource(
          wallClockUtcNow: DateTime.parse('2026-10-25T03:30:00+02:00'),
          monotonicElapsed: const Duration(minutes: 30),
        );

        final utcTime = (await TrustedTimeFixtures.verifiedManifest(
          verifiedServerUtc: DateTime.parse('2026-10-25T01:30:00Z'),
        )).createTrustedTime(timeSource: utcSource);
        final offsetTime = (await TrustedTimeFixtures.verifiedManifest(
          verifiedServerUtc: DateTime.parse('2026-10-25T03:30:00+02:00'),
        )).createTrustedTime(timeSource: offsetSource);

        expect(offsetTime.persistedSnapshot, utcTime.persistedSnapshot);
        expect(offsetTime.read(), utcTime.read());
      },
    );

    test('snapshot round-trip preserves every field exactly', () async {
      final original = await TrustedTimeFixtures.snapshot(
        verifiedServerUtc: DateTime.utc(2026, 7, 1, 9),
        wallClockUtc: DateTime.utc(2026, 7, 1, 9, 2),
        monotonicElapsed: const Duration(hours: 7),
      );

      final decoded = DwTrustedTimeSnapshot.decodePersisted(
        jsonDecode(jsonEncode(original.toPersistedMap())),
      );

      expect(decoded, original);
    });

    test('invalid persisted dates and impossible maxima fail closed', () async {
      final validMap = (await TrustedTimeFixtures.snapshot(
        verifiedServerUtc: DateTime.utc(2026, 7, 1, 9),
        wallClockUtc: DateTime.utc(2026, 7, 1, 9, 2),
      )).toPersistedMap();
      final invalidMaps = <Map<String, Object?>>[
        {...validMap, 'verifiedServerUtcEpochUs': 'invalid'},
        {...validMap, 'monotonicAnchorMicroseconds': -1},
        {
          ...validMap,
          'maxVerifiedServerUtcEpochUs':
              (validMap['verifiedServerUtcEpochUs']! as int) - 1,
        },
        {
          ...validMap,
          'maxWallClockUtcSeenEpochUs':
              (validMap['wallClockUtcAtValidationEpochUs']! as int) - 1,
        },
        {
          ...validMap,
          'trustedUtcWatermarkEpochUs':
              (validMap['maxVerifiedServerUtcEpochUs']! as int) - 1,
        },
        {
          ...validMap,
          'trustedUtcWatermarkEpochUs':
              (validMap['maxWallClockUtcSeenEpochUs']! as int) - 1,
        },
      ];

      for (final invalidMap in invalidMaps) {
        final restored = DwTrustedTime.fromPersistedSnapshot(
          persistedSnapshot: invalidMap,
          timeSource: MutableTrustedTimeSource(
            wallClockUtcNow: DateTime.utc(2026, 7, 1, 9, 2),
            monotonicElapsed: Duration.zero,
          ),
        );

        expect(restored.read().status, DwTrustedTimeStatus.corrupt);
      }
    });
  });

  group('DwTrustedTime binding and checked arithmetic', () {
    test('policy rejects every trusted-clock lease binding mismatch', () async {
      final baseManifest = await TrustedTimeFixtures.verifiedManifest();
      final acceptedRecord = baseManifest.acceptedLeaseRecord;
      final mismatchedManifests = <DwVerifiedOfflineManifest>[
        await TrustedTimeFixtures.verifiedManifest(userScopeId: 'scope-b'),
        await TrustedTimeFixtures.verifiedManifest(leaseId: 'lease-b'),
        await TrustedTimeFixtures.verifiedManifest(recordVersion: 2),
        await TrustedTimeFixtures.verifiedManifest(
          manifestRevision: 'different-payload',
        ),
      ];

      for (final mismatchedManifest in mismatchedManifests) {
        final trustedReading = mismatchedManifest
            .createTrustedTime(
              timeSource: MutableTrustedTimeSource(
                wallClockUtcNow: DateTime.utc(2026, 1, 10, 12),
                monotonicElapsed: Duration.zero,
              ),
            )
            .read();

        expect(
          DwOfflineLeasePolicy.evaluate(
            leaseRecord: acceptedRecord,
            trustedTime: trustedReading,
          ).decision,
          DwOfflineLeaseDecision.corrupt,
        );
      }
    });

    test(
      'snapshot preserves positive microseconds and negative epoch exactly',
      () async {
        final positiveManifest = await TrustedTimeFixtures.verifiedManifest(
          verifiedServerUtc: DateTime.utc(2026, 7, 1, 9, 0, 0, 123, 456),
        );
        final negativeManifest = await TrustedTimeFixtures.verifiedManifest(
          leaseId: 'negative-lease',
          verifiedServerUtc: DateTime.fromMicrosecondsSinceEpoch(
            -1234567,
            isUtc: true,
          ),
        );

        for (final verifiedManifest in [positiveManifest, negativeManifest]) {
          final verifiedServerUtc =
              verifiedManifest.acceptedLeaseRecord.lease!.verifiedServerUtc;
          final source = MutableTrustedTimeSource(
            wallClockUtcNow: verifiedServerUtc,
            monotonicElapsed: const Duration(microseconds: 7),
          );
          final snapshot = verifiedManifest
              .createTrustedTime(timeSource: source)
              .persistedSnapshot;
          final decoded = DwTrustedTimeSnapshot.decodePersisted(
            jsonDecode(jsonEncode(snapshot.toPersistedMap())),
          );

          expect(decoded, snapshot);
          expect(
            decoded!.verifiedServerUtc.microsecondsSinceEpoch,
            verifiedServerUtc.microsecondsSinceEpoch,
          );
        }
      },
    );

    test('old millisecond snapshots fail closed', () {
      final oldInstantMilliseconds = DateTime.utc(
        2026,
        7,
        1,
      ).millisecondsSinceEpoch;
      final oldSnapshot = <String, Object?>{
        'userScopeId': 'scope-a',
        'leaseId': 'lease-a',
        'recordVersion': 1,
        'payloadDigest': 'digest-v1',
        'verifiedServerUtcEpochMs': oldInstantMilliseconds,
        'wallClockUtcAtValidationEpochMs': oldInstantMilliseconds,
        'monotonicAnchorMicroseconds': 0,
        'maxVerifiedServerUtcEpochMs': oldInstantMilliseconds,
        'maxWallClockUtcSeenEpochMs': oldInstantMilliseconds,
        'trustedUtcWatermarkEpochMs': oldInstantMilliseconds,
      };
      expect(DwTrustedTimeSnapshot.decodePersisted(oldSnapshot), isNull);
    });
  });
}

class MutableTrustedTimeSource implements DwTrustedTimeSource {
  MutableTrustedTimeSource({
    required this.wallClockUtcNow,
    required this.monotonicElapsed,
  });

  @override
  DateTime wallClockUtcNow;

  @override
  Duration monotonicElapsed;
}

class TrustedTimeFixtures {
  static late TestSignedManifestFixture manifestFixture;

  static Future<DwVerifiedOfflineManifest> verifiedManifest({
    String userScopeId = 'scope-a',
    String leaseId = 'lease-a',
    int recordVersion = 1,
    String manifestRevision = 'manifest-1',
    DateTime? verifiedServerUtc,
    DateTime? validUntilUtc,
  }) {
    return manifestFixture.verify(
      userScopeId: userScopeId,
      leaseId: leaseId,
      leaseRecordVersion: recordVersion,
      manifestRevision: manifestRevision,
      verifiedServerUtc: verifiedServerUtc ?? DateTime.utc(2026, 1, 10, 12),
      leaseValidUntilUtc: validUntilUtc ?? DateTime.utc(2027),
    );
  }

  static Future<DwTrustedTimeSnapshot> snapshot({
    required DateTime verifiedServerUtc,
    required DateTime wallClockUtc,
    Duration monotonicElapsed = Duration.zero,
  }) async {
    final source = MutableTrustedTimeSource(
      wallClockUtcNow: wallClockUtc,
      monotonicElapsed: monotonicElapsed,
    );
    return (await verifiedManifest(
      verifiedServerUtc: verifiedServerUtc,
    )).createTrustedTime(timeSource: source).persistedSnapshot;
  }
}
