import 'package:flutter_test/flutter_test.dart';

import 'support/media_test_kit.dart';

void main() {
  late MediaRig rig;
  setUp(() => rig = MediaRig());

  testWidgets('video: ready, playing, paused, disposed', (tester) async {
    final controller = controllerFor(videoItem('v'));
    await rig.loadVideo(tester);
    expect(controller.state.value.playState.name, 'ready');
    await controller.play();
    await rig.playVideoTo(tester, const Duration(seconds: 1));
    expect(controller.state.value.playState.name, 'playing');
    await controller.pause();
    await tester.pump();
    expect(controller.state.value.playState.name, 'paused');
    await release(tester, controller);
    expect(rig.video.livePlayers, isEmpty);
  });

  testWidgets('audio: ready, playing, disposed', (tester) async {
    final controller = controllerFor(audioItem('a'));
    await rig.loadAudio(tester);
    expect(controller.state.value.playState.name, 'ready');
    await controller.play();
    await tester.pump();
    expect(controller.state.value.playState.name, 'playing');
    await release(tester, controller);
  });
}
