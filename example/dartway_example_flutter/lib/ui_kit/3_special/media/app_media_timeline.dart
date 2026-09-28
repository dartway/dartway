part of '../../ui_kit.dart';

/// Scrubbable timeline for a `DwMediaSession` — position, buffered range and
/// duration. Mechanism (`session.seek`) comes from `dartway_media_flutter`;
/// everything drawn here is the project's own.
///
/// Copied from the framework's example into a project's own `ui_kit/` and
/// restyled — see the `dartway-media` toolkit skill.
class AppMediaTimeline extends StatelessWidget {
  const AppMediaTimeline({super.key, required this.session});

  final DwMediaSession session;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: session.controller.state,
      builder: (context, _) {
        final state = session.controller.state.value;
        final durationMs = state.duration.inMilliseconds;
        final positionMs = state.position.inMilliseconds.clamp(0, max(durationMs, 0));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Slider(
              value: durationMs > 0 ? positionMs.toDouble() : 0,
              max: durationMs > 0 ? durationMs.toDouble() : 1,
              onChanged: durationMs > 0
                  ? (value) => session.seek(Duration(milliseconds: value.round()))
                  : null,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  AppText.caption(_format(state.position)),
                  AppText.caption(_format(state.duration)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  static String _format(Duration duration) {
    String two(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return hours > 0
        ? '$hours:${two(minutes)}:${two(seconds)}'
        : '${two(minutes)}:${two(seconds)}';
  }
}
