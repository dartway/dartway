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
}) => EngineFact(
  position: seconds(position),
  duration: seconds(100),
  buffered: seconds(100),
  playing: playing,
  buffering: buffering,
  loading: loading,
  ended: ended,
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
            fact(2),
            fact(100, playing: false, ended: true),
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
            fact(10, playing: false),
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
            fact(50),
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
            fact(2),
            SeekSettled(seconds(50)),
            fact(51),
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
            fact(50),
            fact(51),
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
}
