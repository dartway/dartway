part of 'dw_offline_lease_policy.dart';

final class DwTrustedTimeSnapshot {
  const DwTrustedTimeSnapshot._({
    required this.binding,
    required this.verifiedServerUtc,
    required this.wallClockUtcAtValidation,
    required this.monotonicAnchor,
    required this.maxVerifiedServerUtc,
    required this.maxWallClockUtcSeen,
    required this.trustedUtcWatermark,
  });

  static const int schemaVersion = 1;
  static const String timestampEncoding = 'epochMicrosecondsUtc';

  final DwOfflineLeaseBinding binding;
  final DateTime verifiedServerUtc;
  final DateTime wallClockUtcAtValidation;
  final Duration monotonicAnchor;
  final DateTime maxVerifiedServerUtc;
  final DateTime maxWallClockUtcSeen;
  final DateTime trustedUtcWatermark;

  Map<String, Object?> toPersistedMap() {
    return <String, Object?>{
      'schemaVersion': schemaVersion,
      'timestampEncoding': timestampEncoding,
      'userScopeId': binding.userScopeId,
      'leaseId': binding.leaseId,
      'recordVersion': binding.recordVersion,
      'payloadDigest': binding.payloadDigest,
      'verifiedServerUtcEpochUs': verifiedServerUtc.microsecondsSinceEpoch,
      'wallClockUtcAtValidationEpochUs':
          wallClockUtcAtValidation.microsecondsSinceEpoch,
      'monotonicAnchorMicroseconds': monotonicAnchor.inMicroseconds,
      'maxVerifiedServerUtcEpochUs':
          maxVerifiedServerUtc.microsecondsSinceEpoch,
      'maxWallClockUtcSeenEpochUs': maxWallClockUtcSeen.microsecondsSinceEpoch,
      'trustedUtcWatermarkEpochUs': trustedUtcWatermark.microsecondsSinceEpoch,
    };
  }

  static DwTrustedTimeSnapshot? decodePersisted(Object? persistedSnapshot) {
    if (persistedSnapshot is! Map<String, Object?> ||
        persistedSnapshot['schemaVersion'] != schemaVersion ||
        persistedSnapshot['timestampEncoding'] != timestampEncoding) {
      return null;
    }
    final binding = DwPersistedOfflineLease._decodeBinding(persistedSnapshot);
    final verifiedServerUtc =
        DwPersistedOfflineLease._decodeRequiredEpochMicroseconds(
          persistedSnapshot['verifiedServerUtcEpochUs'],
        );
    final wallClockUtcAtValidation =
        DwPersistedOfflineLease._decodeRequiredEpochMicroseconds(
          persistedSnapshot['wallClockUtcAtValidationEpochUs'],
        );
    final monotonicAnchorMicroseconds =
        persistedSnapshot['monotonicAnchorMicroseconds'];
    final maxVerifiedServerUtc =
        DwPersistedOfflineLease._decodeRequiredEpochMicroseconds(
          persistedSnapshot['maxVerifiedServerUtcEpochUs'],
        );
    final maxWallClockUtcSeen =
        DwPersistedOfflineLease._decodeRequiredEpochMicroseconds(
          persistedSnapshot['maxWallClockUtcSeenEpochUs'],
        );
    final trustedUtcWatermark =
        DwPersistedOfflineLease._decodeRequiredEpochMicroseconds(
          persistedSnapshot['trustedUtcWatermarkEpochUs'],
        );
    if (binding == null ||
        verifiedServerUtc == null ||
        wallClockUtcAtValidation == null ||
        monotonicAnchorMicroseconds is! int ||
        monotonicAnchorMicroseconds < 0 ||
        maxVerifiedServerUtc == null ||
        maxWallClockUtcSeen == null ||
        trustedUtcWatermark == null ||
        maxVerifiedServerUtc.isBefore(verifiedServerUtc) ||
        maxWallClockUtcSeen.isBefore(wallClockUtcAtValidation) ||
        trustedUtcWatermark.isBefore(maxVerifiedServerUtc) ||
        trustedUtcWatermark.isBefore(maxWallClockUtcSeen)) {
      return null;
    }
    return DwTrustedTimeSnapshot._(
      binding: binding,
      verifiedServerUtc: verifiedServerUtc,
      wallClockUtcAtValidation: wallClockUtcAtValidation,
      monotonicAnchor: Duration(microseconds: monotonicAnchorMicroseconds),
      maxVerifiedServerUtc: maxVerifiedServerUtc,
      maxWallClockUtcSeen: maxWallClockUtcSeen,
      trustedUtcWatermark: trustedUtcWatermark,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is DwTrustedTimeSnapshot &&
        other.binding == binding &&
        other.verifiedServerUtc == verifiedServerUtc &&
        other.wallClockUtcAtValidation == wallClockUtcAtValidation &&
        other.monotonicAnchor == monotonicAnchor &&
        other.maxVerifiedServerUtc == maxVerifiedServerUtc &&
        other.maxWallClockUtcSeen == maxWallClockUtcSeen &&
        other.trustedUtcWatermark == trustedUtcWatermark;
  }

  @override
  int get hashCode => Object.hash(
    binding,
    verifiedServerUtc,
    wallClockUtcAtValidation,
    monotonicAnchor,
    maxVerifiedServerUtc,
    maxWallClockUtcSeen,
    trustedUtcWatermark,
  );
}
