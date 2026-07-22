/// Result of sending to one provider-specific target, such as a device token.
enum DwPushTargetStatus {
  /// The provider accepted the push for this target.
  sent,

  /// The target is no longer valid and should be removed by the host app.
  invalid,

  /// A transient failure occurred and the recipient delivery may be retried.
  retryableFailure,

  /// A permanent failure occurred for this target.
  permanentFailure,
}

/// Provider outcome for one target.
final class DwPushTargetResult {
  const DwPushTargetResult({
    required this.target,
    required this.status,
    this.errorCode,
    this.retryAfter,
  });

  final String target;
  final DwPushTargetStatus status;
  final String? errorCode;

  /// Provider-requested minimum delay before retrying this target.
  final Duration? retryAfter;
}

/// Aggregated provider outcome for one recipient delivery attempt.
final class DwPushTransportResult {
  DwPushTransportResult(Iterable<DwPushTargetResult> results)
    : results = List.unmodifiable(results) {
    final targets = <String>{};
    for (final result in this.results) {
      if (!targets.add(result.target)) {
        throw ArgumentError.value(
          result.target,
          'results',
          'Each target must occur exactly once',
        );
      }
      if (result.retryAfter != null &&
          (result.status != DwPushTargetStatus.retryableFailure ||
              result.retryAfter! <= Duration.zero)) {
        throw ArgumentError.value(
          result.retryAfter,
          'results',
          'retryAfter must be positive and is valid only for retryable failures',
        );
      }
    }
  }

  final List<DwPushTargetResult> results;

  bool get wasDelivered =>
      results.any((result) => result.status == DwPushTargetStatus.sent);

  bool get shouldRetry =>
      !wasDelivered &&
      results.any(
        (result) => result.status == DwPushTargetStatus.retryableFailure,
      );

  /// Longest provider-requested retry delay across retryable targets.
  Duration? get retryAfter {
    Duration? longest;
    for (final result in results) {
      final candidate = result.retryAfter;
      if (candidate != null && (longest == null || candidate > longest)) {
        longest = candidate;
      }
    }
    return longest;
  }

  List<String> get invalidTargets => results
      .where((result) => result.status == DwPushTargetStatus.invalid)
      .map((result) => result.target)
      .toList(growable: false);
}
