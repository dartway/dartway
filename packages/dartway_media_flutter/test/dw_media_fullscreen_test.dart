import 'package:dartway_media_flutter/dartway_media_flutter.dart';
import 'package:dartway_media_flutter/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

void main() {
  late DwFakeVideoPlayerPlatform fake;
  late List<MethodCall> platformCalls;

  setUp(() {
    fake = DwFakeVideoPlayerPlatform();
    VideoPlayerPlatform.instance = fake;
    platformCalls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      platformCalls.add(call);
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  List<String> orientationCalls() => [
    for (final call in platformCalls)
      if (call.method == 'SystemChrome.setPreferredOrientations') call.arguments.toString(),
  ];

  DwMediaSession buildSession({DwMediaConfig config = const DwMediaConfig()}) {
    final manager = DwMediaSessionManager(config: config);
    return manager.open(
      items: [
        DwMediaItem(id: 'v', kind: DwMediaKind.video, source: const DwMediaSource.url('https://example.com/v.mp4')),
      ],
    );
  }

  testWidgets('entering fullscreen pushes a route and locks the configured orientations', (tester) async {
    final session = buildSession(
      config: const DwMediaConfig(
        fullscreenOrientations: [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight],
        exitOrientations: [DeviceOrientation.portraitUp],
      ),
    );
    await tester.pump();
    fake.emitInitialized(fake.livePlayers.single, duration: const Duration(seconds: 10));
    await tester.pump();

    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => showDwMediaFullscreen(
            context,
            session: session,
            builder: (context) => const Text('fullscreen page'),
          ),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('fullscreen page'), findsOneWidget);
    expect(session.isFullscreen.value, isTrue);
    expect(orientationCalls(), isNotEmpty);
    expect(orientationCalls().last, contains('landscapeLeft'));

    session.exitFullscreen();
    await tester.pumpAndSettle();

    expect(find.text('fullscreen page'), findsNothing);
    expect(session.isFullscreen.value, isFalse);
    expect(orientationCalls().last, contains('portraitUp'));
    await session.dispose();
  });

  testWidgets('a back-gesture pop also restores orientation and clears isFullscreen', (tester) async {
    final session = buildSession(
      config: const DwMediaConfig(exitOrientations: [DeviceOrientation.portraitUp]),
    );
    await tester.pump();
    fake.emitInitialized(fake.livePlayers.single, duration: const Duration(seconds: 10));
    await tester.pump();

    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => showDwMediaFullscreen(
            context,
            session: session,
            builder: (context) => const Text('fullscreen page'),
          ),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final navigator = tester.state<NavigatorState>(find.byType(Navigator).last);
    navigator.pop();
    await tester.pumpAndSettle();

    expect(session.isFullscreen.value, isFalse);
    expect(orientationCalls().last, contains('portraitUp'));
    await session.dispose();
  });

  testWidgets('fullscreen off makes showDwMediaFullscreen a no-op', (tester) async {
    final session = buildSession(config: const DwMediaConfig(fullscreen: false));
    await tester.pump();
    fake.emitInitialized(fake.livePlayers.single, duration: const Duration(seconds: 10));
    await tester.pump();

    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => showDwMediaFullscreen(
            context,
            session: session,
            builder: (context) => const Text('fullscreen page'),
          ),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('fullscreen page'), findsNothing);
    expect(session.isFullscreen.value, isFalse);
    await session.dispose();
  });
}
