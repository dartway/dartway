import 'package:dartway_media_flutter/dartway_media_flutter.dart';

/// In-memory acceptance of the package's played spans. Union reports across
/// rewatches; a durable adapter would persist before acknowledging acceptance.
class WorkoutPlaybackCoverage {
  final _coverage = <String, DwMediaIntervalAccumulator>{};

  /// Acknowledges acceptance into this demo's memory, not persistent storage.
  Future<void> accept(DwMediaPlaybackReport report) async {
    final coverage = _coverage.putIfAbsent(
      report.itemId,
      DwMediaIntervalAccumulator.new,
    );
    for (final interval in report.intervals) {
      coverage.add(interval);
    }
  }

  Duration coveredDuration(String itemId) =>
      _coverage[itemId]?.coveredDuration ?? Duration.zero;
}
