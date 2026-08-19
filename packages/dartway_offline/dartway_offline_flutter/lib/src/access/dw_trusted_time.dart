part of 'dw_offline_lease_policy.dart';

abstract interface class DwTrustedTimeSource {
  DateTime get wallClockUtcNow;
  Duration get monotonicElapsed;
}

/// Time capability derived from the same verified lease envelope as access.
final class DwVerifiedTimeInput {
  DwVerifiedTimeInput._({required DwVerifiedOfflineLeaseInput leaseInput})
    : binding = leaseInput.binding,
      verifiedServerUtc = leaseInput.verifiedServerUtc.toUtc();

  final DwOfflineLeaseBinding? binding;
  final DateTime verifiedServerUtc;
}

enum DwTrustedTimeStatus { trusted, needsOnlineValidation, corrupt }

final class DwTrustedTimeReading {
  DwTrustedTimeReading._trusted({
    required this.binding,
    required DateTime trustedNowUtc,
  }) : status = DwTrustedTimeStatus.trusted,
       trustedNowUtc = trustedNowUtc.toUtc();

  const DwTrustedTimeReading._needsOnlineValidation({required this.binding})
    : status = DwTrustedTimeStatus.needsOnlineValidation,
      trustedNowUtc = null;

  const DwTrustedTimeReading._corrupt({this.binding})
    : status = DwTrustedTimeStatus.corrupt,
      trustedNowUtc = null;

  final DwOfflineLeaseBinding? binding;
  final DwTrustedTimeStatus status;
  final DateTime? trustedNowUtc;

  @override
  bool operator ==(Object other) {
    return other is DwTrustedTimeReading &&
        other.binding == binding &&
        other.status == status &&
        other.trustedNowUtc == trustedNowUtc;
  }

  @override
  int get hashCode => Object.hash(binding, status, trustedNowUtc);
}

final class DwTrustedTime {
  DwTrustedTime._({
    required DwTrustedTimeSource timeSource,
    required DwTrustedTimeSnapshot persistedSnapshot,
    required DateTime anchorTrustedUtc,
    required Duration runtimeMonotonicAnchor,
    required DwTrustedTimeStatus status,
  }) : _timeSource = timeSource,
       _persistedSnapshot = persistedSnapshot,
       _anchorTrustedUtc = anchorTrustedUtc,
       _runtimeMonotonicAnchor = runtimeMonotonicAnchor,
       _lastMonotonicElapsed = runtimeMonotonicAnchor,
       _lastTrustedUtc = anchorTrustedUtc,
       _status = status;

  factory DwTrustedTime.fromVerifiedInput({
    required DwVerifiedTimeInput verifiedInput,
    required DwTrustedTimeSource timeSource,
    DwTrustedTimeSnapshot? previousSnapshot,
  }) {
    final binding = verifiedInput.binding;
    final runtimeMonotonicAnchor = timeSource.monotonicElapsed;
    if (binding == null ||
        runtimeMonotonicAnchor.isNegative ||
        (previousSnapshot != null && previousSnapshot.binding != binding)) {
      return DwTrustedTime._corrupt(timeSource, binding: binding);
    }
    final wallClockUtcAtValidation = timeSource.wallClockUtcNow.toUtc();
    final maxVerifiedServerUtc = _latestUtc(
      verifiedInput.verifiedServerUtc,
      previousSnapshot?.maxVerifiedServerUtc,
    );
    final maxWallClockUtcSeen = _latestUtc(
      wallClockUtcAtValidation,
      previousSnapshot?.maxWallClockUtcSeen,
    );
    final trustedUtcWatermark = _latestUtc(
      _latestUtc(maxVerifiedServerUtc, maxWallClockUtcSeen),
      previousSnapshot?.trustedUtcWatermark,
    );
    final snapshot = DwTrustedTimeSnapshot._(
      binding: binding,
      verifiedServerUtc: verifiedInput.verifiedServerUtc,
      wallClockUtcAtValidation: wallClockUtcAtValidation,
      monotonicAnchor: runtimeMonotonicAnchor,
      maxVerifiedServerUtc: maxVerifiedServerUtc,
      maxWallClockUtcSeen: maxWallClockUtcSeen,
      trustedUtcWatermark: trustedUtcWatermark,
    );
    return DwTrustedTime._(
      timeSource: timeSource,
      persistedSnapshot: snapshot,
      anchorTrustedUtc: trustedUtcWatermark,
      runtimeMonotonicAnchor: runtimeMonotonicAnchor,
      status: DwTrustedTimeStatus.trusted,
    );
  }

