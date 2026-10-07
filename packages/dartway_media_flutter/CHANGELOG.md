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

## 0.1.0

- First version (D-107): `DwMedia` (`dw.plugins.media`), `DwMediaSession` and its manager — one
  engine per item over `video_player` and `just_audio`, reached only through the session;
  `DwMediaSource.resolve` re-called on retry; real-playback guards for `onStarted`,
  `onReachedEnd` and autoplay; a queue with preview and an autoplay countdown; resume through
  `DwMediaPositionStore`; background rules that stop playing, buffering, pending and counting-down
  items; session-owned controls visibility; `DwMediaFullscreenHost`, `DwMiniPlayerHost`,
  `DwVideoSurface`; and the fakes of `testing.dart`. Every behaviour is a `DwMediaConfig` setting
  with a per-session `DwMediaOpenOptions` override — see `docs/3-flutter/media.md`.
