---
name: dartway-media
description: >-
  Video and audio in a DartWay app: the plugin `DwMedia` (`dartway_media_flutter`,
  `dw.plugins.media`) with `DwMediaConfig` and per-session `DwMediaOpenOptions`, `DwMediaItem` /
  `DwMediaSource` (a URL or a resolver re-called on retry), `DwMediaSession` (play, pause, seek,
  skip, speed, mute, retry, next/previous/jumpTo, autoplay countdown, fullscreen, minimize/restore),
  `DwMediaCallbacks`, `DwVideoSurface`, `DwMediaFullscreenHost`, `DwMiniPlayerHost`, and the
  fakes of `testing.dart`. **The package ships no controls**: play/pause, the timeline, speed,
  fullscreen, the next-item card, the mini-player's look and the error state with retry are the
  project's own widgets, copied from the framework's example and restyled. Use when a feature plays
  a video or an audio track, needs a queue, resume, a mini-player or fullscreen, or when a player's
  error, background or web behaviour needs tuning.
---

# DartWay — video and audio (`dartway-media`)

**Mechanism in the package, look in the project.** `dartway_media_flutter` has no button, no
timeline, no colour and no text. The controls an app shows are its own `ui_kit/` widgets. The
framework's page is `docs/3-flutter/media.md` in the framework repository: its settings table is
the one list of every setting and its default; this skill does not repeat it.

## 1. Add the package and the plugin — `__FLUTTER_PKG__`

The package is not on pub.dev yet. Until it is, it comes from the framework repository like the
project's other `dartway_*` git dependencies — the same `url` and `ref` as theirs, so all of them
lock to one commit (`frameworkRefsDiverged` warns otherwise):

```yaml
dependencies:
  dartway_media_flutter:
    git:
      url: https://github.com/dartway/dartway.git
      ref: master          # the ref the other dartway_* packages use
      path: packages/dartway_media_flutter
```

Once it is published, this becomes `flutter pub add dartway_media_flutter`.

In the core's `plugins:`:

```dart
DwMedia(
  config: const DwMediaConfig(
    speeds: [1, 1.25, 1.5, 2],   // empty (the default) hides the speed control
    autoplayNext: true,
    nextPreview: true,
  ),
),
```

A project that plays nothing does not add the package: `video_player` and `just_audio` come with
it.

## 2. Open a session

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

- **Anything that expires is a resolver, not a URL.** `DwMediaSource.resolve` is called on every
  load and on every retry, so an expired signed link is fetched again instead of ending the player.
- **The plugin owns the session.** Do not keep it in a page's `State` and do not dispose it when the
  page goes: `dw.plugins.media.sessionManager.active` holds it, and that is what lets the
  mini-player carry on. A page reads the active session with a `ValueListenableBuilder` — or simply
  opens its item again: `open()` for an item a live session stands on returns that session, never a
  second engine — with this open's callbacks, settings and queue, and playing under `autoplayOnOpen`.
- **Everything goes through the session.** Its engine is not public; commands are `session.play()`,
  `seek`, `setSpeed` (a speed from `options.speeds` only — it throws otherwise), `retry`, the queue
  and the rest.
- **Settings are per session when they must be.** One `DwMediaConfig` for the app, a
  `DwMediaOpenOptions` for the session that differs (`withoutResume: true` for a clip feed).
- **Pick the right callback.** `onCompleted` — "watched enough", fires at `completedThreshold`,
  a seek counts. `onReachedEnd` — "played to the end", real playback only, a scrub never counts.
  `onStarted` — the first real playback, not a `play()` the browser refused.

## 3. The controls: copy, then restyle

Read `example/dartway_example_flutter/lib/ui_kit/3_special/media/` in the framework repository end
to end, copy what the feature needs into `__FLUTTER_PKG__/lib/ui_kit/3_special/media/`, add the
`part` lines to `ui_kit.dart`, and restyle there. From then on they are the project's widgets.

