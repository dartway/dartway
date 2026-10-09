---
name: dartway-media
description: >-
  Video and audio: the plugin DwMedia (dartway_media_flutter, dw.plugins.media) with DwMediaConfig and
  DwMediaOpenOptions, DwMediaItem and DwMediaSource (a URL or a resolver re-called on retry), the
  session the plugin owns (play, seek, queue, autoplay, fullscreen, minimize/restore),
  DwMediaFullscreenHost, DwMiniPlayerHost, and the test fakes. The package ships no controls: they
  are copied from the framework's example into the kit. Use when a feature plays video or audio,
  needs a queue, resume, a mini-player or fullscreen, or when a player's behaviour needs tuning.
---

# DartWay — video and audio (`dartway-media`)

**Mechanism in the package, look in the project** — no button, timeline, colour or text ships.
Every setting and its default: `docs/3-flutter/media.md` in the framework repository.

## Add it

Until it is on pub.dev, a git dependency with the same `url` and `ref` as the project's other `dartway_*`
packages (`frameworkRefsDiverged` warns otherwise), `path: packages/dartway_media_flutter`. Then in the
core's `plugins:` — `DwMedia(config: const DwMediaConfig(speeds: [1, 1.25, 1.5, 2], autoplayNext: true,
nextPreview: true))`. A project that plays nothing does not add it.

## Sessions

```dart
final session = dw.plugins.media.open(
  items: [
    DwMediaItem(
      id: item.id.toString(),
      kind: DwMediaKind.video,
      title: item.title,
      source: DwMediaSource.resolve(() => fetchPlaybackUrl(item.id)),
    ),
  ],
  callbacks: DwMediaCallbacks(onCompleted: (item) => onPositionThreshold(item.id)),
  options: const DwMediaOpenOptions(autoplayOnOpen: true),
);
```

- **Anything that expires is a resolver**, re-called on every load and retry.
- **The plugin owns the session** (`dw.plugins.media.sessionManager.active`): a page never keeps or
  disposes it; opening an item a live session stands on returns that session. Everything goes through
  the session — `play`, `seek`, `setSpeed` (only from `options.speeds`), `retry`, the queue.
- Per-session settings: `DwMediaOpenOptions` (`withoutResume: true` for a clip feed).
- `onCompleted` — position threshold (a seek counts), not played coverage; `onReachedEnd` — played to the end by real playback
  only, never a scrub; `onStarted` — the first real playback.

## Controls, fullscreen, the mini-player

Copy what the feature needs from the framework repository's example (on GitHub, not in this project),
[`ui_kit/3_special/media/`](https://github.com/dartway/dartway/tree/master/example/dartway_example_flutter/lib/ui_kit/3_special/media)
into the project's `lib/ui_kit/3_special/media/`, add the `part` lines, restyle — `AppMediaPlayer`,
`AppMediaControlBar`, `AppMediaTimeline` (one `seek` on release), `AppMediaNextItemCard`,
`AppMediaErrorView` (`retry()` inside the player), `AppMiniPlayerChrome`. Strings through `context.l10n`
(the example's `media*` keys).

- **Fullscreen**: `DwMediaFullscreenHost(session:, builder:, child:)` around the inline player — the one
  way in; `enterFullscreen()`/`exitFullscreen()` and back gestures.
- **Mini-player**: `DwMiniPlayerHost(sessionManager:, onExpand:, builder:)` once, in
  `MaterialApp.builder` over the router's child; it has no `Overlay` above it (no tooltips). It
  drags freely, resizes by a pinch and — with a mouse — by a corner handle; the chrome draws the
  handle's mark at `DwMiniPlayerHost.resizeCornerOf(context)` and keeps its buttons off that corner.
  Never re-implement the host to change placement or size: the `miniPlayer*` settings cover it.
- **The player page** restores the session on entry and minimizes it on leaving, in a hook —
  `final media = dw.plugins.media.sessionManager;` then
  `useEffect(() { media.active.value?.restore(); return () => media.active.value?.minimize(); }, const [])`,
  as the framework repository's example (on GitHub, not in this project) does in
  [`workouts_page.dart`](https://github.com/dartway/dartway/blob/master/example/dartway_example_flutter/lib/app/workouts/workouts_page.dart).
  With `miniPlayer: false`, `minimize()` follows `onLeaveWithoutMiniPlayer`. `open()`, `minimize()`
  and `restore()` are safe from `initState`/`dispose` — a page that plays its own material on
  entry opens it there, with no post-frame helper of its own; `play()`, `pause()`, `seek()` and
  `jumpTo()` are commands for after the frame (a tap, a callback), never called from a build.

## Platforms and tests

Background audio needs `audio` in iOS `UIBackgroundModes`; the web starts muted until the person
unmutes. Tests: `DwFakeVideoPlayerPlatform.install()` and `DwFakeJustAudioPlatform.install()` from
`package:dartway_media_flutter/testing.dart`; real playback is `latest.advanceTo(…)`, a scrub
`session.seek(…)`, the end `finish()`, a failure `fail(…)` — "a scrub does not count as the end" is
proved with those, not with a position alone; after an audio command
`await dwSettleMedia(tester)`; `await dw.plugins.media.dispose()` before a test with a playing video ends.

## Confirmed intervals and delivery (optional)

Default players do not prove played coverage from `onProgress`/position snapshots.
Never subtract consecutive positions to record time: a seek can bridge the gap.
Only an observer with independent confirmation may capture
`session.playbackObservation` before a span and call
`handle.record(DwMediaPlayedInterval(start, end))` afterwards. A stale
handle or known non-playing state rejects the observation; these guards do not
prove the interval. Pause, buffering, seek, speed, background and source reload
break continuity. Fullscreen/mini-player reuse the session. Missing samples earn
nothing; neither end nor a seek fills coverage to the duration.

Opt in with `DwMediaConfig(playbackDelivery: acceptReport)` or the session override;
without an adapter recording is disabled (`withoutPlaybackDelivery` disables an
inherited adapter). The adapter must take durable ownership before its Future
succeeds. `session.flushPlayback()` seals a nonempty window and starts one handled
attempt; replacement/end/disposal seal remaining confirmed intervals too. Inspect
`manager.pendingPlaybackReports` and `manager.playbackDeliveryError(report)`;
`await manager.retryPlaybackReport(report)` retries explicitly and surfaces failure.
Concurrent retry joins the same attempt. Pending reports capture their adapter and
source attribution, survive engine disposal, and exist only while the manager does.
There are no retry timers or process-lifetime persistence guarantees.

Reports have immutable half-open intervals, sorted and merged across overlap and
adjacency, and only unique covered duration. Later reports may overlap after a
rewatch: project consumers union them using `DwMediaIntervalAccumulator`, rather
than summing report durations. Batch/session/generation identities are manager-local,
not backend idempotency keys. Thresholds such as 70%, content identity, DTOs, durable
storage and backend deduplication belong to the project. The framework example's
`workout_playback_coverage.dart` illustrates explicit input and in-memory acceptance;
it never wires position callbacks as confirmed input.
