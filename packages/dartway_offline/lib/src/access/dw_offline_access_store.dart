import 'dart:convert';

import 'package:drift/drift.dart';

import '../repository/dw_offline_read_delegate.dart';
import '../storage/dw_offline_database.dart';
import 'dw_offline_lease_policy.dart';

/// Persists verified lease/time capabilities and authorizes active packages.
final class DwOfflineAccessStore implements DwOfflineRepositoryReadPolicy {
  DwOfflineAccessStore({
    required DwOfflineDatabase database,
    required DwOfflineManifestVerifier manifestVerifier,
    required String expectedAudience,
    required DwTrustedTimeSource timeSource,
  }) : _database = database,
       _manifestVerifier = manifestVerifier,
       _expectedAudience = expectedAudience,
       _timeSource = timeSource {
    if (expectedAudience.trim().isEmpty ||
        expectedAudience != expectedAudience.trim()) {
      throw ArgumentError.value(expectedAudience, 'expectedAudience');
    }
  }

  static const int _recordSchemaVersion = 1;

  final DwOfflineDatabase _database;
  final DwOfflineManifestVerifier _manifestVerifier;
  final String _expectedAudience;
  final DwTrustedTimeSource _timeSource;

  Future<void> persistVerifiedManifestLease(
    DwVerifiedOfflineManifest verifiedManifest,
  ) async {
    final lease = verifiedManifest.acceptedLeaseRecord.lease!;
    final storageLeaseId = _leaseStorageKey(lease);
    final existingRow =
        await (_database.select(_database.dwOfflineLeases)..where(
              (row) =>
                  row.userScopeId.equals(lease.userScopeId) &
                  row.leaseId.equals(storageLeaseId),
            ))
            .getSingleOrNull();
    final existingRecord = _decodeRecord(existingRow?.leaseEnvelopeJson);
    final decodedPreviousSnapshot = DwTrustedTimeSnapshot.decodePersisted(
      existingRecord?['trustedTime'],
    );
    final trustedTime = verifiedManifest.createTrustedTime(
      timeSource: _timeSource,
      previousSnapshot: decodedPreviousSnapshot?.binding == lease.binding
          ? decodedPreviousSnapshot
          : null,
    );
    final reading = trustedTime.read();
    if (reading.status != DwTrustedTimeStatus.trusted) {
      throw StateError('Verified manifest did not create trusted time.');
    }
    final nowEpochMs = _timeSource.wallClockUtcNow
        .toUtc()
        .millisecondsSinceEpoch;
    await _database
        .into(_database.dwOfflineLeases)
        .insertOnConflictUpdate(
          DwOfflineLeasesCompanion.insert(
            userScopeId: lease.userScopeId,
            leaseId: storageLeaseId,
            leaseEnvelopeJson: _encodeRecord(
              lease: lease.toPersistedMap(),
              trustedTime: trustedTime.persistedSnapshot.toPersistedMap(),
              signedManifestEnvelopeJson:
                  verifiedManifest.canonicalEnvelopeJson,
            ),
            trustedAtEpochMs: nowEpochMs,
            expiresAtEpochMs:
                lease.validUntilUtc?.millisecondsSinceEpoch ??
                0x7fffffffffffffff,
          ),
        );
  }

  Future<DwOfflineLeaseRecord> loadPreviousLeaseRecord(
    DwVerifiedOfflineManifest candidate,
  ) async {
    final candidateLease = candidate.acceptedLeaseRecord.lease!;
    final escapedLeaseId = _escapeLikePattern(candidateLease.leaseId);
    final rows =
        await (_database.select(_database.dwOfflineLeases)..where(
              (row) =>
                  row.userScopeId.equals(candidateLease.userScopeId) &
                  row.leaseId.like('$escapedLeaseId:%', escapeChar: '\\'),
            ))
            .get();
    DwOfflineLeaseRecord previous = const DwOfflineLeaseRecord.missing();
    for (final row in rows) {
      final storedRecord = _decodeRecord(row.leaseEnvelopeJson);
      final envelopeJson = storedRecord?['signedManifestEnvelopeJson'];
      final persistedLeaseValue = storedRecord?['lease'];
      if (envelopeJson is! String || persistedLeaseValue is! Map) continue;
      final verification = await _manifestVerifier.verify(
        envelopeJson: envelopeJson,
        expectedAudience: _expectedAudience,
        expectedUserScopeId: candidate.manifest.userScopeId,
        expectedPackageId: candidate.manifest.packageId,
      );
      final storedManifest = verification.verifiedManifest;
      if (storedManifest == null) continue;
      final persistedLease = DwPersistedOfflineLease.decode(
        Map<String, Object?>.from(persistedLeaseValue),
      );
      final acceptance = storedManifest.reverifyPersistedLease(
        persistedClaims: persistedLease,
      );
      final storedLease = acceptance.record?.lease;
      if (storedLease == null ||
          storedLease.leaseId != candidateLease.leaseId) {
        continue;
      }
      final currentLease = previous.lease;
      if (currentLease == null ||
          storedLease.recordVersion > currentLease.recordVersion) {
        previous = acceptance.record!;
      } else if (storedLease.recordVersion == currentLease.recordVersion &&
          storedLease != currentLease) {
        throw StateError('Persisted lease history is inconsistent.');
      }
    }
    return previous;
  }

