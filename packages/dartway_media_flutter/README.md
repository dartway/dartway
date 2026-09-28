# dartway_media_flutter

Video and audio for a DartWay app, reached as `dw.plugins.media`: one controller over
`video_player` and `just_audio`, sessions owned by the plugin that outlive the page that opened
them, a queue with an autoplay countdown, resume, a fullscreen route and a mini-player host. Every
behaviour is a `DwMediaConfig` setting, overridable per session with `DwMediaOpenOptions`.

Mechanism only — no `chewie`, no colours, no text, no controls. The default controls (play/pause,
timeline, speed, fullscreen, next-item card, mini-player look, error with retry) are source in the
framework's `example/dartway_example_flutter/lib/ui_kit/3_special/media/`, copied into a project's
own `ui_kit/` and restyled — the `dartway-media` toolkit skill walks through it.

`package:dartway_media_flutter/testing.dart` fakes both platforms for a project's widget tests.

Documentation, with the table of every setting: `docs/3-flutter/media.md`.
