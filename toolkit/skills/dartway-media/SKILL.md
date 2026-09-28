---
name: dartway-media
description: >-
  Video/audio playback in a DartWay project: the plugin `DwMedia` (`dartway_media_flutter`,
  `dw.plugins.media`) with `DwMediaConfig`/`DwMediaOpenOptions`, `DwMediaItem`/`DwMediaSource`,
  opening a queue with `DwMedia.open(...)`, `DwMediaSession` (play/pause/seek/skip/setSpeed/
  setVolume/setMuted/retry, next/previous/jumpTo, fullscreen, minimize/restore),
  `DwVideoSurface`, `showDwMediaFullscreen`, `DwMiniPlayerHost`. **The package ships no controls** —
  play/pause, the timeline, speed, fullscreen, the next-item card, mini-player chrome and the error
  state with retry live as the project's own widgets, copied from `example/` and restyled. Use when
  a feature plays a video or an audio track, when a project needs a mini-player or a queue, or when
  a player's error, resume or background behaviour needs tuning.
---

# DartWay — media playback (`dartway-media`)

**Mechanism in the package, look in the project.** `dartway_media_flutter` has no button, no
timeline, no colour — see `docs/3-flutter/ui-kit.md`. The default controls a project actually
shows are `example/dartway_example_flutter/lib/ui_kit/3_special/media/`: read them end to end
before writing a feature, then copy the ones the project needs into `__FLUTTER_PKG__/lib/ui_kit/3_special/media/`
and restyle from there — they become the project's code the moment they are copied, same as the
rest of the kit (`dartway-ui-kit`).

The framework's own page is `docs/3-flutter/media.md` — the knob table there is the source of
truth for every default; this skill does not repeat it.

## 1. Add the package and declare the plugin — `__FLUTTER_PKG__`

```bash
flutter pub add dartway_media_flutter
```

```dart
dw = DwFlutterToolbox(
  plugins: [
    DwMedia(
      config: DwMediaConfig(
        speeds: [1.0, 1.25, 1.5, 2.0],   // empty (the default) turns the speed control off
        resume: const DwMediaResumePolicy(),
        // ... every other knob is docs/3-flutter/media.md's table, not repeated here
      ),
    ),
  ],
);
```

**A project that plays nothing does not add this package at all** — that is the whole point of it
being a plugin rather than a `DwFlutterConfig` field, and why the template does not ship it.

## 2. Open a queue and read state

```dart
final session = dw.plugins.media.open(
  items: [
    DwMediaItem(id: lesson.id, kind: DwMediaKind.video, source: DwMediaSource.resolve(fetchFreshUrl)),
  ],
  callbacks: DwMediaCallbacks(
    onCompleted: (item) => dw.plugins.analytics.track(LessonEvent.videoCompleted, {'lessonId': item.id}),
    onError: (item, error) => dw.handleError(error, StackTrace.current),
  ),
  options: const DwMediaOpenOptions(autoplayOnOpen: true),   // per-open override, see below
);
```

- **`DwMediaSource.resolve(fetchFreshUrl)`, not `.url(...)`, for anything time-limited** — a signed
  link that can expire. The resolver runs again on `retry()`, so an expired link recovers instead
  of dead-ending the player (`dartway/molodey#128`).
- **Callbacks are supplied once, at `open()`**, not per item — they cover the whole queue.
  `onItemChanged` fires when the queue advances; `onStarted`/`onProgress`/`onReachedEnd`/
  `onCompleted`/`onError` are about whichever item is current.
- **A session survives the widget that opened it.** Hold the `DwMediaSession` outside a
  `State.dispose` boundary (a controller/provider your screen and the mini-player both reach), not
  as a local variable of one page — that is what lets the mini-player and fullscreen keep playing
  through navigation.
- **Every knob is overridable per `open()`** with `DwMediaOpenOptions` — a project that wants
  resume and a countdown for lectures and neither for short clips passes one `DwMediaConfig`
  default and overrides per call, never two configs.

## 3. Controls widgets — copy, don't import

Build your own over `DwMediaController`/`DwMediaSession`, reading `session.controller.state`
(`ValueListenable<DwMediaPlaybackState>`) and `session.queue`
(`ValueListenable<DwMediaQueueState>`) with `ValueListenableBuilder`/`ListenableBuilder` — the
package exposes state this way rather than as riverpod providers, because a session's identity is
created at `open()` time, not declared once like `dw.plugins.prefs.provider(...)`.

What to copy from `example/.../ui_kit/3_special/media/` and restyle:

| Widget | Reads |
|---|---|
| Play/pause | `state.playState`, calls `session.play`/`session.pause` |
| Timeline (scrub + buffered range) | `state.position`/`duration`/`buffered`, calls `session.seek` |
| Skip ±  | calls `session.skipBack`/`skipForward` (their durations are `options.skipBack`/`skipForward`) |
| Speed | `session.options.speeds` (hidden when empty), calls `session.setSpeed` |
| Mute | `state.muted`, calls `session.setMuted` |
| Fullscreen | calls `showDwMediaFullscreen(context, session: session, builder: ...)` |
| Error + retry | `state.errorMessage`, calls `session.retry` |
| Next-item card | `session.queue.value.next`/`showNextPreview`/`autoplayCountdownSeconds` |
| Mini-player chrome | the `builder` given to `DwMiniPlayerHost` |

`DwVideoSurface(session: session)` is the one widget the package does ship pixels for — a plain
texture at the correct aspect ratio, deliberately with no chrome around it.

## 4. Mini-player — mounted once, at the app root

```dart
MaterialApp.router(
  builder: (context, child) => Stack(
    children: [
      if (child != null) child,
      DwMiniPlayerHost(
        sessionManager: dw.plugins.media.sessionManager,
        onExpand: (item) => context.go('/player/${item.id}'),   // the app's own route
        builder: (context, session, expand, close) => YourMiniPlayerChrome(
          session: session,
          onTap: expand,
          onClose: close,
        ),
      ),
    ],
  ),
)
```

`DwMiniPlayerHost` decides *whether* to show it (`session.minimized` and `options.miniPlayer`) and
the drag/scale/snap mechanics; it has no opinion on where `expand` navigates to, or what the
chrome looks like.

## 5. Platform configuration

- **`options.backgroundAudio: true`** needs, additionally: iOS — `UIBackgroundModes` with `audio`
  in `Info.plist`; Android — nothing extra (a foreground playback session is enough for
  `just_audio` without a background service). Without this, audio still pauses on background
  regardless of the flag, and the failure looks like the flag doing nothing.
- **Fullscreen orientations** (`options.fullscreenOrientations`/`exitOrientations`) need no platform
  config — they go through `SystemChrome`, already available.
- **Web**: nothing to add; `options.webMutedStart`/`webRememberSoundChoice` are handled entirely in
  Dart.

## 6. Tests

```dart
setUp(() {
  VideoPlayerPlatform.instance = DwFakeVideoPlayerPlatform();
  JustAudioPlatform.instance = DwFakeJustAudioPlatform();
});
```

(`import 'package:dartway_media_flutter/testing.dart';`) — drives `DwMediaController` without a
real plugin on any platform. `fake.emitInitialized`/`emitCompleted` (video) and
`player.emitCompleted`/`emitPosition` (audio, via `fake.players`) are the engine's *real*
end-of-playback signals; `session.seek(duration)` is a scrub, which must never fire
`onReachedEnd` on its own — if a test needs to prove a fix around the end of playback, drive it
through one of these two paths deliberately, not through position alone. See
`packages/dartway_media_flutter/test/` in the framework repository for the full set, including one
test per config knob turning its behaviour on and off.
