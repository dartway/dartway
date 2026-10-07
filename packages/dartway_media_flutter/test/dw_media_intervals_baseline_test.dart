import 'package:dartway_media_flutter/dartway_media_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/media_test_kit.dart';

void main() {
  testWidgets('progress subtraction credits a seek gap, not just playback', (
    tester,
  ) async {
    final rig = MediaRig();
    var previous = Duration.zero;
    var credited = Duration.zero;
    final manager = DwMediaSessionManager(
      config: const DwMediaConfig(progressInterval: Duration.zero),
    );
    final session = manager.open(
      items: [videoItem('v')],
      callbacks: DwMediaCallbacks(
        onProgress: (_, position, _) {
          credited += position - previous;
          previous = position;
        },
      ),
    );
    await rig.loadVideo(tester);
    await session.play();
    await rig.playVideoTo(tester, const Duration(seconds: 1));
    await session.seek(const Duration(seconds: 80));
    await rig.playVideoTo(tester, const Duration(seconds: 81));
    await endSession(tester, session);
    // This behavioral baseline demonstrates why onProgress cannot be used
    // as a confirmed-interval adapter: 79 skipped seconds were credited.
    expect(credited, const Duration(seconds: 81));
  });
}
