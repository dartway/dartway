# Video and audio: what does the package do, and what does the project draw?

Every DartWay project that plays media used to write its own player. Tvaity grew a full one —
speed, fullscreen, resume, an in-app mini-player, a next-item card, an audio playlist, background
audio, one active player app-wide, the web's autoplay rules. Molodey has bare `video_player`/
`just_audio` widgets whose error state takes over the whole lesson
(`dartway/molodey#128`) and a signed link that expires after two hours. `dartway_media_flutter`
is the one player every project builds on instead, reached as `dw.plugins.media`.

**Mechanism only — no look.** The package has no button, no timeline widget, no colour (see
[the UI kit](ui-kit.md)), and no `chewie`: `chewie` ships Material/Cupertino controls, which is a
design decision the package does not make. The default controls a project actually shows live in
`example/dartway_example_flutter/lib/ui_kit/3_special/media/`, copied into the project's own
`ui_kit/` and restyled — the `dartway-media` toolkit skill walks through it. A project that plays
nothing does not add this package at all, and does not download `video_player`.

## The shape

- **`DwMediaItem`** — one thing to play: a stable `id` (the identity used for resume, for "is this
  the active item", and as the queue's key), a `kind` (`video`/`audio`), and a `DwMediaSource`.
- **`DwMediaSource.url(...)`** for a plain address; **`DwMediaSource.resolve(...)`** for anything
  time-limited — an async function called again on every load *and* on every
  `DwMediaController.retry()`, so an expired signed link is re-fetched instead of dead-ending the
  player.
- **`DwMedia.open(items:, callbacks:, options:)`** returns a `DwMediaSession` — a queue, the
  current controller, fullscreen and minimized state. **The session survives the widget that opened
  it.** Hold it outside a `State`'s lifetime (a controller/provider both the page and the
  mini-player reach), not as a local variable — that is what lets the mini-player and fullscreen
  keep playing through navigation, and it is the plugin, not any widget, that owns it.
- **`DwMediaController`** — one API over both engines: `play`/`pause`/`seek`/`skip`/`setSpeed`/
  `setVolume`/`setMuted`/`retry`, and a `state` (`ValueListenable<DwMediaPlaybackState>`):
  `loading`/`buffering`/`playing`/`paused`/`ended`/`error`, with position, duration, buffered range,
  speed, volume and an error message.
- **Callbacks are supplied once, at `open()`**, and cover the whole queue: `onStarted`,
  `onProgress` (throttled), `onReachedEnd`, `onCompleted` (at a configurable threshold), `onError`,
  `onItemChanged` (the queue advancing).
- **State is `ValueListenable`, not a riverpod `Provider`.** `dw.plugins.prefs.provider(...)`
  declares a provider once, as a top-level `final`, because a preferences key is known at compile
  time; a `DwMediaSession`'s identity is created at `open()`, so there is nothing to declare a
  top-level provider of. Read `session.controller.state`/`session.queue`/`session.isFullscreen`/
  `session.minimized` and `dw.plugins.media.sessionManager.active` with `ValueListenableBuilder`/
  `ListenableBuilder`, the way `DwVideoSurface` and `DwMiniPlayerHost` do internally.

## The trap both engines share, and how the package avoids it

`onReachedEnd` must fire when real playback reaches the end, and must **not** fire when someone
scrubs the timeline to the very end. Both engines make the naive check wrong:

- `video_player`'s `VideoPlayerValue.isCompleted` becomes `true` on *any* `seekTo` that lands on the
  duration — including a scrub — not only when playback actually finishes.
