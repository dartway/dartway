part of '../../ui_kit.dart';

/// "Up next": shown ahead of the end (`DwMediaConfig.nextPreview`) and during
/// the autoplay countdown, with the seconds left and a way to stay on this
/// item. A tap goes to the next item at once.
///
/// Copied into a project's own `ui_kit/` and restyled — see the
/// `dartway-media` toolkit skill.
class AppMediaNextItemCard extends StatelessWidget {
  const AppMediaNextItemCard({super.key, required this.session});

  final DwMediaSession session;

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<DwMediaQueueState>(
        valueListenable: session.queue,
        builder: (context, queue, _) {
          final next = queue.next;
          if (!queue.showNextPreview || next == null) {
            return const SizedBox.shrink();
          }
          final countdown = queue.autoplayCountdown;
          return GestureDetector(
            onTap: session.next,
            child: SizedBox(
              width: 220,
              child: AppCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AppText.caption(
                            countdown == null
                                ? context.l10n.mediaUpNext
                                : context.l10n.mediaNextIn(countdown.inSeconds),
                          ),
                          AppText.body(
                            next.title ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (countdown != null)
                      IconButton(
                        tooltip: context.l10n.mediaStayHere,
                        icon: const Icon(Icons.close),
                        onPressed: session.cancelAutoplay,
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      );
}
