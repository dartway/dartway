import 'package:dartway_media_flutter/dartway_media_flutter.dart';

/// An explicit-input example, with in-memory acceptance only.
///
/// The default players cannot prove played spans from position callbacks, so
/// WorkoutsPage never calls confirm automatically. A capable observation adapter
/// captures session.playbackObservation before a span, confirms that span itself
/// (including platform discontinuities), then passes the same handle to confirm.
/// A production delivery adapter must durably take ownership before acknowledging.
class WorkoutPlaybackCoverage {
  final _coverage = <String, DwMediaIntervalAccumulator>{};

  DwMediaObservationResult confirm(
    DwMediaObservationHandle observation,
    DwMediaPlayedInterval confirmed,
  ) => observation.record(confirmed);

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
