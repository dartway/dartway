# dartway_media_flutter

A video/audio player for a DartWay app, reached as `dw.plugins.media`: one `DwMediaController` API
over `video_player` and `just_audio`, a `DwMediaSession` that survives route changes (so the
mini-player and fullscreen keep playing without a reload), a queue with resume, and a mini-player
host — mechanism only, no `chewie`, no colours, no built-in controls.

The default controls (play/pause, timeline, speed, fullscreen, next-item card, mini-player chrome,
error with retry) live as source in `example/dartway_example_flutter/lib/ui_kit/3_special/media/`,
copied into a project's own `ui_kit/` and restyled — see the `dartway-media` toolkit skill.

Documentation: `docs/3-flutter/media.md`.
