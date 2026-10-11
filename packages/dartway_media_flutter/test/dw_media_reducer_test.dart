import 'package:dartway_media_flutter/dartway_media_flutter.dart';
import 'package:dartway_media_flutter/src/controller/dw_media_reducer.dart';
import 'package:flutter_test/flutter_test.dart';

Duration seconds(int n) => Duration(seconds: n);
EngineFact fact(
  int position, {
  bool playing = true,
  bool buffering = false,
  bool loading = false,
  bool ended = false,
  int seekEpoch = 0,
  bool provisionalPlayback = false,
}) => EngineFact(
  position: seconds(position),
  duration: seconds(100),
  buffered: seconds(100),
  playing: playing,
  buffering: buffering,
  loading: loading,
  ended: ended,
  seekEpoch: seekEpoch,
  provisionalPlayback: provisionalPlayback,
);

void main() {
  final ready = fact(0, playing: false);
  final cases =
      <
        ({
          String name,
          List<MediaEvent> events,
          DwMediaPlayIntent intent,
          bool waiting,
          int position,
          int? target,
          DwMediaPlayState playState,
          bool reallyPlayed,
          List<(int, int)> spans,
        })
      >[
        (
          name: 'buffering flaps preserve intent and continuous evidence',
          events: [
            ready,
            const PlayCommand(),
            fact(1),
            fact(1, buffering: true),
            fact(1),
            fact(2),
          ],
          intent: DwMediaPlayIntent.play,
          waiting: false,
          position: 2,
          target: null,
          playState: DwMediaPlayState.playing,
          reallyPlayed: true,
          spans: [(0, 1), (1, 2)],
        ),
        (
          name: 'optimistic isPlaying earns no evidence',
          events: [
            ready,
            const PlayCommand(),
            fact(0),
            const PlayCommand(),
            fact(0),
          ],
          intent: DwMediaPlayIntent.play,
          waiting: true,
          position: 0,
          target: null,
          playState: DwMediaPlayState.playing,
          reallyPlayed: false,
          spans: [],
        ),
        (
          name: 'refused web play restores pause intent',
          events: [
            ready,
            const PlayCommand(),
            fact(0),
            const PlayRefused(),
            fact(0, playing: false),
          ],
          intent: DwMediaPlayIntent.pause,
          waiting: false,
          position: 0,
          target: null,
          playState: DwMediaPlayState.ready,
          reallyPlayed: false,
          spans: [],
        ),
        (
          name: 'seek ignores stale position and ended facts',
          events: [
            ready,
            const PlayCommand(),
            fact(1),
            SeekCommand(seconds(50)),
            fact(2, seekEpoch: 1),
            fact(100, playing: false, ended: true, seekEpoch: 1),
          ],
          intent: DwMediaPlayIntent.play,
          waiting: false,
          position: 50,
          target: 50,
          playState: DwMediaPlayState.playing,
          reallyPlayed: true,
          spans: [(0, 1)],
        ),
        (
          name: 'two skips use the displayed target; old completion loses',
          events: [
            ready,
            SeekCommand(seconds(10)),
            SeekCommand(seconds(20)),
            SeekSettled(seconds(10)),
            fact(10, playing: false, seekEpoch: 2),
          ],
          intent: DwMediaPlayIntent.pause,
          waiting: false,
          position: 20,
          target: 20,
          playState: DwMediaPlayState.ready,
          reallyPlayed: false,
          spans: [],
        ),
        (
          name: 'pause during loading cancels autoplay',
          events: [const PlayCommand(), const PauseCommand(), ready],
          intent: DwMediaPlayIntent.pause,
          waiting: false,
          position: 0,
          target: null,
          playState: DwMediaPlayState.ready,
          reallyPlayed: false,
          spans: [],
        ),
        (
          name: 'ended then play restarts from zero',
          events: [
            ready,
            const PlayCommand(),
            fact(1),
            fact(100, playing: false, ended: true),
            const PlayCommand(),
          ],
          intent: DwMediaPlayIntent.play,
          waiting: true,
          position: 0,
          target: 0,
          playState: DwMediaPlayState.playing,
          reallyPlayed: true,
          spans: [(0, 1)],
        ),
        (
          name: 'error mid-seek clears the target and rejects late completion',
          events: [
            ready,
            const PlayCommand(),
            fact(1),
            SeekCommand(seconds(50)),
            const FailureFact('failed'),
            SeekSettled(seconds(50)),
            fact(50, seekEpoch: 1),
          ],
          intent: DwMediaPlayIntent.play,
          waiting: false,
          position: 50,
          target: null,
          playState: DwMediaPlayState.error,
          reallyPlayed: true,
          spans: [(0, 1)],
        ),
        (
          name: 'a settled seek starts evidence at its target',
          events: [
            ready,
            const PlayCommand(),
            fact(1),
            SeekCommand(seconds(50)),
            fact(2, seekEpoch: 1),
            SeekSettled(seconds(50)),
            fact(51, seekEpoch: 1),
          ],
          intent: DwMediaPlayIntent.play,
          waiting: false,
          position: 51,
          target: null,
          playState: DwMediaPlayState.playing,
          reallyPlayed: true,
          spans: [(0, 1), (50, 51)],
        ),
        (
          name: 'arrival within tolerance settles without earning a seek gap',
          events: [
            ready,
            const PlayCommand(),
            fact(1),
            SeekCommand(seconds(50)),
            fact(50, seekEpoch: 1),
            fact(51, seekEpoch: 1),
          ],
          intent: DwMediaPlayIntent.play,
          waiting: false,
          position: 51,
          target: null,
          playState: DwMediaPlayState.playing,
          reallyPlayed: true,
          spans: [(0, 1), (50, 51)],
        ),
      ];
  for (final row in cases) {
    test(row.name, () {
      var state = const MediaPlayerState();
      final spans = <DwMediaPlayedInterval>[];
      for (final event in row.events) {
        state = reduceMedia(state, event);
        if (state.interval case final interval?) spans.add(interval);
        spans.addAll(state.committedIntervals);
      }
      expect(state.playback.intent, row.intent);
      expect(state.playback.waiting, row.waiting);
      expect(state.playback.playState, row.playState);
      expect(state.playback.position, seconds(row.position));
      expect(
        state.playback.seekTarget,
        row.target == null ? null : seconds(row.target!),
      );
      expect(state.hasReallyPlayed, row.reallyPlayed);
      expect(spans, [
        for (final (start, end) in row.spans)
          DwMediaPlayedInterval(seconds(start), seconds(end)),
      ]);
    });
  }

  test('an aborted seek anchors at the next engine fact', () {
    var state = const MediaPlayerState();
    final spans = <DwMediaPlayedInterval>[];
    for (final event in <MediaEvent>[
      ready,
      const PlayCommand(),
      fact(50),
      SeekCommand(seconds(10)),
      SeekAborted(seconds(10)),
      fact(51, seekEpoch: 1),
    ]) {
      state = reduceMedia(state, event);
      if (state.interval case final interval?) spans.add(interval);
      spans.addAll(state.committedIntervals);
    }
    expect(spans, [DwMediaPlayedInterval(Duration.zero, seconds(50))]);
    expect(state.playback.position, seconds(51));
    expect(state.playback.seekTarget, isNull);
  });

  test('a poll from before a seek cannot rewind settled playback', () {
    var state = const MediaPlayerState();
    final spans = <DwMediaPlayedInterval>[];
    for (final event in <MediaEvent>[
      ready,
      const PlayCommand(),
      SeekCommand(seconds(50)),
      SeekSettled(seconds(50)),
      fact(2),
      fact(51, seekEpoch: 1),
    ]) {
      state = reduceMedia(state, event);
      if (state.interval case final interval?) spans.add(interval);
      spans.addAll(state.committedIntervals);
    }
    expect(state.playback.position, seconds(51));
    expect(spans, [DwMediaPlayedInterval(seconds(50), seconds(51))]);
  });

  test('web audio commits only when its play call completes', () {
    var state = const MediaPlayerState();
    final spans = <DwMediaPlayedInterval>[];
    for (final event in <MediaEvent>[
      ready,
      const PlayCommand(),
      fact(2, provisionalPlayback: true),
      const PauseCommand(),
      const PlayAccepted(1),
    ]) {
      state = reduceMedia(state, event);
      spans.addAll(state.committedIntervals);
    }
    expect(spans, [DwMediaPlayedInterval(Duration.zero, seconds(2))]);
    expect(state.hasReallyPlayed, isTrue);
  });

  test('web audio refusal drops spans closed before it arrived', () {
    var state = const MediaPlayerState();
    final spans = <DwMediaPlayedInterval>[];
    for (final event in <MediaEvent>[
      ready,
      const PlayCommand(),
      fact(2, provisionalPlayback: true),
      const PauseCommand(),
      const PlayRefused(1),
    ]) {
      state = reduceMedia(state, event);
      spans.addAll(state.committedIntervals);
    }
    expect(spans, isEmpty);
    expect(state.hasReallyPlayed, isFalse);
  });
}
