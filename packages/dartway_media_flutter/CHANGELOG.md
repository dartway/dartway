## 0.1.0

- First version (D-107): `DwMedia` (`dw.plugins.media`), `DwMediaSession` and its manager, one
  `DwMediaController` over `video_player` and `just_audio`, `DwMediaSource.resolve` re-called on
  retry, real-playback guards for `onStarted` and `onReachedEnd`, a queue with preview and autoplay
  countdown, resume through `DwMediaPositionStore`, `DwMediaFullscreenHost` and its route,
  `DwMiniPlayerHost`, `DwVideoSurface`, and the fakes of `testing.dart`. Every behaviour is a
  `DwMediaConfig` setting with a per-session `DwMediaOpenOptions` override — see
  `docs/3-flutter/media.md`.
