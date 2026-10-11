import 'dart:async';

import 'package:dartway_media_flutter/dartway_media_flutter.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/media_test_kit.dart';

void main() {
  late MediaRig rig;
  setUp(() => rig = MediaRig());

  testWidgets('waiting leaves the controls timer alone and play is a no-op', (
    tester,
  ) async {
    final manager = DwMediaSessionManager(
      config: const DwMediaConfig(
        resume: null,
        controlsAutoHideDelay: Duration(seconds: 1),
      ),
    );
    final session = manager.open(items: [videoItem('v')]);
    final video = await rig.loadVideo(tester);
    await session.play();
    expect(session.status.value.waiting, isTrue);
    await session.play();
    expect(video.playCalls, 1);
    await rig.playVideoTo(tester, const Duration(seconds: 1));
    video.startBuffering();
    await tester.pump(const Duration(milliseconds: 400));
    video.stopBuffering();
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      session.controlsVisible.value,
      isFalse,
      reason: 'the original timer expires',
    );
    expect(session.status.value.intent, DwMediaPlayIntent.play);
    video.startBuffering();
    await tester.pump();
    expect(session.controlsVisible.value, isFalse);
    await session.togglePlay();
    expect(session.status.value.intent, DwMediaPlayIntent.pause);
    expect(video.isPlaying, isFalse);
    expect(session.controlsVisible.value, isTrue);
    await endSession(tester, session);
  });

  testWidgets(
    'scrub targets show at once; stale ticks and older seek completion lose',
    (tester) async {
      final manager = DwMediaSessionManager(
        config: const DwMediaConfig(resume: null),
      );
      final session = manager.open(items: [videoItem('v')]);
      final video = await rig.loadVideo(tester);
      await session.play();
      await rig.playVideoTo(tester, const Duration(seconds: 1));
      final gate = Completer<void>();
      video.seekBarrier = gate.future;
      final first = session.skipForward();
      expect(session.position.value.position, const Duration(seconds: 11));
      final second = session.skipForward();
      final third = session.skipForward();
      expect(session.position.value.position, const Duration(seconds: 31));
      expect(video.seekCalls, [const Duration(seconds: 11)]);
      final displayed = <Duration>[];
      session.position.addListener(
        () => displayed.add(session.position.value.position),
      );
      await rig.playVideoTo(tester, const Duration(seconds: 2));
      expect(session.position.value.position, const Duration(seconds: 31));
      gate.complete();
      await first;
      await second;
      await third;
      expect(video.seekCalls, [
        const Duration(seconds: 11),
        const Duration(seconds: 31),
      ]);
      expect(video.position, const Duration(seconds: 31));
      expect(displayed.every((p) => p == const Duration(seconds: 31)), isTrue);
      expect(session.position.value.seekTarget, isNull);
      await endSession(tester, session);
    },
  );

  testWidgets('two quick skips land at +20', (tester) async {
    final manager = DwMediaSessionManager(
      config: const DwMediaConfig(resume: null),
    );
    final session = manager.open(items: [videoItem('v')]);
    final video = await rig.loadVideo(tester);
    final gate = Completer<void>();
    video.seekBarrier = gate.future;
    final first = session.skipForward();
    final second = session.skipForward();
    expect(session.position.value.position, const Duration(seconds: 20));
    gate.complete();
    await Future.wait([first, second]);
    expect(video.position, const Duration(seconds: 20));
    await endSession(tester, session);
  });

  testWidgets('minimize, toggle, expand share intent and engine', (
    tester,
  ) async {
    final manager = DwMediaSessionManager(
      config: const DwMediaConfig(resume: null),
    );
    final session = manager.open(items: [videoItem('v')]);
    final video = await rig.loadVideo(tester);
    await session.play();
    session.minimize();
    await session.togglePlay();
    session.restore();
    final reopened = manager.open(items: [videoItem('v')]);
    expect(reopened, same(session));
    expect(reopened.status.value.intent, DwMediaPlayIntent.pause);
    expect(video.isPlaying, isFalse);
    expect(rig.video.opened, hasLength(1));
    await endSession(tester, session);
  });

  testWidgets(
    'pause while loading cancels play and a queued seek keeps its target',
    (tester) async {
      final late = MediaRig(readyOnOpen: false);
      final manager = DwMediaSessionManager(
        config: const DwMediaConfig(resume: null),
      );
      final session = manager.open(items: [videoItem('loading')]);
      await session.play();
      await session.pause();
      final seeking = session.seek(const Duration(seconds: 20));
      expect(session.status.value.intent, DwMediaPlayIntent.pause);
      expect(session.position.value.position, const Duration(seconds: 20));
      await late.loadVideo(tester);
      await seeking;
      expect(late.video.latest.isPlaying, isFalse);
      expect(late.video.latest.position, const Duration(seconds: 20));
      expect(session.position.value.seekTarget, isNull);
      await endSession(tester, session);
    },
  );

  testWidgets('play after an end seeks to zero then confirms fresh playback', (
    tester,
  ) async {
    final manager = DwMediaSessionManager(
      config: const DwMediaConfig(resume: null),
    );
    final session = manager.open(items: [videoItem('restart')]);
    final video = await rig.loadVideo(tester);
    await session.play();
    await rig.playVideoTo(tester, const Duration(seconds: 1));
    video.finish();
    await tester.pump();
    expect(session.status.value.intent, DwMediaPlayIntent.pause);
    await session.play();
    expect(video.position, Duration.zero);
    expect(video.isPlaying, isTrue);
    expect(session.status.value.intent, DwMediaPlayIntent.play);
    expect(session.status.value.waiting, isTrue);
    await rig.playVideoTo(tester, const Duration(seconds: 1));
    expect(session.status.value.waiting, isFalse);
    await endSession(tester, session);
  });

  testWidgets('error during a seek survives its late completion', (
    tester,
  ) async {
    final manager = DwMediaSessionManager(
      config: const DwMediaConfig(resume: null),
    );
    final session = manager.open(items: [videoItem('error-seek')]);
    final video = await rig.loadVideo(tester);
    final gate = Completer<void>();
    video.seekBarrier = gate.future;
    final seeking = session.seek(const Duration(seconds: 20));
    video.fail('failed during seek');
    await tester.pump();
    expect(session.status.value.isError, isTrue);
    expect(session.position.value.seekTarget, isNull);
    gate.complete();
    await seeking;
    expect(session.status.value.isError, isTrue);
    expect(session.position.value.seekTarget, isNull);
    await endSession(tester, session);
  });

  testWidgets(
    'position ticks notify position and merge, never status or the video surface',
    (tester) async {
      final manager = DwMediaSessionManager(
        config: const DwMediaConfig(resume: null),
      );
      final session = manager.open(items: [videoItem('v')]);
      await rig.loadVideo(tester);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: DwVideoSurface(session: session),
        ),
      );
      await session.play();
      await rig.playVideoTo(tester, const Duration(seconds: 1));
      await tester.pump();
      var statuses = 0;
      var positions = 0;
      var merges = 0;
      var surfaceBuilds = 0;
      session.status.addListener(() => statuses++);
      session.position.addListener(() => positions++);
      session.playback.addListener(() => merges++);
      final previous = debugOnRebuildDirtyWidget;
      debugOnRebuildDirtyWidget = (element, builtOnce) {
        previous?.call(element, builtOnce);
        if (element.widget is AspectRatio &&
            element.findAncestorWidgetOfExactType<DwVideoSurface>() != null) {
          surfaceBuilds++;
        }
      };
      addTearDown(() => debugOnRebuildDirtyWidget = previous);
      for (var i = 2; i <= 5; i++) {
        await rig.playVideoTo(tester, Duration(seconds: i));
      }
      expect(positions, 4);
      expect(merges, 4);
      expect(statuses, 0);
      expect(surfaceBuilds, 0);
      await tester.pumpWidget(const SizedBox.shrink());
      await endSession(tester, session);
    },
  );
}