  factory DwTrustedTime.fromPersistedSnapshot({
    required Object? persistedSnapshot,
    required DwTrustedTimeSource timeSource,
  }) {
    final decodedSnapshot = DwTrustedTimeSnapshot.decodePersisted(
      persistedSnapshot,
    );
    if (decodedSnapshot == null) {
      return DwTrustedTime._corrupt(timeSource);
    }
    final runtimeMonotonicAnchor = timeSource.monotonicElapsed;
    if (runtimeMonotonicAnchor.isNegative) {
      return DwTrustedTime._corrupt(
        timeSource,
        binding: decodedSnapshot.binding,
      );
    }
    final currentWallUtc = timeSource.wallClockUtcNow.toUtc();
    final rollbackToleranceUtc = _CheckedUtcArithmetic.add(
      currentWallUtc,
      rollbackTolerance,
    );
    if (rollbackToleranceUtc == null) {
      return DwTrustedTime._corrupt(
        timeSource,
        binding: decodedSnapshot.binding,
      );
    }
    if (rollbackToleranceUtc.isBefore(decodedSnapshot.maxWallClockUtcSeen)) {
      return DwTrustedTime._(
        timeSource: timeSource,
        persistedSnapshot: decodedSnapshot,
        anchorTrustedUtc: decodedSnapshot.trustedUtcWatermark,
        runtimeMonotonicAnchor: runtimeMonotonicAnchor,
        status: DwTrustedTimeStatus.needsOnlineValidation,
      );
    }
    final restoredAnchorUtc = _latestUtc(
      _latestUtc(
        decodedSnapshot.maxVerifiedServerUtc,
        decodedSnapshot.maxWallClockUtcSeen,
      ),
      _latestUtc(currentWallUtc, decodedSnapshot.trustedUtcWatermark),
    );
    final restoredSnapshot = DwTrustedTimeSnapshot._(
      binding: decodedSnapshot.binding,
      verifiedServerUtc: decodedSnapshot.verifiedServerUtc,
      wallClockUtcAtValidation: decodedSnapshot.wallClockUtcAtValidation,
      monotonicAnchor: decodedSnapshot.monotonicAnchor,
      maxVerifiedServerUtc: decodedSnapshot.maxVerifiedServerUtc,
      maxWallClockUtcSeen: _latestUtc(
        decodedSnapshot.maxWallClockUtcSeen,
        currentWallUtc,
      ),
      trustedUtcWatermark: restoredAnchorUtc,
    );
    return DwTrustedTime._(
      timeSource: timeSource,
      persistedSnapshot: restoredSnapshot,
      anchorTrustedUtc: restoredAnchorUtc,
      runtimeMonotonicAnchor: runtimeMonotonicAnchor,
      status: DwTrustedTimeStatus.trusted,
    );
  }

