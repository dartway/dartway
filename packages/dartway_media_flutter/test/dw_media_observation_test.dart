import 'dart:async';

import 'package:dartway_media_flutter/dartway_media_flutter.dart';
import 'package:dartway_media_flutter/testing.dart';
import 'package:dartway_media_flutter/src/platform/dw_media_platform.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dw_media_played_interval_test.dart' show span;
import 'support/media_test_kit.dart';

void main() {
  late MediaRig rig;
  setUp(() => rig = MediaRig());
  tearDown(() => debugDwMediaIsWebOverride = null);

  testWidgets('flaps preserve a span; seeks seal and never bridge their gap', (
    tester,
  ) async {
    final held = Completer<void>();
    final manager = DwMediaSessionManager(
      config: DwMediaConfig(resume: null, playbackDelivery: (_) => held.future),
    );
    final session = manager.open(items: [videoItem('v')]);
    final video = await rig.loadVideo(tester);
    await session.play();
    expect(session.hasReallyPlayed, isFalse);
    await rig.playVideoTo(tester, const Duration(seconds: 1));
    expect(session.hasReallyPlayed, isTrue);
    video.startBuffering();
    await tester.pump();
    video.stopBuffering();
    await tester.pump();
    expect(manager.pendingPlaybackReports, isEmpty);
    await rig.playVideoTo(tester, const Duration(seconds: 2));
    await session.seek(const Duration(seconds: 80));
    final first = manager.pendingPlaybackReports.single;
    expect(first.intervals, [span(0, 2)]);
    await rig.playVideoTo(tester, const Duration(seconds: 81));
    await session.pause();
    expect(manager.pendingPlaybackReports.last.intervals, [span(80, 81)]);
    expect(session.flushPlayback(), isNull);
    await endSession(tester, session);
    expect(manager.pendingPlaybackReports, hasLength(2));
    held.complete();
    await tester.pump();
    expect(manager.pendingPlaybackReports, isEmpty);
  });

  testWidgets('without an adapter no coverage is retained', (tester) async {
    final manager = DwMediaSessionManager(
      config: const DwMediaConfig(resume: null),
    );
    final session = manager.open(items: [videoItem('v')]);
    await rig.loadVideo(tester);
    await session.play();
    await rig.playVideoTo(tester, const Duration(seconds: 1));
    await session.pause();
    expect(session.flushPlayback(), isNull);
    expect(manager.pendingPlaybackReports, isEmpty);
    await endSession(tester, session);
  });

  testWidgets('speed and background pause seal only earned spans', (
    tester,
  ) async {
    final held = Completer<void>();
    final manager = DwMediaSessionManager(
      config: DwMediaConfig(
        resume: null,
        speeds: const [1, 2],
        playbackDelivery: (_) => held.future,
      ),
    );
    final session = manager.open(items: [videoItem('v')]);
    await rig.loadVideo(tester);
    await session.play();
    await rig.playVideoTo(tester, const Duration(seconds: 1));
    await session.setSpeed(2);
    expect(manager.pendingPlaybackReports.single.intervals, [span(0, 1)]);
    await rig.playVideoTo(tester, const Duration(seconds: 2));
    manager.handleAppLifecycle(AppLifecycleState.hidden);
    await tester.pump();
    expect(session.status.value.intent, DwMediaPlayIntent.pause);
    expect(manager.pendingPlaybackReports.last.intervals, [span(1, 2)]);
    manager.handleAppLifecycle(AppLifecycleState.resumed);
    await endSession(tester, session);
    held.complete();
    await tester.pump();
  });

  testWidgets('refused play earns nothing; errors seal existing evidence', (
    tester,
  ) async {
    final held = Completer<void>();
    final manager = DwMediaSessionManager(
      config: DwMediaConfig(resume: null, playbackDelivery: (_) => held.future),
    );
    final session = manager.open(items: [videoItem('v')]);
    final video = await rig.loadVideo(tester);
    debugDwMediaIsWebOverride = true;
    video.refusePlayWith = PlatformException(code: 'NotAllowedError');
    await session.play();
    expect(session.flushPlayback(), isNull);
    expect(session.hasReallyPlayed, isFalse);
    video.refusePlayWith = null;
    await session.play();
    await rig.playVideoTo(tester, const Duration(seconds: 1));
    video.fail('source failed');
    await tester.pump();
    expect(manager.pendingPlaybackReports.single.intervals, [span(0, 1)]);
    await endSession(tester, session);
    held.complete();
    await tester.pump();
  });

  testWidgets('retry and same-item replacement preserve source attribution', (
    tester,
  ) async {
    final held = Completer<void>();
    final manager = DwMediaSessionManager(
      config: DwMediaConfig(resume: null, playbackDelivery: (_) => held.future),
    );
    final session = manager.open(items: [videoItem('v')]);
    await rig.loadVideo(tester);
    await session.play();
    await rig.playVideoTo(tester, const Duration(seconds: 1));
    final retrying = session.retry();
    final first = manager.pendingPlaybackReports.single;
    await rig.loadVideo(tester);
    await retrying;
    await rig.playVideoTo(tester, const Duration(seconds: 2));
    await session.jumpTo(0, autoplay: false);
    await rig.loadVideo(tester);
    expect(manager.pendingPlaybackReports, hasLength(2));
    final second = manager.pendingPlaybackReports.last;
    expect(second.sourceGeneration, greaterThan(first.sourceGeneration));
    expect(first.intervals, [span(0, 1)]);
    expect(second.intervals, [span(1, 2)]);
    await endSession(tester, session);
    expect(manager.pendingPlaybackReports, hasLength(2));
    held.complete();
    await tester.pump();
  });

  testWidgets(
    'failed delivery retains exact batches; retries join; disposal does not await delivery',
    (tester) async {
      final attempts = <DwMediaPlaybackReport>[];
      final held = Completer<void>();
      var fail = true;
      Future<void> deliver(DwMediaPlaybackReport report) {
        attempts.add(report);
        return fail ? Future.error(StateError('offline')) : held.future;
      }

      final manager = DwMediaSessionManager(
        config: DwMediaConfig(resume: null, playbackDelivery: deliver),
      );
      final session = manager.open(items: [videoItem('a')]);
      final engine = await rig.loadVideo(tester);
      await session.play();
      await rig.playVideoTo(tester, const Duration(seconds: 1));
      final first = session.flushPlayback()!;
      await tester.pump();
      expect(manager.playbackDeliveryError(first), isStateError);
      expect(manager.pendingPlaybackReports.single, same(first));
      expect(tester.takeException(), isNull);
      await expectLater(manager.retryPlaybackReport(first), throwsStateError);
      fail = false;
      final running = manager.retryPlaybackReport(first);
      expect(manager.retryPlaybackReport(first), same(running));
      await session.seek(Duration.zero);
      await rig.playVideoTo(tester, const Duration(seconds: 1));
      final second = session.flushPlayback()!;
      expect(second.batchId, isNot(first.batchId));
      expect(second.intervals, first.intervals);
      await endSession(tester, session);
      expect(engine.isReleased, isTrue);
      expect(session.flushPlayback(), isNull);
      expect(manager.sessions, isEmpty);
      expect(manager.pendingPlaybackReports, [first, second]);
      await tester.pump();
      expect(attempts.where((r) => identical(r, first)), hasLength(3));
      held.complete();
      await running;
      await tester.pump();
      expect(manager.pendingPlaybackReports, isEmpty);
      expect(attempts.first, same(attempts[1]));
    },
  );

  testWidgets(
    'acknowledging an old batch removes only that batch after item movement',
    (tester) async {
      final replies = <int, Completer<void>>{};
      final manager = DwMediaSessionManager(
        config: DwMediaConfig(
          resume: null,
          playbackDelivery: (r) =>
              replies.putIfAbsent(r.batchId, Completer<void>.new).future,
        ),
      );
      final session = manager.open(items: [videoItem('a'), videoItem('b')]);
      await rig.loadVideo(tester);
      await session.play();
      await rig.playVideoTo(tester, const Duration(seconds: 1));
      await session.next(autoplay: false);
      await rig.loadVideo(tester);
      final first = manager.pendingPlaybackReports.single;
      expect(first.itemId, 'a');
      await session.play();
      await rig.playVideoTo(tester, const Duration(seconds: 2));
      await endSession(tester, session);
      final second = manager.pendingPlaybackReports.last;
      expect(second.itemId, 'b');
      final joining = manager.retryPlaybackReport(first);
      replies[first.batchId]!.complete();
      await joining;
      expect(manager.pendingPlaybackReports, [second]);
      replies[second.batchId]!.completeError(StateError('still offline'));
      await tester.pump();
      expect(manager.pendingPlaybackReports.single, same(second));
      expect(manager.playbackDeliveryError(second), isStateError);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'end adds no unobserved tail and reopening cannot redirect pending delivery',
    (tester) async {
      final oldAdapter = <DwMediaPlaybackReport>[];
      final newAdapter = <DwMediaPlaybackReport>[];
      final held = Completer<void>();
      final manager = DwMediaSessionManager(
        config: DwMediaConfig(
          resume: null,
          playbackDelivery: (r) {
            oldAdapter.add(r);
            return held.future;
          },
        ),
      );
      final session = manager.open(items: [videoItem('v')]);
      await rig.loadVideo(tester);
      await session.play();
      await rig.playVideoTo(tester, const Duration(seconds: 1));
      rig.video.latest.finish();
      await tester.pump();
      final first = manager.pendingPlaybackReports.single;
      expect(first.intervals, [span(0, 1)]);
      expect(
        manager.open(
          items: [videoItem('v')],
          options: DwMediaOpenOptions(
            playbackDelivery: (r) async {
              newAdapter.add(r);
            },
          ),
        ),
        same(session),
      );
      expect(manager.pendingPlaybackReports, hasLength(1));
      await endSession(tester, session);
      held.complete();
      await tester.pump();
      expect(oldAdapter.single, same(first));
      expect(newAdapter, isEmpty);
    },
  );

  testWidgets(
    'audio earns spans; fullscreen and mini-player keep the same state',
    (tester) async {
      final accepted = <DwMediaPlaybackReport>[];
      final manager = DwMediaSessionManager(
        config: DwMediaConfig(
          resume: null,
          playbackDelivery: (r) async {
            accepted.add(r);
          },
        ),
      );
      final session = manager.open(items: [audioItem('a')]);
      final track = await rig.loadAudio(tester);
      await session.play();
      await dwSettleMedia(tester);
      track.advanceTo(const Duration(seconds: 1));
      await dwSettleMedia(tester);
      expect(session.hasReallyPlayed, isTrue);
      session.minimize();
      session.restore();
      session.enterFullscreen();
      session.exitFullscreen();
      await endSession(tester, session);
      expect(accepted.single.intervals, hasLength(1));
      expect(accepted.single.intervals.single.start, Duration.zero);
      expect(
        accepted.single.intervals.single.end.inMilliseconds,
        closeTo(1000, 100),
      );
    },
  );
}
