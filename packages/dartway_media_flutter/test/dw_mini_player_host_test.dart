import 'package:dartway_media_flutter/dartway_media_flutter.dart';
import 'package:dartway_media_flutter/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

void main() {
  late DwFakeVideoPlayerPlatform fake;

  setUp(() {
    fake = DwFakeVideoPlayerPlatform();
    VideoPlayerPlatform.instance = fake;
  });

  DwMediaItem item(String id) => DwMediaItem(
    id: id,
    kind: DwMediaKind.video,
    source: DwMediaSource.url('https://example.com/$id.mp4'),
  );

  Widget hostApp(DwMediaSessionManager manager, {DwMediaItem? expanded}) => MaterialApp(
    home: Stack(
      children: [
        const SizedBox.expand(),
        DwMiniPlayerHost(
          sessionManager: manager,
          onExpand: (item) {},
          builder: (context, session, expand, close) => GestureDetector(
            onTap: expand,
            child: Container(
              key: const Key('mini-player-chrome'),
              color: const Color(0xFF000000),
              child: IconButton(
                key: const Key('mini-player-close'),
                icon: const Icon(Icons.close),
                onPressed: close,
              ),
            ),
          ),
        ),
      ],
    ),
  );

  testWidgets('hidden until a session is both active and minimized', (tester) async {
    final manager = DwMediaSessionManager(config: const DwMediaConfig());
    await tester.pumpWidget(hostApp(manager));
    expect(find.byKey(const Key('mini-player-chrome')), findsNothing);

    final session = manager.open(items: [item('a')]);
    await tester.pump();
    expect(find.byKey(const Key('mini-player-chrome')), findsNothing, reason: 'active but not minimized');

    session.minimize();
    await tester.pump();
    expect(find.byKey(const Key('mini-player-chrome')), findsOneWidget);
    await session.dispose();
  });

  testWidgets('miniPlayer: false never shows it even when minimized', (tester) async {
    final manager = DwMediaSessionManager(config: const DwMediaConfig(miniPlayer: false));
    await tester.pumpWidget(hostApp(manager));
    final session = manager.open(items: [item('a')]);
    session.minimize();
    await tester.pump();
    expect(find.byKey(const Key('mini-player-chrome')), findsNothing);
    await session.dispose();
  });

  testWidgets('tapping the chrome calls expand and restores the session', (tester) async {
    DwMediaItem? expandedItem;
    final manager = DwMediaSessionManager(config: const DwMediaConfig());
    await tester.pumpWidget(MaterialApp(
      home: Stack(
        children: [
          const SizedBox.expand(),
          DwMiniPlayerHost(
            sessionManager: manager,
            onExpand: (item) => expandedItem = item,
            builder: (context, session, expand, close) => GestureDetector(
              onTap: expand,
              child: Container(key: const Key('mini-player-chrome')),
            ),
          ),
        ],
      ),
    ));
    final session = manager.open(items: [item('a')]);
    session.minimize();
    await tester.pump();

    await tester.tap(find.byKey(const Key('mini-player-chrome')));
    await tester.pump();

    expect(expandedItem?.id, 'a');
    expect(session.minimized.value, isFalse);
    await session.dispose();
  });

  testWidgets('miniPlayerCloseStopsPlayback true: close disposes the session', (tester) async {
    final manager = DwMediaSessionManager(
      config: const DwMediaConfig(miniPlayerCloseStopsPlayback: true),
    );
    await tester.pumpWidget(hostApp(manager));
    final session = manager.open(items: [item('a')]);
    session.minimize();
    await tester.pump();

    await tester.tap(find.byKey(const Key('mini-player-close')));
    await tester.pump();

    expect(session.isDisposed, isTrue);
    expect(find.byKey(const Key('mini-player-chrome')), findsNothing);
  });

  testWidgets('miniPlayerCloseStopsPlayback false: close only hides it', (tester) async {
    final manager = DwMediaSessionManager(
      config: const DwMediaConfig(miniPlayerCloseStopsPlayback: false),
    );
    await tester.pumpWidget(hostApp(manager));
    final session = manager.open(items: [item('a')]);
    session.minimize();
    await tester.pump();

    await tester.tap(find.byKey(const Key('mini-player-close')));
    await tester.pump();

    expect(session.isDisposed, isFalse);
    expect(find.byKey(const Key('mini-player-chrome')), findsNothing);
    await session.dispose();
  });
}
