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

  testWidgets(
    'ordinary progress and seek-to-end never automatically record coverage',
    (tester) async {
      var progress = 0;
      var completed = 0;
      final manager = DwMediaSessionManager(
        config: DwMediaConfig(playbackDelivery: (_) async {}),
      );
      final session = manager.open(
        items: [videoItem('v')],
        callbacks: DwMediaCallbacks(
          onProgress: (_, _, _) => progress++,
          onCompleted: (_) => completed++,
        ),
      );
      await rig.loadVideo(tester);
      await session.play();
      await rig.playVideoTo(tester, const Duration(seconds: 1));
      await session.seek(const Duration(seconds: 100));
      rig.video.latest.finish();
      await tester.pump();
      expect(progress, greaterThan(0));
      expect(completed, 1);
      expect(session.flushPlayback(), isNull);
      await endSession(tester, session);
      expect(manager.pendingPlaybackReports, isEmpty);
    },
  );

  testWidgets(
    'tracking is disabled without an adapter; invalid spans still fail clearly',
    (tester) async {
      final manager = DwMediaSessionManager(config: const DwMediaConfig());
      final session = manager.open(items: [videoItem('v')]);
      await rig.loadVideo(tester);
      await session.play();
      await rig.playVideoTo(tester, const Duration(seconds: 1));
      expect(
        session.playbackObservation.record(span(0, 1)),
        DwMediaObservationResult.disabled,
      );
      expect(
        () => session.playbackObservation.record(span(0, 0)),
        throwsArgumentError,
      );
      await endSession(tester, session);
      expect(manager.pendingPlaybackReports, isEmpty);
    },
  );

  testWidgets(
    'explicit confirmed spans exclude the seek gap; in-flight seeks reject new observations',
    (tester) async {
      final accepted = <DwMediaPlaybackReport>[];
      final manager = DwMediaSessionManager(
        config: DwMediaConfig(
          playbackDelivery: (report) async {
            accepted.add(report);
          },
        ),
      );
      final session = manager.open(items: [videoItem('v')]);
      await rig.loadVideo(tester);
      await session.play();
      await rig.playVideoTo(tester, const Duration(seconds: 1));
      final beforeSeek = session.playbackObservation;
      expect(beforeSeek.record(span(0, 1)), DwMediaObservationResult.recorded);
      final seeking = session.seek(const Duration(seconds: 80));
      expect(beforeSeek.record(span(1, 80)), DwMediaObservationResult.stale);
      expect(
        session.playbackObservation.record(span(80, 81)),
        DwMediaObservationResult.notPlaying,
      );
      await seeking;
      await rig.playVideoTo(tester, const Duration(seconds: 81));
      expect(
        session.playbackObservation.record(span(80, 81)),
        DwMediaObservationResult.recorded,
      );
      final report = session.flushPlayback()!;
      expect(report.intervals, [span(0, 1), span(80, 81)]);
      expect(report.coveredDuration, const Duration(seconds: 2));
      await manager.retryPlaybackReport(report);
      expect(accepted.single, same(report));
      expect(manager.pendingPlaybackReports, isEmpty);
      await endSession(tester, session);
    },
  );

  testWidgets(
    'pause/buffer/speed/background invalidate continuity; raw states are only gates',
    (tester) async {
      final manager = DwMediaSessionManager(
        config: DwMediaConfig(
          speeds: const [1, 2],
          playbackDelivery: (_) async {},
        ),
      );
      final session = manager.open(items: [videoItem('v')]);
      await rig.loadVideo(tester);
      expect(
        session.playbackObservation.record(span(0, 1)),
        DwMediaObservationResult.notPlaying,
      );
      await session.play();
      await rig.playVideoTo(tester, const Duration(seconds: 1));
      var old = session.playbackObservation;
      await session.pause();
      expect(old.record(span(0, 1)), DwMediaObservationResult.stale);
      expect(
        session.playbackObservation.record(span(0, 1)),
        DwMediaObservationResult.notPlaying,
      );
      await session.play();
      old = session.playbackObservation;
      rig.video.latest.startBuffering();
      await tester.pump();
      expect(old.record(span(0, 1)), DwMediaObservationResult.stale);
      expect(
        session.playbackObservation.record(span(0, 1)),
        DwMediaObservationResult.notPlaying,
      );
      rig.video.latest.stopBuffering();
      await tester.pump();
      old = session.playbackObservation;
      await session.setSpeed(2);
      expect(old.record(span(0, 1)), DwMediaObservationResult.stale);
      old = session.playbackObservation;
      manager.handleAppLifecycle(AppLifecycleState.hidden);
      expect(old.record(span(0, 1)), DwMediaObservationResult.stale);
      await tester.pump();
      expect(
        session.playbackObservation.record(span(0, 1)),
        DwMediaObservationResult.notPlaying,
      );
      manager.handleAppLifecycle(AppLifecycleState.resumed);
      await endSession(tester, session);
      expect(manager.pendingPlaybackReports, isEmpty);
    },
  );

  testWidgets('refused play and errors do not accept observations', (
    tester,
  ) async {
    final manager = DwMediaSessionManager(
      config: DwMediaConfig(playbackDelivery: (_) async {}),
    );
    final session = manager.open(items: [videoItem('v')]);
    final video = await rig.loadVideo(tester);
    debugDwMediaIsWebOverride = true;
    video.refusePlayWith = PlatformException(code: 'NotAllowedError');
    await session.play();
    await tester.pump();
    expect(
      session.playbackObservation.record(span(0, 1)),
      DwMediaObservationResult.notPlaying,
    );
    video.refusePlayWith = null;
    await session.play();
    await rig.playVideoTo(tester, const Duration(seconds: 1));
    final old = session.playbackObservation;
    video.fail('source failed');
    await tester.pump();
    expect(old.record(span(0, 1)), DwMediaObservationResult.stale);
    expect(
      session.playbackObservation.record(span(0, 1)),
      DwMediaObservationResult.notPlaying,
    );
    await endSession(tester, session);
  });

  testWidgets(
    'source retries and same-item replacement seal once and reject old handles',
    (tester) async {
      final held = Completer<void>();
      final manager = DwMediaSessionManager(
        config: DwMediaConfig(playbackDelivery: (_) => held.future),
      );
      final session = manager.open(items: [videoItem('v')]);
      await rig.loadVideo(tester);
      await session.play();
      await rig.playVideoTo(tester, const Duration(seconds: 1));
      final first = session.playbackObservation;
      first.record(span(0, 1));
      final retrying = session.retry();
      expect(first.record(span(0, 1)), DwMediaObservationResult.stale);
      expect(manager.pendingPlaybackReports, hasLength(1));
      await rig.loadVideo(tester);
      await retrying;
      await session.play();
      await rig.playVideoTo(tester, const Duration(seconds: 2));
      final second = session.playbackObservation;
      expect(second.sourceGeneration, greaterThan(first.sourceGeneration));
      second.record(span(1, 2));
      await session.jumpTo(0, autoplay: false);
      expect(second.record(span(1, 2)), DwMediaObservationResult.stale);
      await rig.loadVideo(tester);
      expect(manager.pendingPlaybackReports, hasLength(2));
      expect(manager.pendingPlaybackReports.map((r) => r.sourceGeneration), [
        first.sourceGeneration,
        second.sourceGeneration,
      ]);
      await endSession(tester, session);
      expect(
        manager.pendingPlaybackReports,
        hasLength(2),
        reason: 'empty teardown adds no report',
      );
      held.complete();
      await tester.pump();
      expect(manager.pendingPlaybackReports, isEmpty);
    },
  );

  testWidgets(
    'failed delivery retains exact batches; retry joins; late ack and disposal preserve newer data',
    (tester) async {
      final attempts = <DwMediaPlaybackReport>[];
      final held = Completer<void>();
      var fail = true;
      Future<void> deliver(DwMediaPlaybackReport report) {
        attempts.add(report);
        if (fail) return Future.error(StateError('offline'));
        return held.future;
      }

      final manager = DwMediaSessionManager(
        config: DwMediaConfig(playbackDelivery: deliver),
      );
      final session = manager.open(items: [videoItem('a'), videoItem('b')]);
      final engine = await rig.loadVideo(tester);
      await session.play();
      await rig.playVideoTo(tester, const Duration(seconds: 1));
      final observer = session.playbackObservation;
      observer.record(span(0, 1));
      final first = session.flushPlayback()!;
      await tester.pump();
      expect(manager.playbackDeliveryError(first), isStateError);
      expect(manager.pendingPlaybackReports.single, same(first));
      expect(tester.takeException(), isNull);
      await expectLater(manager.retryPlaybackReport(first), throwsStateError);
      expect(manager.pendingPlaybackReports.single, same(first));
      fail = false;
      final running = manager.retryPlaybackReport(first);
      expect(manager.retryPlaybackReport(first), same(running));
      observer.record(
        span(0, 1),
      ); // rewatch can be in a later independent window
      final second = session.flushPlayback()!;
      expect(second.batchId, isNot(first.batchId));
      expect(second.intervals, first.intervals);
      await endSession(tester, session);
      expect(
        engine.isReleased,
        isTrue,
        reason: 'delivery does not hold the engine',
      );
      expect(observer.record(span(0, 1)), DwMediaObservationResult.stale);
      expect(session.flushPlayback(), isNull);
      expect(manager.sessions, isEmpty);
      expect(manager.pendingPlaybackReports, [first, second]);
      await tester.pump();
      expect(attempts.where((r) => identical(r, first)), hasLength(3));
      // Both adapter calls accept on this future; each acknowledges its own batch.
      held.complete();
      await running;
      await tester.pump();
      expect(manager.pendingPlaybackReports, isEmpty);
      expect(attempts.first, same(attempts[1]));
      expect(first.intervals, [span(0, 1)]);
    },
  );

  testWidgets(
    'acknowledging an old batch removes only that batch after item movement',
    (tester) async {
      final replies = <int, Completer<void>>{};
      final manager = DwMediaSessionManager(
        config: DwMediaConfig(
          playbackDelivery: (r) =>
              replies.putIfAbsent(r.batchId, Completer<void>.new).future,
        ),
      );
      final session = manager.open(items: [videoItem('a'), videoItem('b')]);
      await rig.loadVideo(tester);
      await session.play();
      await rig.playVideoTo(tester, const Duration(seconds: 1));
      session.playbackObservation.record(span(0, 1));
      await session.next(autoplay: false);
      await rig.loadVideo(tester);
      final first = manager.pendingPlaybackReports.single;
      expect(first.itemId, 'a');
      await session.play();
      await rig.playVideoTo(tester, const Duration(seconds: 2));
      session.playbackObservation.record(span(0, 2));
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
    'end seals only confirmed coverage and a reopen cannot redirect pending delivery',
    (tester) async {
      final oldAdapter = <DwMediaPlaybackReport>[];
      final newAdapter = <DwMediaPlaybackReport>[];
      final held = Completer<void>();
      final manager = DwMediaSessionManager(
        config: DwMediaConfig(
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
      session.playbackObservation.record(span(0, 1));
      rig.video.latest.finish();
      await tester.pump();
      final first = manager.pendingPlaybackReports.single;
      expect(first.intervals, [span(0, 1)], reason: 'no tail is fabricated');
      final reused = manager.open(
        items: [videoItem('v')],
        options: DwMediaOpenOptions(
          playbackDelivery: (r) async {
            newAdapter.add(r);
          },
        ),
      );
      expect(reused, same(session));
      expect(manager.pendingPlaybackReports, hasLength(1));
      expect(
        manager.retryPlaybackReport(first),
        same(manager.retryPlaybackReport(first)),
      );
      await endSession(tester, session);
      held.complete();
      await tester.pump();
      expect(oldAdapter.single, same(first));
      expect(newAdapter, isEmpty);
    },
  );

  testWidgets(
    'audio shares explicit gates and fullscreen/miniplayer do not split a session',
    (tester) async {
      final manager = DwMediaSessionManager(
        config: DwMediaConfig(playbackDelivery: (_) async {}),
      );
      final session = manager.open(items: [audioItem('a')]);
      final track = await rig.loadAudio(tester);
      await session.play();
      await dwSettleMedia(tester);
      track.advanceTo(const Duration(seconds: 1));
      await dwSettleMedia(tester);
      final observer = session.playbackObservation;
      session.minimize();
      session.restore();
      session.enterFullscreen();
      session.exitFullscreen();
      expect(observer.record(span(0, 1)), DwMediaObservationResult.recorded);
      await endSession(tester, session);
    },
  );
}