  factory DwTrustedTime._corrupt(
    DwTrustedTimeSource timeSource, {
    DwOfflineLeaseBinding? binding,
  }) {
    final zeroUtc = DateTime.fromMicrosecondsSinceEpoch(0, isUtc: true);
    final fallbackBinding =
        binding ??
        const DwOfflineLeaseBinding._(
          userScopeId: 'corrupt',
          leaseId: 'corrupt',
          recordVersion: 1,
          payloadDigest: 'corrupt',
        );
    return DwTrustedTime._(
      timeSource: timeSource,
      persistedSnapshot: DwTrustedTimeSnapshot._(
        binding: fallbackBinding,
        verifiedServerUtc: zeroUtc,
        wallClockUtcAtValidation: zeroUtc,
        monotonicAnchor: Duration.zero,
        maxVerifiedServerUtc: zeroUtc,
        maxWallClockUtcSeen: zeroUtc,
        trustedUtcWatermark: zeroUtc,
      ),
      anchorTrustedUtc: zeroUtc,
      runtimeMonotonicAnchor: Duration.zero,
      status: DwTrustedTimeStatus.corrupt,
    );
  }

  static const Duration rollbackTolerance = Duration(minutes: 5);

  final DwTrustedTimeSource _timeSource;
  DwTrustedTimeSnapshot _persistedSnapshot;
  final DateTime _anchorTrustedUtc;
  final Duration _runtimeMonotonicAnchor;
  Duration _lastMonotonicElapsed;
  DateTime _lastTrustedUtc;
  DwTrustedTimeStatus _status;

  DwTrustedTimeSnapshot get persistedSnapshot => _persistedSnapshot;

  DwTrustedTimeReading read() {
    final binding = _persistedSnapshot.binding;
    if (_status == DwTrustedTimeStatus.corrupt) {
      return DwTrustedTimeReading._corrupt(binding: binding);
    }
    if (_status == DwTrustedTimeStatus.needsOnlineValidation) {
      return DwTrustedTimeReading._needsOnlineValidation(binding: binding);
    }
    final currentMonotonicElapsed = _timeSource.monotonicElapsed;
    if (currentMonotonicElapsed.isNegative ||
        currentMonotonicElapsed < _runtimeMonotonicAnchor ||
        currentMonotonicElapsed < _lastMonotonicElapsed) {
      _status = DwTrustedTimeStatus.corrupt;
      return DwTrustedTimeReading._corrupt(binding: binding);
    }
    _lastMonotonicElapsed = currentMonotonicElapsed;
    final elapsedMicroseconds =
        currentMonotonicElapsed.inMicroseconds -
        _runtimeMonotonicAnchor.inMicroseconds;
    final candidateTrustedUtc = _CheckedUtcArithmetic.add(
      _anchorTrustedUtc,
      Duration(microseconds: elapsedMicroseconds),
    );
    if (candidateTrustedUtc == null) {
      _status = DwTrustedTimeStatus.corrupt;
      return DwTrustedTimeReading._corrupt(binding: binding);
    }
    if (candidateTrustedUtc.isAfter(_lastTrustedUtc)) {
      _lastTrustedUtc = candidateTrustedUtc;
    }
    final maxWallClockUtcSeen = _latestUtc(
      _persistedSnapshot.maxWallClockUtcSeen,
      _timeSource.wallClockUtcNow.toUtc(),
    );
    _persistedSnapshot = DwTrustedTimeSnapshot._(
      binding: binding,
      verifiedServerUtc: _persistedSnapshot.verifiedServerUtc,
      wallClockUtcAtValidation: _persistedSnapshot.wallClockUtcAtValidation,
      monotonicAnchor: _persistedSnapshot.monotonicAnchor,
      maxVerifiedServerUtc: _persistedSnapshot.maxVerifiedServerUtc,
      maxWallClockUtcSeen: maxWallClockUtcSeen,
      trustedUtcWatermark: _latestUtc(
        _latestUtc(_persistedSnapshot.trustedUtcWatermark, _lastTrustedUtc),
        maxWallClockUtcSeen,
      ),
    );
    return DwTrustedTimeReading._trusted(
      binding: binding,
      trustedNowUtc: _lastTrustedUtc,
    );
  }

  static DateTime _latestUtc(DateTime firstUtc, DateTime? secondUtc) {
    if (secondUtc == null || firstUtc.isAfter(secondUtc)) {
      return firstUtc.toUtc();
    }
    return secondUtc.toUtc();
  }
}