- `just_audio` on Android can reach `ProcessingState.completed` after a seek performed while
  paused, with `play()` never called in the session (`dartway/molodey#128`'s origin).

So `onReachedEnd` is never derived from a position/duration comparison by itself. Every seek
`DwMediaController` performs — from `seek`, `skip`, or resuming a saved position — runs through a
guard that suppresses the one synchronous state update that seek itself causes; the engine's own,
independent "real end of playback" event is never suppressed, because it arrives without this
controller having called `seek`. `DwMediaConfig.reachedEndTolerance` adds one documented exception
on top of the guard: a tick that is still genuinely *playing* and lands within tolerance of the
duration also counts, since that is continued playback, not a scrub.

## Session, queue, fullscreen, mini-player

- **One active item app-wide** by default (`DwMediaConfig.singleActiveItem`): opening a session, or
  calling `play()` on one, pauses whichever session was previously active. Off allows several
  sessions to play at once.
- **The queue** advances with `next`/`previous`/`jumpTo`; a next-item preview and an autoplay
  countdown are each their own flag, independent of one another and of `autoplayNext` itself.
- **Fullscreen** is the package's own route (`showDwMediaFullscreen`/`DwMediaFullscreenRoute`), with
  configurable orientations for both fullscreen and after exit, restored however the route ends —
  a system back gesture, `Navigator.pop`, or the app calling `session.exitFullscreen()`.
- **The mini-player** (`DwMiniPlayerHost`) is mounted once, at the app root; it decides *whether* to
  show a session (active and minimized) and the drag/pinch-to-scale/edge-snap mechanics, and calls
  `onExpand(item)` — where that expands *to* is the app's own route, this widget has no opinion. Its
  look comes entirely from the `builder` a project supplies.

## Background, wakelock, web

- Video pauses on the app going to the background (`paused`/`hidden`/`detached`) unless
  `pauseVideoInBackground` is off; **`inactive` is deliberately never treated as background** — it
  fires for a system dialog, an incoming call banner, or the OS's own fullscreen transition, and
  pausing on it broke a project's fullscreen video in practice.
- Audio keeps playing in the background when `backgroundAudio` is on — which additionally needs, on
  iOS, `audio` in `Info.plist`'s `UIBackgroundModes` (Android needs nothing extra).
- The screen is kept awake while a video plays (`wakelockWhilePlaying`), refcounted across however
  many sessions want it at once.
- On the web, a video starts muted and is unmuted once playback is actually granted
  (`webMutedStart`) — starting unmuted throws `NotAllowedError` outside a user gesture — and the
  chosen sound state can carry across items in the same session (`webRememberSoundChoice`).

## Every knob

**Nothing here is fixed policy.** Every field below is a `DwMediaConfig` default a project sets
once, and every one of them can be overridden for a single `DwMedia.open()` call with a
`DwMediaOpenOptions` — a project can run a lecture queue with resume and a countdown next to a
short-clip feed with neither, off one shared default.

| Knob | Default | What it does |
|---|---|---|
| `autoplayOnOpen` | `false` | `open()` starts playing the first item immediately |
| `autoplayNext` | `false` | reaching the end of an item advances the queue |
| `autoplayCountdown` | `true` | shows a counting-down number before autoplay fires (ignored unless `autoplayNext` is also on) |
| `autoplayCountdownDuration` | 5 s | how long that countdown runs |
| `nextPreview` | `false` | the queue reports "next item is coming up" ahead of time — independent of `autoplayNext` |
| `nextPreviewLeadTime` | 10 s | how long before the end the preview becomes visible |
| `completedThreshold` | `0.9` | fraction of the duration at which `onCompleted` fires |
| `reachedEndTolerance` | 500 ms | how close to the duration a still-playing tick counts as "reached the end", on top of the engine's own event; `Duration.zero` disables the leniency |
| `progressInterval` | 1 s | how often `onProgress` may fire |
| `resume` | on, its own defaults | resume policy, or `null` to turn resume off entirely |
| `resume.saveInterval` | 5 s | how often the position is saved while playing |
| `resume.minimum` | 5 s | a position under this is never saved |
| `resume.clearPastFraction` | `0.9` | past this fraction the saved position is cleared, not updated |
| `resume.saveOnLifecycleEvents` | `true` | also save immediately on pause, background, and dispose |
| `speeds` | `[]` | speeds a controls widget may offer; empty turns the speed control off |
| `defaultSpeed` | `1.0` | the speed a freshly opened item starts at |
| `rememberSpeedAcrossItems` | `true` | the chosen speed carries to the next item in the queue |
| `skipBack` / `skipForward` | 10 s each | how far `session.skipBack`/`skipForward` move |
| `fullscreen` | `true` | whether `showDwMediaFullscreen`/the mini-player's expand may push the fullscreen route at all |
| `fullscreenOrientations` | landscape (both) | orientations allowed while fullscreen; empty leaves the platform default |
| `exitOrientations` | portrait up | orientations restored on leaving fullscreen; empty leaves whatever was set before untouched |
| `autoEnterFullscreenOnPlay` | `false` | starting playback of a video enters fullscreen on its own |
| `keepFullscreenAcrossItems` | `true` | the queue advancing while fullscreen keeps fullscreen open |
| `miniPlayer` | `true` | whether a minimized session is offered to `DwMiniPlayerHost` at all |
| `miniPlayerInitialSize` | 160×90 | its starting size |
| `miniPlayerInitialAlignment` | bottom-right | its starting position |
| `miniPlayerMinScale` / `maxScale` | 0.5 / 1.5 | pinch-to-scale bounds |
| `miniPlayerSnapToEdges` | `true` | dragging snaps horizontally to the nearest edge on release |
| `miniPlayerCloseStopsPlayback` | `true` | closing the mini-player stops the session; off only pauses and hides it |
| `pauseVideoInBackground` | `true` | video pauses when the app goes to the background |
| `backgroundAudio` | `false` | audio keeps playing when the app goes to the background |
| `wakelockWhilePlaying` | `true` | the screen is kept awake while a video plays |
| `singleActiveItem` | `true` | opening/playing a session pauses whatever else was active |
| `webMutedStart` | `true` | a web video starts muted, unmuted once playback is granted |
| `webRememberSoundChoice` | `true` | the sound choice carries across items in the same session |
| `autoRetryCount` | `0` | how many times a load failure retries itself before surfacing `DwMediaPlayState.error` |
| `autoRetryDelay` | 3 s | the delay between automatic retries |
| `controlsAutoHideDelay` | 3 s | published on the resolved options for a controls widget's own auto-hide timer — the package starts no timer itself |
| `positionStore` | in-memory | where resume positions are kept; pass one backed by `dw.plugins.prefs` or a project's own storage to resume across launches |

## Testing

`dartway_media_flutter/testing.dart` ships `DwFakeVideoPlayerPlatform` and `DwFakeJustAudioPlatform`
— assign them to `VideoPlayerPlatform.instance`/`JustAudioPlatform.instance` in `setUp` to drive
`DwMediaController` in a widget test without a real plugin on any platform. Each exposes the one
distinction the reached-end guard depends on as two explicit calls: `emitCompleted` (the engine's
real end-of-playback signal) versus driving a plain `seek` to the duration (which flips
`isCompleted`/reaches `ProcessingState.completed` on its own, without the fake doing anything) —
so a project's own regression test for "a scrub must not count as the end" is one line.

## Not now

OS picture-in-picture, lock-screen/notification controls, HLS/quality/subtitles, and offline files
(with `dartway_offline` when it returns, dartway/dartway#262).
