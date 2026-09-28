part of '../../ui_kit.dart';

/// "Up next", shown ahead of time (`DwMediaConfig.nextPreview`) and, when
/// `autoplayNext` is also on, counting down to it
/// (`session.queue.value.autoplayCountdownSeconds`).
///
/// Copied from the framework's example into a project's own `ui_kit/` and
/// restyled — see the `dartway-media` toolkit skill.
class AppMediaNextItemCard extends StatelessWidget {
  const AppMediaNextItemCard({super.key, required this.session});

  final DwMediaSession session;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: session.queue,
      builder: (context, _) {
        final queue = session.queue.value;
        final next = queue.next;
        if (!queue.showNextPreview || next == null) {
          return const SizedBox.shrink();
        }
        final countdown = queue.autoplayCountdownSeconds;
        return InkWell(
          onTap: () => session.next(),
          child: AppCard(
            child: Row(
              children: [
                Expanded(
                  child: AppText.body(next.title ?? context.l10n.mediaUpNext),
                ),
                if (countdown != null) AppText.caption('$countdown'),
              ],
            ),
          ),
        );
      },
    );
  }
}
