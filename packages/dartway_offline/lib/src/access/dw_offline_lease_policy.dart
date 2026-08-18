import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:cryptography/cryptography.dart';

part 'dw_offline_lease.dart';
part 'dw_offline_lease_acceptance.dart';
part 'dw_trusted_time.dart';
part 'dw_trusted_time_snapshot.dart';
part '../manifest/dw_offline_asset_descriptor.dart';
part '../manifest/dw_offline_manifest.dart';
part '../manifest/dw_offline_manifest_verifier.dart';

const int _minimumUtcEpochMicroseconds = -8640000000000000000;
const int _maximumUtcEpochMicroseconds = 8640000000000000000;

final class _CheckedUtcArithmetic {
  const _CheckedUtcArithmetic._();

  static DateTime? add(DateTime utcInstant, Duration duration) {
    final utcEpochMicroseconds = utcInstant.toUtc().microsecondsSinceEpoch;
    final durationMicroseconds = duration.inMicroseconds;
    if (durationMicroseconds > 0 &&
        utcEpochMicroseconds >
            _maximumUtcEpochMicroseconds - durationMicroseconds) {
      return null;
    }
    if (durationMicroseconds < 0 &&
        utcEpochMicroseconds <
            _minimumUtcEpochMicroseconds - durationMicroseconds) {
      return null;
    }
    return DateTime.fromMicrosecondsSinceEpoch(
      utcEpochMicroseconds + durationMicroseconds,
      isUtc: true,
    );
  }
}

enum DwOfflineLeaseDecision {
  usable,
  needsOnlineValidation,
  expired,
  revoked,
  corrupt,
}

final class DwOfflineLeaseEvaluation {
  const DwOfflineLeaseEvaluation({
    required this.decision,
    this.requiresOnlineValidation = false,
  });

  final DwOfflineLeaseDecision decision;
  final bool requiresOnlineValidation;
}

final class DwOfflineLeasePolicy {
  const DwOfflineLeasePolicy._();

  static DwOfflineLeaseEvaluation evaluate({
    required DwOfflineLeaseRecord leaseRecord,
    required DwTrustedTimeReading trustedTime,
    bool connectivityAvailable = false,
  }) {
    if (leaseRecord.status == DwOfflineLeaseRecordStatus.corrupt ||
        trustedTime.status == DwTrustedTimeStatus.corrupt) {
      return const DwOfflineLeaseEvaluation(
        decision: DwOfflineLeaseDecision.corrupt,
      );
    }
    if (leaseRecord.status == DwOfflineLeaseRecordStatus.missing) {
      return const DwOfflineLeaseEvaluation(
        decision: DwOfflineLeaseDecision.needsOnlineValidation,
      );
    }
    final acceptedLease = leaseRecord.lease!;
    if (trustedTime.binding != acceptedLease.binding) {
      return const DwOfflineLeaseEvaluation(
        decision: DwOfflineLeaseDecision.corrupt,
      );
    }
    if (acceptedLease.isRevoked) {
      return const DwOfflineLeaseEvaluation(
        decision: DwOfflineLeaseDecision.revoked,
      );
    }
    if (acceptedLease.validUntilUtc == null) {
      return DwOfflineLeaseEvaluation(
        decision: DwOfflineLeaseDecision.usable,
        requiresOnlineValidation: connectivityAvailable,
      );
    }
    if (trustedTime.status == DwTrustedTimeStatus.needsOnlineValidation) {
      return const DwOfflineLeaseEvaluation(
        decision: DwOfflineLeaseDecision.needsOnlineValidation,
      );
    }
    if (!trustedTime.trustedNowUtc!.isBefore(acceptedLease.validUntilUtc!)) {
      return const DwOfflineLeaseEvaluation(
        decision: DwOfflineLeaseDecision.expired,
      );
    }
    return const DwOfflineLeaseEvaluation(
      decision: DwOfflineLeaseDecision.usable,
    );
  }
}
