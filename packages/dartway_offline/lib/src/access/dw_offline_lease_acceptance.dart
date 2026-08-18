part of 'dw_offline_lease_policy.dart';

enum DwPersistedOfflineLeaseStatus { missing, decoded, corrupt }

final class DwPersistedOfflineLeaseClaims {
  const DwPersistedOfflineLeaseClaims._({required this.lease});

  final DwOfflineLease lease;

  @override
  bool operator ==(Object other) {
    return other is DwPersistedOfflineLeaseClaims && other.lease == lease;
  }

  @override
  int get hashCode => lease.hashCode;
}

/// Raw persisted decoding never grants access; signed reverification is
/// required before decoded claims can become an accepted record.
final class DwPersistedOfflineLease {
  const DwPersistedOfflineLease._({required this.status, this.claims});

  static const int schemaVersion = 2;
  static const String timestampEncoding = 'epochMicrosecondsUtc';

  final DwPersistedOfflineLeaseStatus status;
  final DwPersistedOfflineLeaseClaims? claims;

  static DwPersistedOfflineLease decode(Object? persistedLease) {
    if (persistedLease == null) {
      return const DwPersistedOfflineLease._(
        status: DwPersistedOfflineLeaseStatus.missing,
      );
    }
    if (persistedLease is! Map<String, Object?> ||
        persistedLease['schemaVersion'] != schemaVersion ||
        persistedLease['timestampEncoding'] != timestampEncoding) {
      return const DwPersistedOfflineLease._(
        status: DwPersistedOfflineLeaseStatus.corrupt,
      );
    }
    final binding = _decodeBinding(persistedLease);
    final verifiedServerUtc = _decodeRequiredEpochMicroseconds(
      persistedLease['verifiedServerUtcEpochUs'],
    );
    final persistedValidUntilUtc = _decodeNullableEpochMicroseconds(
      persistedLease['validUntilUtcEpochUs'],
    );
    final isRevoked = persistedLease['isRevoked'];
    if (binding == null ||
        verifiedServerUtc == null ||
        persistedValidUntilUtc.isInvalid ||
        isRevoked is! bool) {
      return const DwPersistedOfflineLease._(
        status: DwPersistedOfflineLeaseStatus.corrupt,
      );
    }
    final structuralLease = DwOfflineLease._fromClaimsOrNull(
      binding: binding,
      verifiedServerUtc: verifiedServerUtc,
      validUntilUtc: persistedValidUntilUtc.value,
      isRevoked: isRevoked,
    );
    if (structuralLease == null) {
      return const DwPersistedOfflineLease._(
        status: DwPersistedOfflineLeaseStatus.corrupt,
      );
    }
    return DwPersistedOfflineLease._(
      status: DwPersistedOfflineLeaseStatus.decoded,
      claims: DwPersistedOfflineLeaseClaims._(lease: structuralLease),
    );
  }

  static DwOfflineLeaseBinding? _decodeBinding(
    Map<String, Object?> persistedLease,
  ) {
    final userScopeId = persistedLease['userScopeId'];
    final leaseId = persistedLease['leaseId'];
    final recordVersion = persistedLease['recordVersion'];
    final payloadDigest = persistedLease['payloadDigest'];
    if (userScopeId is! String ||
        leaseId is! String ||
        recordVersion is! int ||
        payloadDigest is! String) {
      return null;
    }
    final normalizedUserScopeId = DwOfflineLeaseBinding._normalizedText(
      userScopeId,
    );
    final normalizedLeaseId = DwOfflineLeaseBinding._normalizedText(leaseId);
    final normalizedPayloadDigest = DwOfflineLeaseBinding._normalizedText(
      payloadDigest,
    );
    if (normalizedUserScopeId == null ||
        normalizedLeaseId == null ||
        recordVersion <= 0 ||
        normalizedPayloadDigest == null) {
      return null;
    }
    return DwOfflineLeaseBinding._(
      userScopeId: normalizedUserScopeId,
      leaseId: normalizedLeaseId,
      recordVersion: recordVersion,
      payloadDigest: normalizedPayloadDigest,
    );
  }

  static DateTime? _decodeRequiredEpochMicroseconds(Object? epochMicroseconds) {
    if (epochMicroseconds is! int ||
        epochMicroseconds < _minimumUtcEpochMicroseconds ||
        epochMicroseconds > _maximumUtcEpochMicroseconds) {
      return null;
    }
    return DateTime.fromMicrosecondsSinceEpoch(epochMicroseconds, isUtc: true);
  }

  static _DecodedNullableDateTime _decodeNullableEpochMicroseconds(
    Object? epochMicroseconds,
  ) {
    if (epochMicroseconds == null) {
      return const _DecodedNullableDateTime.valid(null);
    }
    final decodedDateTime = _decodeRequiredEpochMicroseconds(epochMicroseconds);
    return decodedDateTime == null
        ? const _DecodedNullableDateTime.invalid()
        : _DecodedNullableDateTime.valid(decodedDateTime);
  }
}

