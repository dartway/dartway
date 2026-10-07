# dartway_media_flutter

Video and audio for a DartWay app, reached as `dw.plugins.media`: sessions owned by the plugin
that outlive the page that opened them, one engine per item over `video_player` and `just_audio`,
a queue with an autoplay countdown, resume, a fullscreen route and a mini-player host. Every
behaviour is a `DwMediaConfig` setting, overridable per session with `DwMediaOpenOptions`.

Mechanism only — no `chewie`, no colours, no text, no controls. The default controls (play/pause,
timeline, speed, fullscreen, next-item card, mini-player look, error with retry) are source in the
framework's `example/dartway_example_flutter/lib/ui_kit/3_special/media/`, copied into a project's
own `ui_kit/` and restyled — the `dartway-media` toolkit skill walks through it.

`package:dartway_media_flutter/testing.dart` fakes both platforms for a project's widget tests.

Documentation, with the table of every setting: `docs/3-flutter/media.md`.

Optional confirmed-playback accounting exports `DwMediaPlayedInterval`,
`DwMediaIntervalAccumulator` and immutable `DwMediaPlaybackReport`. Configure
`playbackDelivery`, capture `session.playbackObservation` before a span, and record
only an interval your caller can independently confirm. Position/progress callbacks
never record coverage automatically. `flushPlayback()` seals a window; the manager
retains failed/in-flight reports for inspection and explicit retry, independently of
engine disposal. Successful delivery acknowledges only that report. Retention is
in memory for the manager's lifetime; project adapters own persistence and policy.
