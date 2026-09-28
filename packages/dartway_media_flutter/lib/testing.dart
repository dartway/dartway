/// Test support for a project that uses `dartway_media_flutter` — fakes of
/// the `video_player` and `just_audio` platforms, so a widget test drives
/// `DwMediaController` without a plugin registered for any real platform.
///
/// ```dart
/// setUp(() {
///   DwFakeVideoPlayerPlatform.install();
///   DwFakeJustAudioPlatform.install();
/// });
/// ```
///
/// Inside `testWidgets`, let the engines finish with `dwSettleMedia(tester)`
/// where a bare `pump` would leave an audio item loading.
library;

export 'testing/dw_fake_just_audio_platform.dart';
export 'testing/dw_fake_video_player_platform.dart';
export 'testing/dw_settle_media.dart';
