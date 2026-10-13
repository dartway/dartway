## 0.3.0-dev.0

- Preserve typed browser refusal/cancellation during owned surface restoration,
  serialize a newer user play behind its pending promise, and detach ownership
  before native cleanup without resetting foreign video controllers.

- Web video surfaces restore one browser pause caused by handing an already
  started video to another surface, including a mini-player or fullscreen view.
  The same controller and source stay live. User/background pauses, playback
  errors and autoplay refusals are respected; position ticks never replay.

- **Breaking** (#555): playback intent owns play/pause; buffering and unconfirmed
  play use `waiting` instead of `DwMediaPlayState.buffering`/`isBuffering`.
  `togglePlay()` uses intent and redundant play commands do nothing. Playing an
  ended item restarts at zero. Intent survives source retries.
- Seeks publish their target immediately, ignore stale ticks and coalesce to one
  active seek plus the latest queued target. Skips use the displayed position.
  Video position reads overlapping a seek are dropped, including reads started
  during a held seek and completed after it settles.
  Seeking away from an ended item clears the ended state immediately; play while
  that seek is pending resumes at its target instead of restarting at zero.
- **Breaking**: remove the manual observation handle and result. The package
  confirms spans from real playback and seals them through `playbackDelivery` on
  pause, seek, speed, source, error or end. Waiting does not break continuity;
  pending delivery and explicit retry keep their existing lifecycle.
- Audio coverage follows ready, playing position ticks on every platform. A
  refused web play can therefore credit the short interval before the browser's
  refusal arrives; `just_audio_web` exposes no separate positive start signal.
  Refusal stops playback but does not retract delivered coverage. Audio seeks
  settle only when the platform seek completes.
- Add `session.status`, `session.position` and `session.hasReallyPlayed`;
  `playback` remains their merge. Video surfaces rebuild only for size changes.
  Example controls follow intent, waiting and pending seek positions.
- Test fakes can hold seek completion or a position read and expose play/seek
  calls.
- Migration: `docs/migrations/2026-10-11-media-player-state.md`.
- Dependency carets follow DartWay 0.22 and its satellites on their next
  development lines; public dependency types follow those releases (#530).

## 0.2.0

- Optional explicit confirmed-playback intervals: sorted union and unique covered
  duration, session/source-bound observation handles, and immutable reports.
  Progress and seek position changes never infer coverage. Known playback/command
  boundaries invalidate handles; callers must confirm platform discontinuities.
- `playbackDelivery` seals windows into manager-owned pending batches. In-flight
  retry joins one attempt; failures retain the same payload for explicit retry;
  acknowledgement removes only that batch. Engine disposal never awaits delivery.
  No persistence or lesson-completion policy; unconfigured sessions record nothing.

- **Breaking** (#425): the mini-player stays where it is released — `miniPlayerSnapToEdges` now
  defaults to `false` (snapping is kept, opt-in). Its size is a width with the height from the
  video's aspect ratio: `miniPlayerInitialSize` became `miniPlayerInitialWidth` (240), and the
  pinch bounds `miniPlayerMinScale`/`miniPlayerMaxScale` became `miniPlayerMinWidth` (160) and
  `miniPlayerMaxWidthFraction` (0.6 of the viewport). Migration: `docs/migrations/2026-10-03-mini-player-free-placement-and-width.md`.
- `DwMiniPlayerHost` resizes by a handle in the corner opposite the one the player is anchored to,
  while a mouse or a hovering stylus is connected (`miniPlayerResize`: `pointer`, `always`, `never`;
  `miniPlayerResizeHandleExtent`), keeping the aspect ratio and the anchored corner; the pinch
  stays. `DwMiniPlayerHost.resizeCornerOf(context)` tells the chrome where the handle is.
- The player is held inside the visible area (the viewport less the system padding); a shrinking
  window pushes it in without forgetting where it was put or how wide, and both come back when
  the window grows; a gesture that only moves the player keeps the chosen width.
- The resize handle carries semantics (increase/decrease step the width; its label is
  `DwMiniPlayerHost.resizeHandleLabel`; a step that would change nothing is not offered), and the
  resize cursor shows over the whole player, chrome buttons included, while a resize runs.
- `DwMediaSessionManager.open()` is safe from `initState` and a build (#377): it returns the
  session at once, and writes what existing listeners hear — `active`, the claim of `autoplayOnOpen`
  that pauses other sessions under `singleActiveItem`, a reused session's queue, engine settings
  and play — once the tree is unlocked, so a `DwMiniPlayerHost` mounted earlier no longer throws
  "setState() called during build". Outside a build all of it still happens at once.

## 0.1.0

- First version (D-107): `DwMedia` (`dw.plugins.media`), `DwMediaSession` and its manager — one
  engine per item over `video_player` and `just_audio`, reached only through the session;
  `DwMediaSource.resolve` re-called on retry; real-playback guards for `onStarted`,
  `onReachedEnd` and autoplay; a queue with preview and an autoplay countdown; resume through
  `DwMediaPositionStore`; background rules that stop playing, buffering, pending and counting-down
  items; session-owned controls visibility; `DwMediaFullscreenHost`, `DwMiniPlayerHost`,
  `DwVideoSurface`; and the fakes of `testing.dart`. Every behaviour is a `DwMediaConfig` setting
  with a per-session `DwMediaOpenOptions` override — see `docs/3-flutter/media.md`.
