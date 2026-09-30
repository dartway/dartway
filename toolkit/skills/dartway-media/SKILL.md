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
  callbacks: DwMediaCallbacks(onCompleted: (item) => markWatched(item.id)),
  options: const DwMediaOpenOptions(autoplayOnOpen: true),
);
```

- **Anything that expires is a resolver**, re-called on every load and retry.
- **The plugin owns the session** (`dw.plugins.media.sessionManager.active`): a page never keeps or
  disposes it; opening an item a live session stands on returns that session. Everything goes through
  the session — `play`, `seek`, `setSpeed` (only from `options.speeds`), `retry`, the queue.
- Per-session settings: `DwMediaOpenOptions` (`withoutResume: true` for a clip feed).
- `onCompleted` — watched enough (a seek counts); `onReachedEnd` — played to the end; `onStarted` — the
  first real playback.

## Controls, fullscreen, the mini-player

Copy what the feature needs from the example's
[`ui_kit/3_special/media/`](https://github.com/dartway/dartway/tree/master/example/dartway_example_flutter/lib/ui_kit/3_special/media)
into the project's `lib/ui_kit/3_special/media/`, add the `part` lines, restyle — `AppMediaPlayer`,
`AppMediaControlBar`, `AppMediaTimeline` (one `seek` on release), `AppMediaNextItemCard`,
`AppMediaErrorView` (`retry()` inside the player), `AppMiniPlayerChrome`. Strings through `context.l10n`
(the example's `media*` keys).

- **Fullscreen**: `DwMediaFullscreenHost(session:, builder:, child:)` around the inline player — the one
  way in; `enterFullscreen()`/`exitFullscreen()` and back gestures.
- **Mini-player**: `DwMiniPlayerHost(sessionManager:, onExpand:, builder:)` once, in
  `MaterialApp.builder` over the router's child; it has no `Overlay` above it (no tooltips).
- **The player page** restores the session on entry and minimizes it on leaving, in a hook —
  `useEffect(() { media.active.value?.restore(); return () => media.active.value?.minimize(); }, const [])`,
  as the example's
  [`workouts_page.dart`](https://github.com/dartway/dartway/blob/master/example/dartway_example_flutter/lib/app/workouts/workouts_page.dart)
  does. With `miniPlayer: false`, `minimize()` follows `onLeaveWithoutMiniPlayer`.

## Platforms and tests

Background audio needs `audio` in iOS `UIBackgroundModes`; the web starts muted until the person
unmutes. Tests: `DwFakeVideoPlayerPlatform.install()` and `DwFakeJustAudioPlatform.install()` from
`package:dartway_media_flutter/testing.dart`; real playback is `latest.advanceTo(…)`, a scrub
`session.seek(…)`, the end `finish()`, a failure `fail(…)`; after an audio command
`await dwSettleMedia(tester)`; `await dw.plugins.media.dispose()` before a test with a playing video ends.
