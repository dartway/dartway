## 0.1.0

- First version (D-107): `DwMedia` (`dw.plugins.media`), `DwMediaSession` and its manager — one
  engine per item over `video_player` and `just_audio`, reached only through the session;
  `DwMediaSource.resolve` re-called on retry; real-playback guards for `onStarted`,
  `onReachedEnd` and autoplay; a queue with preview and an autoplay countdown; resume through
  `DwMediaPositionStore`; background rules that stop playing, buffering, pending and counting-down
  items; session-owned controls visibility; `DwMediaFullscreenHost`, `DwMiniPlayerHost`,
  `DwVideoSurface`; and the fakes of `testing.dart`. Every behaviour is a `DwMediaConfig` setting
  with a per-session `DwMediaOpenOptions` override — see `docs/3-flutter/media.md`.
