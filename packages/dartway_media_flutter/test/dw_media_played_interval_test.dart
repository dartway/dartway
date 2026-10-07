import 'package:dartway_media_flutter/src/observation/dw_media_played_interval.dart';
import 'package:flutter_test/flutter_test.dart';

DwMediaPlayedInterval span(int start, int end) =>
    DwMediaPlayedInterval(Duration(seconds: start), Duration(seconds: end));

void main() {
  test(
    'half-open intervals reject negative, empty and reversed spans at runtime',
    () {
      for (final values in [(-1, 1), (0, 0), (2, 1)]) {
        expect(() => span(values.$1, values.$2), throwsArgumentError);
      }
      expect(span(0, 1).duration, const Duration(seconds: 1));
    },
  );
  test(
    'union is sorted, merges overlap/adjacency and does not count rewatches twice',
    () {
      final inputs = [
        span(20, 25),
        span(5, 10),
        span(0, 7),
        span(10, 12),
        span(6, 8),
        span(21, 24),
      ];
      for (final order in [inputs, inputs.reversed.toList()]) {
        final accumulator = DwMediaIntervalAccumulator();
        for (final interval in order) {
          accumulator.add(interval);
        }
        expect(accumulator.intervals, [span(0, 12), span(20, 25)]);
        expect(accumulator.coveredDuration, const Duration(seconds: 17));
        final snapshot = accumulator.intervals;
        expect(() => snapshot.add(span(30, 31)), throwsUnsupportedError);
        accumulator.clear();
        expect(accumulator.isEmpty, isTrue);
        expect(accumulator.coveredDuration, Duration.zero);
        expect(snapshot, [span(0, 12), span(20, 25)]);
      }
    },
  );
  test('report takes an immutable normalized copy; an empty report fails', () {
    final input = [span(5, 10), span(0, 6)];
    final report = DwMediaPlaybackReport(
      batchId: 1,
      sessionId: 1,
      itemId: 'a',
      sourceGeneration: 1,
      intervals: input,
    );
    input.clear();
    expect(report.intervals, [span(0, 10)]);
    expect(report.coveredDuration, const Duration(seconds: 10));
    expect(() => report.intervals.clear(), throwsUnsupportedError);
    expect(
      () => DwMediaPlaybackReport(
        batchId: 1,
        sessionId: 1,
        itemId: 'a',
        sourceGeneration: 1,
        intervals: [],
      ),
      throwsArgumentError,
    );
  });
}
