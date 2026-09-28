/// Test support for an app that uses `dartway_media_flutter`: stand-ins for
/// the `video_player` and `just_audio` platforms, so a widget test plays
/// items without a plugin for any platform.
///
/// ```dart
/// late DwFakeVideoPlayerPlatform video;
///
/// setUp(() {
///   video = DwFakeVideoPlayerPlatform.install();
///   DwFakeJustAudioPlatform.install();
/// });
///
/// // real playback:  video.latest.advanceTo(const Duration(seconds: 3));
/// // a scrub:        await session.seek(const Duration(seconds: 3));
/// // the real end:   video.latest.finish();
/// ```
///
/// Inside `testWidgets`, let the engines finish with `dwSettleMedia(tester)`
/// where a bare `pump` would leave an audio item loading.
library;

export 'testing/dw_fake_audio.dart';
export 'testing/dw_fake_video.dart';
export 'testing/dw_settle_media.dart';
