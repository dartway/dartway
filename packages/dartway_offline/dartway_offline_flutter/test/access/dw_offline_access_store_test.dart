import 'dart:convert';

import 'package:dartway_offline_flutter/src/access/dw_offline_access_store.dart';
import 'package:dartway_offline_flutter/src/access/dw_offline_lease_policy.dart';
import 'package:dartway_offline_flutter/src/storage/dw_offline_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/signed_manifest_fixture.dart';

void main() {
  late DwOfflineDatabase database;
  late TestSignedManifestFixture manifestFixture;
  late _TimeSource timeSource;
  late DwOfflineAccessStore accessStore;

  setUp(() async {
    database = DwOfflineDatabase(NativeDatabase.memory());
    manifestFixture = await TestSignedManifestFixture.create();
    timeSource = _TimeSource(
      wallClockUtcNow: DateTime.utc(2026),
      monotonicElapsed: Duration.zero,
    );
    accessStore = DwOfflineAccessStore(
      database: database,
      manifestVerifier: manifestFixture.createVerifier(),
      expectedAudience: 'mobile',
      timeSource: timeSource,
    );
  });

  tearDown(() => database.close());

  test('serves an active package while its verified lease is usable', () async {
    final manifest = await manifestFixture.verify(assets: const []);
    await database.beginStagingManifest(manifest);
    await database.activateStagingManifest(
      userScopeId: 'scope-a',
      packageId: 'package-a',
      manifestRevision: 'manifest-1',
      payloadDigest: manifest.payloadDigest,
    );

    await accessStore.persistVerifiedManifestLease(manifest);

    expect(
      await accessStore.canReadPackage(
        userScopeId: 'scope-a',
        packageId: 'package-a',
        manifestRevision: 'manifest-1',
      ),
      isTrue,
    );
  });

  test('locks a bounded package at its signed validity boundary', () async {
    final manifest = await manifestFixture.verify(
      assets: const [],
      verifiedServerUtc: DateTime.utc(2026),
      leaseValidUntilUtc: DateTime.utc(2026, 1, 31),
    );
    await database.beginStagingManifest(manifest);
    await database.activateStagingManifest(
      userScopeId: 'scope-a',
      packageId: 'package-a',
      manifestRevision: 'manifest-1',
      payloadDigest: manifest.payloadDigest,
    );
    await accessStore.persistVerifiedManifestLease(manifest);
    timeSource
      ..wallClockUtcNow = DateTime.utc(2026, 2, 1)
      ..monotonicElapsed = const Duration(days: 31);

    expect(
      await accessStore.canReadPackage(
        userScopeId: 'scope-a',
        packageId: 'package-a',
        manifestRevision: 'manifest-1',
      ),
      isFalse,
    );
  });

  test('does not authorize a different package or revision', () async {
    final manifest = await manifestFixture.verify(assets: const []);
    await accessStore.persistVerifiedManifestLease(manifest);

    expect(
      await accessStore.canReadPackage(
        userScopeId: 'scope-a',
        packageId: 'package-b',
        manifestRevision: 'manifest-1',
      ),
      isFalse,
    );
  });

  test('lease lookup treats SQL wildcard characters as literal text', () async {
    final candidate = await manifestFixture.verify(
      assets: const [],
      leaseId: 'lease%',
    );
    final lease = candidate.acceptedLeaseRecord.lease!;
    await database
        .into(database.dwOfflineLeases)
        .insert(
          DwOfflineLeasesCompanion.insert(
            userScopeId: lease.userScopeId,
            leaseId: 'lease-other:${lease.payloadDigest}',
            leaseEnvelopeJson: jsonEncode(<String, Object?>{
              'schemaVersion': 1,
              'lease': lease.toPersistedMap(),
              'trustedTime': const <String, Object?>{},
              'signedManifestEnvelopeJson': candidate.canonicalEnvelopeJson,
            }),
            trustedAtEpochMs: 0,
            expiresAtEpochMs: 0x7fffffffffffffff,
          ),
        );

    final previous = await accessStore.loadPreviousLeaseRecord(candidate);

    expect(previous.lease, isNull);
  });
}

final class _TimeSource implements DwTrustedTimeSource {
  _TimeSource({required this.wallClockUtcNow, required this.monotonicElapsed});

  @override
  DateTime wallClockUtcNow;

  @override
  Duration monotonicElapsed;
}