  @override
  Future<bool> canReadPackage({
    required String userScopeId,
    required String packageId,
    required String manifestRevision,
  }) async =>
      await authorizedRepositoryContentDigest(
        userScopeId: userScopeId,
        packageId: packageId,
        manifestRevision: manifestRevision,
      ) !=
      null;

  @override
  Future<String?> authorizedRepositoryContentDigest({
    required String userScopeId,
    required String packageId,
    required String manifestRevision,
  }) async {
    final packageRow =
        await (_database.select(_database.dwOfflinePackages)..where(
              (row) =>
                  row.userScopeId.equals(userScopeId) &
                  row.packageId.equals(packageId) &
                  row.activeManifestRevision.equals(manifestRevision),
            ))
            .getSingleOrNull();
    if (packageRow == null) return null;
    final manifestRow =
        await (_database.select(_database.dwOfflineManifests)..where(
              (row) =>
                  row.userScopeId.equals(userScopeId) &
                  row.packageId.equals(packageId) &
                  row.manifestRevision.equals(manifestRevision),
            ))
            .getSingleOrNull();
    if (manifestRow == null) return null;
    final verification = await _manifestVerifier.verify(
      envelopeJson: manifestRow.envelopeJson,
      expectedAudience: _expectedAudience,
      expectedUserScopeId: userScopeId,
      expectedPackageId: packageId,
    );
    final verifiedManifest = verification.verifiedManifest;
    if (verifiedManifest == null ||
        verifiedManifest.manifest.manifestRevision != manifestRevision ||
        verifiedManifest.payloadDigest != manifestRow.payloadDigest) {
      return null;
    }
    final lease = verifiedManifest.acceptedLeaseRecord.lease!;
    final leaseRow =
        await (_database.select(_database.dwOfflineLeases)..where(
              (row) =>
                  row.userScopeId.equals(userScopeId) &
                  row.leaseId.equals(_leaseStorageKey(lease)),
            ))
            .getSingleOrNull();
    final record = _decodeRecord(leaseRow?.leaseEnvelopeJson);
    if (leaseRow == null || record == null) return null;
    final persistedLeaseValue = record['lease'];
    if (persistedLeaseValue is! Map) return null;
    final persistedLease = DwPersistedOfflineLease.decode(
      Map<String, Object?>.from(persistedLeaseValue),
    );
    final acceptance = verifiedManifest.reverifyPersistedLease(
      persistedClaims: persistedLease,
    );
    final acceptedRecord = acceptance.record;
    if (acceptedRecord == null) return null;
    final trustedTime = DwTrustedTime.fromPersistedSnapshot(
      persistedSnapshot: record['trustedTime'],
      timeSource: _timeSource,
    );
    final evaluation = DwOfflineLeasePolicy.evaluate(
      leaseRecord: acceptedRecord,
      trustedTime: trustedTime.read(),
    );
    if (evaluation.decision != DwOfflineLeaseDecision.usable) return null;
    await (_database.update(_database.dwOfflineLeases)..where(
          (row) =>
              row.userScopeId.equals(userScopeId) &
              row.leaseId.equals(leaseRow.leaseId),
        ))
        .write(
          DwOfflineLeasesCompanion(
            leaseEnvelopeJson: Value(
              _encodeRecord(
                lease: Map<String, Object?>.from(persistedLeaseValue),
                trustedTime: trustedTime.persistedSnapshot.toPersistedMap(),
                signedManifestEnvelopeJson:
                    record['signedManifestEnvelopeJson'] as String?,
              ),
            ),
            trustedAtEpochMs: Value(
              _timeSource.wallClockUtcNow.toUtc().millisecondsSinceEpoch,
            ),
          ),
        );
    return verifiedManifest.manifest.repositoryContentDigest;
  }

  static String _leaseStorageKey(DwOfflineLease lease) =>
      '${lease.leaseId}:${lease.payloadDigest}';

  static String _escapeLikePattern(String value) => value
      .replaceAll('\\', '\\\\')
      .replaceAll('%', '\\%')
      .replaceAll('_', '\\_');

  static String _encodeRecord({
    required Map<String, Object?> lease,
    required Map<String, Object?> trustedTime,
    required String? signedManifestEnvelopeJson,
  }) => jsonEncode(<String, Object?>{
    'schemaVersion': _recordSchemaVersion,
    'lease': lease,
    'trustedTime': trustedTime,
    'signedManifestEnvelopeJson': ?signedManifestEnvelopeJson,
  });

  static Map<String, Object?>? _decodeRecord(String? encodedRecord) {
    if (encodedRecord == null) return null;
    try {
      final decoded = jsonDecode(encodedRecord);
      if (decoded is! Map || decoded['schemaVersion'] != _recordSchemaVersion) {
        return null;
      }
      return Map<String, Object?>.from(decoded);
    } on Object {
      return null;
    }
  }
}
