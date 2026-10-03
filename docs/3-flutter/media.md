# Video and audio: what does the package do, and what does the project draw?

`dartway_media_flutter` is the player every DartWay app builds on, reached as `dw.plugins.media`:
one controller over `video_player` and `just_audio`, sessions that outlive the page that opened
them, a queue, resume, fullscreen and a mini-player.

**Mechanism only — no look.** The package has no button, no timeline, no colour and no text (see
[the UI kit](ui-kit.md)), and no `chewie`, which ships Material and Cupertino controls — a design
decision the package does not make. The controls an app shows are its own widgets: the default
set lives in `example/dartway_example_flutter/lib/ui_kit/3_special/media/`, and a project copies
it into its own `ui_kit/` and restyles it (the `dartway-media` toolkit skill walks through it). A
project that plays nothing does not add the package, and does not download `video_player`.

**Nothing is fixed policy.** Every behaviour below is a setting with a default on `DwMediaConfig`,
and every one can be overridden for a single session — see [every setting](#every-setting).

## Wiring

```dart
dw = DwFlutterCore(
  // ...
  plugins: [
    DwMedia(config: const DwMediaConfig(speeds: [1, 1.25, 1.5, 2], autoplayNext: true)),
  ],
);
```

```dart
final session = dw.plugins.media.open(
  items: [
    DwMediaItem(id: lesson.id, kind: DwMediaKind.video, title: lesson.title,
        source: DwMediaSource.resolve(() => fetchSignedUrl(lesson.id))),
  ],
  callbacks: DwMediaCallbacks(onCompleted: (item) => markWatched(item.id)),
  options: const DwMediaOpenOptions(autoplayOnOpen: true),
);
```

- **`DwMediaItem`** — one thing to play: a stable `id` (the queue's key, the resume key, "is this
  the item playing"), a `kind` (`video` or `audio`), a `DwMediaSource`, and `title`/`artworkUrl`/
  `extras` the package carries without reading.
- **`DwMediaSource.url(...)`** for a plain address, **`DwMediaSource.resolve(...)`** for anything
  that expires: the function is called on every load and again on every retry, so an expired
  signed link is fetched afresh instead of ending the player.
- **`DwMediaCallbacks`** are given once, at `open()`, and cover the whole queue: `onStarted`,
  `onProgress`, `onReachedEnd`, `onCompleted`, `onError`, `onItemChanged`.

## Sessions

`open()` returns a `DwMediaSession`: the queue, the engine of its current item, whether it is
fullscreen, minimized and showing its controls. **The plugin owns it, not the widget that opened
it** — pages come and go and the session plays on, which is what makes the mini-player and
fullscreen possible without a reload. The engine itself is not public: everything goes through the
session. It ends with `session.dispose()`, or with the mini-player's close.

- **One item, one engine.** `open()` for an item a live session stands on returns that session —
  the page coming back reattaches to what the mini-player shows instead of loading a second copy —
  and the new open's request applies to it: its callbacks replace the old ones (a page that is
  gone hears nothing more), its settings replace the old ones, a different queue replaces the old
  one around the same item with the engine kept, and `autoplayOnOpen` plays the item if it is
  paused or hidden. Three settings only a load applies stay as the item was loaded: the start speed
  (`defaultSpeed`), the web's muted start (`webMutedStart`), and the iOS half of
  `wakelockWhilePlaying` (`video_player`'s display-sleep option is fixed when its controller is
  created). The mini-player's initial size and position apply only before it first shows.
- `dw.plugins.media.sessionManager.active` is the session the mini-player shows: the one played
  last, or opened last while nothing plays — opening without autoplay never takes it from a playing
  session. Under `singleActiveItem`, playing a session pauses every other.
- **Nothing is left headless.** Closing the mini-player with `miniPlayerCloseStopsPlayback: false`
  pauses and hides the session: it stays reachable by opening its item again, and the next session
  opened for any other item ends it, so no engine outlives the moment it could still be reached.
  With `miniPlayer: false`, the page leaving (`minimize()`) does what `onLeaveWithoutMiniPlayer`
  says — pause, stop, or keep playing.
- A controls widget reads `session.playback` (the current item's `DwMediaPlaybackState`, following
  the queue), `session.queue` (`DwMediaQueueState`: the items, the current index, the next-item
  preview and the autoplay countdown), `session.isFullscreen`, `session.minimized` and
  `session.controlsVisible`, all `ValueListenable`s — a session is created at `open()`, so there is
  no provider to declare for it ahead of time. `session.options` carries the resolved settings a
  control reads (`speeds`, `fullscreen`).
- **Controls visibility is the session's.** `controlsVisible` is true while the item is not
  playing, and for `controlsAutoHideDelay` after playback starts or after `showControls()`;
  `toggleControls()` is what a tap on the picture calls. The controls themselves are the app's.
- Commands: `play`, `pause`, `seek`, `skipBack`, `skipForward`, `setSpeed` (only a speed from
  `speeds`; with the list empty it throws — the control is off), `setMuted`, `setVolume`, `retry`,
  `next`, `previous`, `jumpTo`, `cancelAutoplay`, `enterFullscreen`, `exitFullscreen`, `minimize`,
  `restore`, `showControls`, `hideControls`, `toggleControls`.
- The playback state is `loading`, `ready`, `buffering`, `playing`, `paused`, `ended` or `error`,
  with the position, duration, buffered position, speed, volume and mute. **An error stays inside
  the player**: the state turns `error`, `onError` fires, and `retry()` re-resolves the source and
  returns to where playback failed. A retry shows `loading` at once, and a tap while any load runs —
  the first one included — joins it rather than loading twice. A load that does not settle within `loadTimeout` fails the
  same way, so a joined retry can never hang; the load that overran is dropped, never joined.

## Real playback, not a position

Both engines report a seek to the end as "completed": `video_player` sets `isCompleted` on any seek
landing on the duration, and `just_audio` on Android reaches `completed` after a seek made while
paused. And `video_player` reports `isPlaying` the moment `play()` is called, before the platform
answers — a web `play()` the browser refused still reads as playing.

So the controller counts only **real playback**: the engine plays, no seek of its own is in
flight, and the position has moved past where playback started or the last seek landed.

- `onStarted` fires on the first real playback of an item — not on a refused `play()`.
- `onReachedEnd` fires when the engine turns "ended" after real playback since the last seek —
  never on a scrub to the end, a resume point near the end, or a completed event that arrives late
  after a paused seek. `reachedEndTolerance` lets a real tick just short of the end count too.
- Autoplay follows the same rule, every time rather than once: a seek clears a real end, so a
  scrub to the end after a real end, a cancelled countdown, or an end by tolerance never moves the
  queue; playing to the end again does.
- `onCompleted` is the other question — "watched enough" — and it fires when the position first
  crosses `completedThreshold`, by playback or by a seek. A project that counts a lesson as done
  when the member drags to the end listens to this one.
- `onProgress` and the periodic resume save run on real playback only.

## Queue, fullscreen, mini-player

- **Autoplay.** With `autoplayNext`, an item that really ended moves the queue on: at once, or after
  a countdown (`autoplayCountdown`) that `queue.autoplayCountdown` shows, updated every
  `autoplayCountdownTick`, and `cancelAutoplay()` stops. The move comes exactly at
  `autoplayCountdownDuration`, fractional or not. The next-item preview (`nextPreview`) is its own switch, independent of autoplay.
- **Fullscreen is a route of the package's own.** Wrap the inline player in
  `DwMediaFullscreenHost(session:, builder:, child:)`: whenever `session.isFullscreen` turns true —
  `enterFullscreen()`, `autoEnterFullscreenOnPlay`, already true when the page builds — it pushes
  the package's route drawing `builder` onto the root navigator, with `fullscreenTransitionDuration`
  and `fullscreenTransitionBuilder` (a fade by default). The route sets `fullscreenOrientations`
  and, only if it set any, `exitOrientations` when it goes; it leaves on `exitFullscreen()` or a
  back gesture alike, and the flag changes after the frame, so a page listening to it rebuilds
  safely. The route itself is not exported: the host is the one way in, so the flag and the route
  cannot disagree. **A request waits for its host**: `enterFullscreen()` or
  `autoEnterFullscreenOnPlay` before any host for the session is mounted — autoplay on open playing
  before the page has built, a call from the page's own `initState` — is kept, and the first host
  that mounts honours it; `isFullscreen` turns true only then. From the mini-player (the page has
  called `minimize()`) a request does nothing, rather than leave anything claiming fullscreen with
  no page to show it. The queue moving on keeps it up (`keepFullscreenAcrossItems`). System bars are
  the app's: its fullscreen page sets them if it wants them hidden.
- **The mini-player is mounted once, at the root** — `DwMiniPlayerHost(sessionManager:,
  builder:, onExpand:)` in `MaterialApp.builder`. It shows the active session while
  `session.minimized` is true; the
  `builder` draws it, and `onExpand(item)` navigates to the app's own player page — the package
  has no opinion on routes. The player page calls `session.minimize()` when it goes and
  `session.restore()` when it comes back, both safe from `initState`/`dispose`. It sits above the
  navigator, where there is no overlay: its buttons cannot carry tooltips.
- **The mini-player stays where it is let go.** A drag moves it inside the visible area — the
  viewport less the system padding — and it stays there; `miniPlayerSnapToEdges` settles it on an
  edge instead. A free player is what a person expects of a window they moved; snapping suits a
  phone layout that wants the content uncovered, and is one setting away. When the window shrinks
  the player is pushed in, but the place it was put is kept: growing the window brings it back.
- **Its size is a width**; the height follows the video's own aspect ratio, so the picture is never
  letterboxed or stretched — 240 wide at first, between 160 and 60 % of the viewport, so on a
  375 px phone it still resizes from 160 to 225. A pinch resizes it, and so — while a mouse, or a
  stylus that hovers, is connected (`miniPlayerResize: pointer`; Flutter's `MouseTracker` counts
  both) — does dragging the handle in the corner opposite the one it is
  anchored to: in the right half of the screen it is anchored right, so the handle is on its left,
  and the anchored corner stays put while the handle follows the pointer. A touch screen has no
  handle by default — a corner the size of a fingertip would swallow the chrome's buttons.
  Position and size live in the host, so they survive route changes and the player hiding and
  showing again. While a resize runs the cursor is the resize one over the whole player, its
  buttons included; outside the player it is not held. For a screen reader the handle's increase
  and decrease actions step the width by the same rule as the drag — an action that would change
  nothing is not offered; its label is the app's, `DwMiniPlayerHost(resizeHandleLabel:)`.
- **The chrome is the app's, handle included.** The host owns the handle's square (a press in it
  resizes and never reaches the chrome) and the cursor over it; the mark the person sees is drawn
  by the chrome, at `DwMiniPlayerHost.resizeCornerOf(context)` — `null` while there is no handle —
  which is also how the chrome keeps its own buttons off that corner. The example's chrome puts a
  scrim under its controls so they read over a light frame.
- `DwVideoSurface(session:)` draws the current video at its own aspect ratio — the one widget the
  package draws, a texture with no chrome.

## Background, the screen, the web

- On the app going to the background — `hidden`, `paused`, `detached`, **never `inactive`**, which a
  permission prompt or a system sheet raises too — positions are saved (`saveOnBackground`), and a
  video (`pauseVideoInBackground`), or audio unless `backgroundAudio` is on, is stopped whatever it
  was doing: playing, buffering, waiting to load to play, or counting down to the next item (the
  countdown is cancelled). Nothing starts in the background: `play()` and autoplay are refused
  there. Coming back resumes nothing on its own. `video_player`'s own background rule, which would pause and resume by
  itself, is switched off so that these settings decide.
- **Background audio needs the platform's permission too.** iOS: `audio` in `UIBackgroundModes` in
  `Info.plist`. Android: nothing to declare for playback with the screen locked while the app lives;
  a notification with controls and a foreground service are not part of the package.
- The screen stays on while a video plays (`wakelockWhilePlaying`), through `wakelock_plus` and,
  on iOS, `video_player`'s own option; two sessions playing at once share one lock, and a failed
  video lets it go.
- **The web.** A browser refuses to start sound without a gesture, so a video starts muted
  (`webMutedStart`) until the person turns the sound on; with `rememberSound`, that choice carries
  to every item after it. On the web only, and by the exact `DOMException` name `video_player_web`
  reports: a `play()` refused with `NotAllowedError` leaves the item paused, not in error, and an
  `AbortError` — a request the player itself superseded — is ignored. Everything else, and anything
  off the web, is an error state with `onError`. A failure `video_player` records in its own value
  carries only a message, and is an error too: `retry()` recovers it. An item's engine is released only after the frame that removed its video from the
  page — disposing a video still on the page throws in the browser.

## Every setting

Each row is a `DwMediaConfig` field with its default; each is overridden per session by the field
of the same name on `DwMediaOpenOptions` (`withoutResume: true` turns resume off for one session).
The package's tests cover every row, default against changed, in
`packages/dartway_media_flutter/test/dw_media_settings_*_test.dart`.

| Setting | Default | What it changes |
|---|---|---|
| `autoplayOnOpen` | `false` | `open()` plays the first item as soon as it loads |
| `autoplayNext` | `false` | an item that really ended moves the queue to the next one |
| `autoplayCountdown` | `true` | with `autoplayNext`, the move waits for a countdown; off, it is immediate |
| `autoplayCountdownDuration` | 5 s | how long that countdown is; the move comes exactly then |
| `autoplayCountdownTick` | 1 s | how often the countdown's remaining time updates; zero shows only the start |
| `nextPreview` | `false` | the queue announces the next item before the current one ends |
| `nextPreviewLeadTime` | 10 s | how long before the end the announcement comes |
| `completedThreshold` | `0.9` | the fraction of the duration at which `onCompleted` fires |
| `reachedEndTolerance` | 500 ms | how close to the end a real tick counts as the end; zero leaves only the engine's event |
| `progressInterval` | 1 s | the shortest gap between two `onProgress` calls |
| `speeds` | `[]` | the speeds `setSpeed` accepts and the controls offer; empty turns speed off and every item plays at `defaultSpeed` |
| `defaultSpeed` | `1.0` | the speed an item starts at; with `speeds` non-empty it must be one of them (asserted) |
| `rememberSpeedAcrossItems` | `true` | a chosen speed stays for the next items; off, each starts at `defaultSpeed` |
| `skipBack` / `skipForward` | 10 s / 10 s | how far `skipBack()` and `skipForward()` move |
| `singleActiveItem` | `true` | opening or playing a session pauses every other; off, several play at once |
| `autoRetryCount` | `0` | how many times a failed load retries itself before the error state |
| `autoRetryDelay` | 3 s | the wait before each of those retries |
| `loadTimeout` | 30 s | how long one load (resolving the source and opening it) may take before it is an error with `onError`; `null` — per open `withoutLoadTimeout: true` — waits for ever |
| `controlsAutoHideDelay` | 3 s | how long `controlsVisible` stays true while playing untouched; zero never hides |
| `resume` | `DwMediaResumePolicy()` | the resume policy; `null` reads and writes no positions |
| `resume.saveInterval` | 5 s | how often the position is saved during real playback |
| `resume.minimum` | 5 s | a position under this is never saved |
| `resume.clearPastFraction` | `0.9` | past this fraction the saved position is cleared, not updated |
| `resume.saveOnPause` | `true` | `pause()` saves |
| `resume.saveOnDispose` | `true` | ending the item or the session saves |
| `resume.saveOnBackground` | `true` | the app going to the background saves |
| `positionStore` | in memory | where positions live; pass one over `dw.plugins.prefs` or the project's storage to resume across launches |
| `pauseVideoInBackground` | `true` | a playing video pauses in the background |
| `backgroundAudio` | `false` | playing audio keeps playing in the background (platform setup above) |
| `wakelockWhilePlaying` | `true` | the screen stays on while a video plays |
| `webMutedStart` | `true` | on the web, a video starts muted until the person turns the sound on |
| `rememberSound` | `true` | the last mute choice carries to every item opened after it |
| `fullscreen` | `true` | whether a session may go fullscreen at all |
| `fullscreenOrientations` | both landscapes | orientations while fullscreen; empty leaves them alone |
| `exitOrientations` | portrait up | orientations set when fullscreen ends; empty allows every one |
| `autoEnterFullscreenOnPlay` | `false` | playing a video goes fullscreen |
| `keepFullscreenAcrossItems` | `true` | the queue moving on stays fullscreen; off, it leaves |
| `fullscreenTransitionDuration` | 200 ms | how long the fullscreen route takes to come and go |
| `fullscreenTransitionBuilder` | `null` (a fade) | the fullscreen route's transition |
| `fallbackAspectRatio` | 16 / 9 | the ratio `DwVideoSurface` keeps while a video reports no size |
| `miniPlayer` | `true` | whether `minimize()` hands the session to the mini-player |
| `miniPlayerInitialWidth` | 240 | the mini-player's width before any resize, held within the bounds below; the height follows the video's ratio |
| `miniPlayerInitialAlignment` | bottom right | where it first appears |
| `miniPlayerMinWidth` / `miniPlayerMaxWidthFraction` | 160 / 0.6 | resize bounds: a width in pixels, and a fraction of the viewport width (never under the minimum, never past the viewport) |
| `miniPlayerResize` | `pointer` | a pinch, plus a corner handle while a mouse or a hovering stylus is connected; `always` shows the handle on touch too, `never` turns resizing off |
| `miniPlayerResizeHandleExtent` | 32 | the side of the handle's square, in logical pixels |
| `miniPlayerSnapToEdges` | `false` | a released mini-player settles on an edge; off, it stays where it was released |
| `miniPlayerSnapEdges` | `horizontal` | which edges: the nearer side (`horizontal`) or the nearest of four (`all`) |
| `miniPlayerSnapThreshold` | infinite | how close to that edge, in logical pixels, it must be released to settle |
| `miniPlayerCloseStopsPlayback` | `true` | its close ends the session; off, it pauses and hides it (reachable by opening its item, ended by the next other open) |
| `onLeaveWithoutMiniPlayer` | `pause` | with `miniPlayer` off, what the page leaving does: `pause`, `stop` or `keepPlaying` |

## Testing

`package:dartway_media_flutter/testing.dart` plays items in a widget test without a plugin for any
platform:

```dart
late DwFakeVideoPlayerPlatform video;

setUp(() {
  video = DwFakeVideoPlayerPlatform.install();   // every video loads at once, a minute long
  DwFakeJustAudioPlatform.install();
});
```

- Every video opened is a `DwFakeVideo` in `video.videos` / `video.latest`: `advanceTo` is real
  playback (read on `video_player`'s next 100 ms poll), `finish` the platform's own end, `fail` a
  failure mid-play, `startBuffering` / `stopBuffering`, `refusePlayWith` / `refuseSeekWith` a
  refused command; `readyOnOpen: false` holds each load until the test calls `ready`.
- Every track is a `DwFakeAudio` in `tracks` / `latest`, with `advanceTo`, `finish` and `fail`; a
  seek to its end reports it completed, as Android does. `just_audio` finishes part of its work
  outside a widget test's fake clock, so after an audio command a test calls `dwSettleMedia(tester)`
  rather than `pump`.
- A scrub is a `session.seek(...)`; real playback is `advanceTo` after `play()`. A test of "a scrub
  to the end must not count" is those two lines apart.
- A playing video polls its position on a timer: end the sessions (`dw.plugins.media.dispose()`)
  before a test finishes.

## Not in the package

OS picture-in-picture, lock-screen and notification controls, HLS quality, subtitles, and offline
files (with `dartway_offline` when it returns, dartway/dartway#262).
