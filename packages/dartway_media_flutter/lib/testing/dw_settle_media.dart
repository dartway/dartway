import 'package:flutter_test/flutter_test.dart';

/// Lets the engines finish what they started, inside `testWidgets`.
///
/// `just_audio` (and `video_player`'s teardown) complete part of their work
/// on futures bound to the root zone — a stream cancel, a lock — which the
/// fake clock of a widget test never runs: `tester.pump()` alone leaves an
/// audio item loading forever. Each round gives the real event loop one turn
/// and then pumps a frame.
Future<void> dwSettleMedia(WidgetTester tester, {int rounds = 6}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
  }
}
