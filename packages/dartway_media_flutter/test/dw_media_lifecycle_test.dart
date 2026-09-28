import 'package:dartway_media_flutter/dartway_media_flutter.dart';
import 'package:dartway_media_flutter/testing.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

void main() {
  late DwFakeVideoPlayerPlatform fakeVideo;
  late DwFakeJustAudioPlatform fakeAudio;

  setUp(() {
    fakeVideo = DwFakeVideoPlayerPlatform();
    VideoPlayerPlatform.instance = fakeVideo;
    fakeAudio = DwFakeJustAudioPlatform();
    JustAudioPlatform.instance = fakeAudio;
  });

  void sendLifecycle(AppLifecycleState state) {
    TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(state);
  }

  testWidgets('pauseVideoInBackground pauses a playing video on paused/hidden/detached', (tester) async {
    final media = DwMedia(config: const DwMediaConfig());
    final item = DwMediaItem(id: 'v', kind: DwMediaKind.video, source: const DwMediaSource.url('https://example.com/v.mp4'));
    final session = media.open(items: [item]);
    await tester.pump();
    fakeVideo.emitInitialized(fakeVideo.livePlayers.single, duration: const Duration(seconds: 60));
    await tester.pump();
    await session.play();
    await tester.pump();
    expect(session.controller.state.value.isPlaying, isTrue);

    sendLifecycle(AppLifecycleState.paused);
    await tester.pump();
    expect(session.controller.state.value.isPlaying, isFalse);
    await media.dispose();
  });

  testWidgets('inactive is ignored — it does not pause', (tester) async {
    final media = DwMedia(config: const DwMediaConfig());
    final item = DwMediaItem(id: 'v', kind: DwMediaKind.video, source: const DwMediaSource.url('https://example.com/v.mp4'));
    final session = media.open(items: [item]);
    await tester.pump();
    fakeVideo.emitInitialized(fakeVideo.livePlayers.single, duration: const Duration(seconds: 60));
    await tester.pump();
    await session.play();
    await tester.pump();

    sendLifecycle(AppLifecycleState.inactive);
    await tester.pump();
    expect(session.controller.state.value.isPlaying, isTrue);
    await media.dispose();
  });

  testWidgets('pauseVideoInBackground off keeps video playing in the background', (tester) async {
    final media = DwMedia(config: const DwMediaConfig(pauseVideoInBackground: false));
    final item = DwMediaItem(id: 'v', kind: DwMediaKind.video, source: const DwMediaSource.url('https://example.com/v.mp4'));
    final session = media.open(items: [item]);
    await tester.pump();
    fakeVideo.emitInitialized(fakeVideo.livePlayers.single, duration: const Duration(seconds: 60));
    await tester.pump();
    await session.play();
    await tester.pump();

    sendLifecycle(AppLifecycleState.paused);
    await tester.pump();
    expect(session.controller.state.value.isPlaying, isTrue);
    await media.dispose();
  });

  testWidgets('backgroundAudio off pauses audio in the background (the default)', (tester) async {
    final media = DwMedia(config: const DwMediaConfig());
    final item = DwMediaItem(id: 'a', kind: DwMediaKind.audio, source: const DwMediaSource.url('https://example.com/a.mp3'));
    final session = media.open(items: [item]);
    await tester.pump();
    await tester.pump();
    await session.play();
    await tester.pump();
    expect(session.controller.state.value.isPlaying, isTrue);

    sendLifecycle(AppLifecycleState.hidden);
    await tester.pump();
    expect(session.controller.state.value.isPlaying, isFalse);
    await media.dispose();
  });

  testWidgets('backgroundAudio on keeps audio playing in the background', (tester) async {
    final media = DwMedia(config: const DwMediaConfig(backgroundAudio: true));
    final item = DwMediaItem(id: 'a', kind: DwMediaKind.audio, source: const DwMediaSource.url('https://example.com/a.mp3'));
    final session = media.open(items: [item]);
    await tester.pump();
    await tester.pump();
    await session.play();
    await tester.pump();

    sendLifecycle(AppLifecycleState.paused);
    await tester.pump();
    expect(session.controller.state.value.isPlaying, isTrue);
    await media.dispose();
  });
}