enum DwOfflineLeaseRecordStatus { missing, accepted, corrupt }

final class DwOfflineLeaseRecord {
  const DwOfflineLeaseRecord.missing()
    : status = DwOfflineLeaseRecordStatus.missing,
      lease = null;

  const DwOfflineLeaseRecord.corrupt()
    : status = DwOfflineLeaseRecordStatus.corrupt,
      lease = null;

  const DwOfflineLeaseRecord._accepted(DwOfflineLease acceptedLease)
    : status = DwOfflineLeaseRecordStatus.accepted,
      lease = acceptedLease;

  final DwOfflineLeaseRecordStatus status;
  final DwOfflineLease? lease;
}

enum DwOfflineLeaseAcceptanceStatus {
  accepted,
  idempotent,
  replayRejected,
  corrupt,
}

final class DwOfflineLeaseAcceptanceResult {
  const DwOfflineLeaseAcceptanceResult._({required this.status, this.record});

  final DwOfflineLeaseAcceptanceStatus status;
  final DwOfflineLeaseRecord? record;
}

final class DwOfflineLeaseAcceptance {
  const DwOfflineLeaseAcceptance._();

  static DwOfflineLeaseAcceptanceResult acceptVerified({
    required DwVerifiedOfflineLeaseInput verifiedInput,
    DwOfflineLeaseRecord previousRecord = const DwOfflineLeaseRecord.missing(),
  }) {
    final candidateLease = DwOfflineLease._fromVerifiedInputOrNull(
      verifiedInput,
    );
    if (candidateLease == null) {
      return const DwOfflineLeaseAcceptanceResult._(
        status: DwOfflineLeaseAcceptanceStatus.corrupt,
      );
    }
    return _compareWithPrevious(candidateLease, previousRecord);
  }

  static DwOfflineLeaseAcceptanceResult reverifyPersisted({
    required DwPersistedOfflineLease persistedClaims,
    required DwVerifiedOfflineLeaseInput verifiedInput,
    DwOfflineLeaseRecord previousRecord = const DwOfflineLeaseRecord.missing(),
  }) {
    final reverifiedLease = DwOfflineLease._fromVerifiedInputOrNull(
      verifiedInput,
    );
    if (persistedClaims.status != DwPersistedOfflineLeaseStatus.decoded ||
        reverifiedLease == null ||
        persistedClaims.claims!.lease != reverifiedLease) {
      return const DwOfflineLeaseAcceptanceResult._(
        status: DwOfflineLeaseAcceptanceStatus.corrupt,
      );
    }
    return _compareWithPrevious(reverifiedLease, previousRecord);
  }

  static DwOfflineLeaseAcceptanceResult _compareWithPrevious(
    DwOfflineLease candidateLease,
    DwOfflineLeaseRecord previousRecord,
  ) {
    if (previousRecord.status == DwOfflineLeaseRecordStatus.missing ||
        previousRecord.status == DwOfflineLeaseRecordStatus.corrupt) {
      return DwOfflineLeaseAcceptanceResult._(
        status: DwOfflineLeaseAcceptanceStatus.accepted,
        record: DwOfflineLeaseRecord._accepted(candidateLease),
      );
    }
    final currentLease = previousRecord.lease!;
    if (candidateLease.userScopeId != currentLease.userScopeId ||
        candidateLease.leaseId != currentLease.leaseId) {
      return const DwOfflineLeaseAcceptanceResult._(
        status: DwOfflineLeaseAcceptanceStatus.corrupt,
      );
    }
    if (candidateLease.recordVersion < currentLease.recordVersion) {
      return const DwOfflineLeaseAcceptanceResult._(
        status: DwOfflineLeaseAcceptanceStatus.replayRejected,
      );
    }
    if (candidateLease.recordVersion == currentLease.recordVersion) {
      if (candidateLease != currentLease) {
        return const DwOfflineLeaseAcceptanceResult._(
          status: DwOfflineLeaseAcceptanceStatus.corrupt,
        );
      }
      return DwOfflineLeaseAcceptanceResult._(
        status: DwOfflineLeaseAcceptanceStatus.idempotent,
        record: previousRecord,
      );
    }
    return DwOfflineLeaseAcceptanceResult._(
      status: DwOfflineLeaseAcceptanceStatus.accepted,
      record: DwOfflineLeaseRecord._accepted(candidateLease),
    );
  }
}

final class _DecodedNullableDateTime {
  const _DecodedNullableDateTime.valid(this.value) : isInvalid = false;
  const _DecodedNullableDateTime.invalid() : value = null, isInvalid = true;

  final DateTime? value;
  final bool isInvalid;
}
