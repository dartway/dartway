import 'package:dartway_example_flutter/core/app_l10n.dart';
import 'package:dartway_example_flutter/core/dw_core.dart';
import 'package:dartway_example_flutter/ui_kit/ui_kit.dart';
import 'package:dartway_media_flutter/dartway_media_flutter.dart';
import 'package:dartway_media_flutter/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/example_test_app.dart';

void main() {
  late DwFakeVideoPlayerPlatform video;

  setUp(() {
    video = DwFakeVideoPlayerPlatform.install();
    DwFakeJustAudioPlatform.install();
  });

  const controls = Key('app-media-controls');
  const miniPlayer = Key('app-mini-player');

  DwMediaSession active() => dw.plugins.media.sessionManager.active.value!;

  /// Real playback of the current video up to [position].
  Future<void> playTo(WidgetTester tester, Duration position) async {
    video.setPosition(video.livePlayers.last, position);
    await tester.pump(const Duration(milliseconds: 100));
  }

  /// Ends every session before the app stops: a playing video polls its
  /// position on a timer that would outlive the test.
  Future<void> stop(WidgetTester tester, ExampleTestApp app) async {
    await app.run(tester, dw.plugins.media.dispose());
    await app.stop(tester);
  }

  testWidgets('a workout plays at the top of the page, its controls hide '
      'while it plays and come back on a tap', (tester) async {
    final app = await ExampleTestApp.start(tester, FakeClub());
    await app.tap(tester, find.text('Workouts').last);
    expect(find.byType(AppMediaPlayer), findsNothing);

    await app.tap(tester, find.text('Morning mobility'));
    await playTo(tester, const Duration(seconds: 1));
    expect(find.byType(AppMediaPlayer), findsOneWidget);
    expect(active().playback.value.isPlaying, isTrue);
    expect(find.byKey(controls), findsOneWidget);

    await tester.pump(dw.plugins.media.config.controlsAutoHideDelay);
    expect(find.byKey(controls), findsNothing);

    await tester.tap(find.byType(AppMediaPlayer));
    await tester.pump();
    expect(find.byKey(controls), findsOneWidget);

    await stop(tester, app);
  });

  testWidgets('the speed menu offers the speeds the app configured', (
    tester,
  ) async {
    final app = await ExampleTestApp.start(tester, FakeClub());
    await app.tap(tester, find.text('Workouts').last);
    await app.tap(tester, find.text('Morning mobility'));
    await tester.tap(find.byKey(const Key('app-media-speed')));
    await app.settle(tester);
    await app.tap(tester, find.text('1.5×').last);
    expect(active().playback.value.speed, 1.5);
    await stop(tester, app);
  });

  testWidgets('with no speeds configured the control bar has no speed menu, '
      'and with fullscreen off no fullscreen button', (tester) async {
    final app = await ExampleTestApp.start(tester, FakeClub());
    final session = dw.plugins.media.open(
      items: [workoutVideo('plain')],
      options: const DwMediaOpenOptions(speeds: [], fullscreen: false),
    );
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(body: AppMediaControlBar(session: session)),
      ),
    );
    await app.settle(tester);
    expect(find.byKey(const Key('app-media-play')), findsOneWidget);
    expect(find.byKey(const Key('app-media-speed')), findsNothing);
    expect(find.byKey(const Key('app-media-fullscreen')), findsNothing);
    await stop(tester, app);
  });

  testWidgets('a failed workout shows the error inside the player, and retry '
      'asks for the link again', (tester) async {
    final app = await ExampleTestApp.start(tester, FakeClub());
    var asked = 0;
    dw.plugins.media.open(
      items: [
        DwMediaItem(
          id: 'signed',
          kind: DwMediaKind.video,
          title: 'Signed',
          source: DwMediaSource.resolve(() async {
            asked++;
            if (asked == 1) throw StateError('link expired');
            return Uri.parse('https://example.com/fresh.mp4');
          }),
        ),
      ],
    );
    await app.tap(tester, find.text('Workouts').last);
    expect(find.text('This could not be played.'), findsOneWidget);
    expect(
      find.text('Morning mobility'),
      findsOneWidget,
      reason:
          'the page '
          'around the player stays',
    );

    await app.tap(tester, find.text('Try again'));
    expect(asked, 2);
    expect(find.text('This could not be played.'), findsNothing);
    await stop(tester, app);
  });

  testWidgets('near the end the next workout is announced', (tester) async {
    final app = await ExampleTestApp.start(tester, FakeClub());
    await app.tap(tester, find.text('Workouts').last);
    await app.tap(tester, find.text('Morning mobility'));
    await playTo(tester, const Duration(seconds: 1));
    await playTo(tester, const Duration(seconds: 55));
    expect(find.text('Up next'), findsOneWidget);
    expect(find.text('Core basics'), findsWidgets);
    await stop(tester, app);
  });

  testWidgets('leaving the page keeps the workout in the mini-player; a tap '
      'on it comes back, close ends it', (tester) async {
    final app = await ExampleTestApp.start(tester, FakeClub());
    await app.tap(tester, find.text('Workouts').last);
    await app.tap(tester, find.text('Morning mobility'));
    await playTo(tester, const Duration(seconds: 1));
    expect(find.byKey(miniPlayer), findsNothing);

    await app.tap(tester, find.text('News'));
    expect(find.byKey(miniPlayer), findsOneWidget);
    expect(active().playback.value.isPlaying, isTrue);

    await app.tap(tester, find.byKey(miniPlayer));
    expect(find.byType(AppMediaPlayer), findsOneWidget);
    expect(find.byKey(miniPlayer), findsNothing);

    await app.tap(tester, find.text('News'));
    await app.tap(tester, find.byKey(const Key('app-mini-player-close')));
    expect(find.byKey(miniPlayer), findsNothing);
    expect(dw.plugins.media.sessionManager.sessions, isEmpty);
    await stop(tester, app);
  });
}

DwMediaItem workoutVideo(String id) => DwMediaItem(
  id: id,
  kind: DwMediaKind.video,
  source: DwMediaSource.url('https://example.com/$id.mp4'),
);
