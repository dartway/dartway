part of '../../ui_kit.dart';

/// The error state — inside the player, never a whole page taken over by it.
/// Retry asks the session, which asks the item's source again: an expired
/// signed link comes back fresh.
///
/// Copied into a project's own `ui_kit/` and restyled — see the
/// `dartway-media` toolkit skill.
class AppMediaErrorView extends StatelessWidget {
  const AppMediaErrorView({super.key, required this.session});

  final DwMediaSession session;

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<DwMediaPlaybackState>(
        valueListenable: session.playback,
        builder: (context, playback, _) {
          if (!playback.isError) return const SizedBox.shrink();
          return ColoredBox(
            color: Colors.black87,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.white,
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.mediaFailed,
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  AppButton.secondary(
                    context.l10n.retry,
                    onTap: dw.action((_) => session.retry()),
                  ),
                ],
              ),
            ),
          );
        },
      );
}
