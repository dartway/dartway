/// An explicitly confirmed, half-open span of media positions [start, end).
/// This value proves nothing about a player: the caller confirms playback.
final class DwMediaPlayedInterval {
  DwMediaPlayedInterval(this.start, this.end) {
    if (start < Duration.zero || end <= start) {
      throw ArgumentError('a played interval needs 0 <= start < end');
    }
  }

  final Duration start;
  final Duration end;
  Duration get duration => end - start;

  @override
  bool operator ==(Object other) =>
      other is DwMediaPlayedInterval &&
      other.start == start &&
      other.end == end;
  @override
  int get hashCode => Object.hash(start, end);
  @override
  String toString() => 'DwMediaPlayedInterval($start, $end)';
}

/// The sorted union of explicitly supplied media intervals. Overlap and
/// adjacency merge; rewatches do not increase unique covered media duration.
final class DwMediaIntervalAccumulator {
  List<DwMediaPlayedInterval> _intervals = [];

  List<DwMediaPlayedInterval> get intervals => List.unmodifiable(_intervals);
  bool get isEmpty => _intervals.isEmpty;
  Duration get coveredDuration => _intervals.fold(
    Duration.zero,
    (sum, interval) => sum + interval.duration,
  );

  void add(DwMediaPlayedInterval interval) {
    final sorted = [..._intervals, interval]
      ..sort((a, b) => a.start.compareTo(b.start));
    final merged = <DwMediaPlayedInterval>[];
    for (final next in sorted) {
      if (merged.isEmpty || next.start > merged.last.end) {
        merged.add(next);
      } else if (next.end > merged.last.end) {
        merged[merged.length - 1] = DwMediaPlayedInterval(
          merged.last.start,
          next.end,
        );
      }
    }
    _intervals = merged;
  }

  void clear() => _intervals = [];
}

/// One immutable sealed observation window. Identities are local to the
/// owning manager, stable for retries, and are not backend idempotency keys.
/// Union intervals across reports for coverage; never sum report durations.
final class DwMediaPlaybackReport {
  DwMediaPlaybackReport({
    required this.batchId,
    required this.sessionId,
    required this.itemId,
    required this.sourceGeneration,
    required Iterable<DwMediaPlayedInterval> intervals,
  }) : intervals = _reportIntervals(intervals);

  final int batchId;
  final int sessionId;
  final String itemId;

  /// Distinguishes item visits and every source load/retry in this session.
  final int sourceGeneration;
  final List<DwMediaPlayedInterval> intervals;
  Duration get coveredDuration =>
      intervals.fold(Duration.zero, (sum, interval) => sum + interval.duration);
}

/// Future success acknowledges this exact batch's acceptance. A project can
/// persist it durably before acknowledging. Errors retain the pending report.
typedef DwMediaPlaybackDelivery =
    Future<void> Function(DwMediaPlaybackReport report);

List<DwMediaPlayedInterval> _reportIntervals(
  Iterable<DwMediaPlayedInterval> intervals,
) {
  final union = DwMediaIntervalAccumulator();
  for (final interval in intervals) {
    union.add(interval);
  }
  if (union.isEmpty)
    throw ArgumentError('a playback report needs confirmed intervals');
  return union.intervals;
}
