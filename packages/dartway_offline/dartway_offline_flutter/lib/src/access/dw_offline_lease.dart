part of 'dw_offline_lease_policy.dart';

final class DwOfflineLeaseBinding {
  const DwOfflineLeaseBinding._({
    required this.userScopeId,
    required this.leaseId,
    required this.recordVersion,
    required this.payloadDigest,
  });

  final String userScopeId;
  final String leaseId;
  final int recordVersion;
  final String payloadDigest;

  static String? _normalizedText(String value) {
    final trimmedValue = value.trim();
    return trimmedValue.isEmpty ? null : trimmedValue;
  }

  @override
  bool operator ==(Object other) {
    return other is DwOfflineLeaseBinding &&
        other.userScopeId == userScopeId &&
        other.leaseId == leaseId &&
        other.recordVersion == recordVersion &&
        other.payloadDigest == payloadDigest;
  }

  @override
  int get hashCode =>
      Object.hash(userScopeId, leaseId, recordVersion, payloadDigest);
}

/// Internal capability created only after manifest signature verification.
final class DwVerifiedOfflineLeaseInput {
  DwVerifiedOfflineLeaseInput._({
    required this.userScopeId,
    required this.leaseId,
    required this.recordVersion,
    required this.payloadDigest,
    required this.verifiedServerUtc,
    required this.validUntilUtc,
    required this.isRevoked,
  });

  final String userScopeId;
  final String leaseId;
  final int recordVersion;
  final String payloadDigest;
  final DateTime verifiedServerUtc;
  final DateTime? validUntilUtc;
  final bool isRevoked;

  DwOfflineLeaseBinding? get binding {
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
}

/// Immutable fields from one verified and accepted server lease envelope.
final class DwOfflineLease {
  const DwOfflineLease._({
    required this.binding,
    required this.verifiedServerUtc,
    required this.validUntilUtc,
    required this.isRevoked,
  });

  factory DwOfflineLease.fromVerifiedInput(
    DwVerifiedOfflineLeaseInput verifiedInput,
  ) {
    final acceptedLease = _fromVerifiedInputOrNull(verifiedInput);
    if (acceptedLease == null) {
      throw ArgumentError.value(
        verifiedInput,
        'verifiedInput',
        'contains invalid or unrepresentable lease claims.',
      );
    }
    return acceptedLease;
  }

  final DwOfflineLeaseBinding binding;
  final DateTime verifiedServerUtc;
  final DateTime? validUntilUtc;
  final bool isRevoked;

  String get userScopeId => binding.userScopeId;
  String get leaseId => binding.leaseId;
  int get recordVersion => binding.recordVersion;
  String get payloadDigest => binding.payloadDigest;

  Map<String, Object?> toPersistedMap() {
    return <String, Object?>{
      'schemaVersion': DwPersistedOfflineLease.schemaVersion,
      'timestampEncoding': DwPersistedOfflineLease.timestampEncoding,
      'userScopeId': userScopeId,
      'leaseId': leaseId,
      'recordVersion': recordVersion,
      'payloadDigest': payloadDigest,
      'verifiedServerUtcEpochUs': verifiedServerUtc.microsecondsSinceEpoch,
      'validUntilUtcEpochUs': validUntilUtc?.microsecondsSinceEpoch,
      'isRevoked': isRevoked,
    };
  }

  static DwOfflineLease? _fromVerifiedInputOrNull(
    DwVerifiedOfflineLeaseInput verifiedInput,
  ) {
    final binding = verifiedInput.binding;
    if (binding == null) {
      return null;
    }
    return _fromClaimsOrNull(
      binding: binding,
      verifiedServerUtc: verifiedInput.verifiedServerUtc.toUtc(),
      validUntilUtc: verifiedInput.validUntilUtc?.toUtc(),
      isRevoked: verifiedInput.isRevoked,
    );
  }

  static DwOfflineLease? _fromClaimsOrNull({
    required DwOfflineLeaseBinding binding,
    required DateTime verifiedServerUtc,
    required DateTime? validUntilUtc,
    required bool isRevoked,
  }) {
    return DwOfflineLease._(
      binding: binding,
      verifiedServerUtc: verifiedServerUtc,
      validUntilUtc: validUntilUtc,
      isRevoked: isRevoked,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is DwOfflineLease &&
        other.binding == binding &&
        other.verifiedServerUtc == verifiedServerUtc &&
        other.validUntilUtc == validUntilUtc &&
        other.isRevoked == isRevoked;
  }

  @override
  int get hashCode =>
      Object.hash(binding, verifiedServerUtc, validUntilUtc, isRevoked);
}