| Widget | What it reads and calls |
|---|---|
| `AppMediaPlayer` | the inline player: `DwMediaFullscreenHost` around the picture, the controls while `session.controlsVisible` (the session hides them after `controlsAutoHideDelay` of playback; a tap calls `toggleControls`), the next card, the error view |
| `AppMediaControlBar` | `session.playback`, `session.isFullscreen`; `play`/`pause`, `skipBack`/`skipForward`, `setMuted`, `setSpeed` (hidden when `options.speeds` is empty), `enterFullscreen`/`exitFullscreen` (hidden when `options.fullscreen` is off or the item is audio) |
| `AppMediaTimeline` | `session.playback` position, buffered, duration; one `seek` on release, not one per drag frame |
| `AppMediaNextItemCard` | `session.queue`: `showNextPreview`, `next`, `autoplayCountdown`; `next()`, `cancelAutoplay()` |
| `AppMediaErrorView` | `playback.isError`; `retry()` — the error stays inside the player |
| `AppMiniPlayerChrome` | the `builder` of `DwMiniPlayerHost`: the picture, play/pause, close |

Every visible string goes through `context.l10n` — the keys the example uses are `media*` in its
`.arb` files. A kit widget carries no string literal: `dart run dartway_cli:dartway check` reports one as
`uiKitContainsText`, which is why tests find these widgets by type and tooltip, not by `Key`.

## 4. Fullscreen, the mini-player, the page

- **Fullscreen**: wrap the inline player in `DwMediaFullscreenHost(session:, builder:, child:)`.
  `session.enterFullscreen()` — or `autoEnterFullscreenOnPlay` — pushes the package's own route
  (not exported: the host is the one way in); `exitFullscreen()` and a back gesture both leave it;
  orientations and the transition come from the config. A request made before the host mounts
  (autoplay on open, the page's `initState`) waits for it; from the mini-player there is no
  fullscreen.
- **Mini-player**: mount `DwMiniPlayerHost` once, in `MaterialApp.builder`, over the router's
  child:

```dart
builder: (context, child) => Stack(
  children: [
    child ?? const SizedBox.shrink(),
    DwMiniPlayerHost(
      sessionManager: dw.plugins.media.sessionManager,
      // `router` is `ref.watch(appRouterProvider)`, already in `build`.
      onExpand: (_) => router.router.goNamed(AppNavigationZone.player.name),
      builder: (context, session, expand, close) =>
          AppMiniPlayerChrome(session: session, onExpand: expand, onClose: close),
    ),
  ],
),
```

  It sits above the navigator, where there is no `Overlay`: no tooltips in its chrome.
- **The player page** calls `session.restore()` in `initState` and `session.minimize()` in
  `dispose` — both are safe there. With `miniPlayer: false`, `minimize()` does what
  `onLeaveWithoutMiniPlayer` says (pause by default), so nothing plays on with no screen.

## 5. Platform setup

- **Background audio** (`backgroundAudio: true`): iOS needs `audio` in `UIBackgroundModes` in
  `ios/Runner/Info.plist`; without it audio stops with the screen whatever the flag says. Android
  needs nothing for playback with the screen locked; a notification with controls is not part of
  the package.
- **Web**: nothing to add. Video starts muted until the person unmutes (`webMutedStart`), and the
  choice carries on (`rememberSound`).

## 6. Tests

```dart
import 'package:dartway_media_flutter/testing.dart';

late DwFakeVideoPlayerPlatform video;

setUp(() {
  video = DwFakeVideoPlayerPlatform.install();
  DwFakeJustAudioPlatform.install();
});
```

- Real playback is `video.latest.advanceTo(...)` (audio: `latest.advanceTo`) after `play()`; a scrub
  is `session.seek(...)`; the platform's end is `finish()`, a failure `fail(...)`. Prove "a scrub
  does not count as the end" with those, not with a position alone.
- After an audio command, `await dwSettleMedia(tester)` — `just_audio` finishes outside a widget
  test's fake clock, and a bare `pump` leaves the item loading.
- A playing video polls on a timer: `await dw.plugins.media.dispose()` (through the test app's
  pumping helper) before the test ends.
