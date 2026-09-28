/// Test support for a project that uses `dartway_media_flutter` — fakes of
/// the `video_player` and `just_audio` platforms, so a widget test drives
/// `DwMediaController` without a plugin registered for any real platform.
///
/// ```dart
/// setUp(() {
///   VideoPlayerPlatform.instance = DwFakeVideoPlayerPlatform();
///   JustAudioPlatform.instance = DwFakeJustAudioPlatform();
/// });
/// ```
library;

export 'testing/dw_fake_just_audio_platform.dart';
export 'testing/dw_fake_video_player_platform.dart';
