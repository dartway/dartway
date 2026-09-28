part of '../../ui_kit.dart';

/// The timeline: where the item is, how far it has buffered, how long it is.
/// Dragging moves the thumb only; the seek happens once, on release — a
/// seek per drag frame would send the engine dozens of requests it would
/// abort one after another.
///
/// Copied into a project's own `ui_kit/` and restyled — see the
/// `dartway-media` toolkit skill.
class AppMediaTimeline extends StatefulWidget {
  const AppMediaTimeline({super.key, required this.session});

  final DwMediaSession session;

  @override
  State<AppMediaTimeline> createState() => _AppMediaTimelineState();
}

class _AppMediaTimelineState extends State<AppMediaTimeline> {
  double? _dragging;

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<DwMediaPlaybackState>(
        valueListenable: widget.session.playback,
        builder: (context, playback, _) {
          final total = playback.duration.inMilliseconds.toDouble();
          final known = total > 0;
          final position =
              _dragging ??
              playback.position.inMilliseconds
                  .clamp(0, max(total, 0))
                  .toDouble();
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                _label(Duration(milliseconds: position.round())),
                Expanded(
                  child: Slider(
                    value: known ? position : 0,
                    max: known ? total : 1,
                    secondaryTrackValue: known
                        ? playback.buffered.inMilliseconds
                              .clamp(0, total)
                              .toDouble()
                        : null,
                    onChanged: known
                        ? (value) => setState(() => _dragging = value)
                        : null,
                    onChangeEnd: known
                        ? (value) {
                            setState(() => _dragging = null);
                            widget.session.seek(
                              Duration(milliseconds: value.round()),
                            );
                          }
                        : null,
                  ),
                ),
                _label(playback.duration),
              ],
            ),
          );
        },
      );

  Widget _label(Duration duration) => Text(
    _format(duration),
    style: const TextStyle(color: Colors.white, fontSize: 12),
  );

  static String _format(Duration duration) {
    String two(int n) => n.toString().padLeft(2, '0');
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return duration.inHours > 0
        ? '${duration.inHours}:${two(minutes)}:${two(seconds)}'
        : '${two(minutes)}:${two(seconds)}';
  }
}
