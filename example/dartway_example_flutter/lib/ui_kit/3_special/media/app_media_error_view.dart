part of '../../ui_kit.dart';

/// The error state, inside the player — never a whole screen taken over by
/// it (`dartway/molodey#128`, the reason `dartway_media_flutter` keeps the
/// error inside `DwMediaController.retry()` rather than throwing).
///
/// Copied from the framework's example into a project's own `ui_kit/` and
/// restyled — see the `dartway-media` toolkit skill.
class AppMediaErrorView extends StatelessWidget {
  const AppMediaErrorView({super.key, required this.session});

  final DwMediaSession session;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: session.controller.state,
      builder: (context, _) {
        final state = session.controller.state.value;
        if (!state.isError) return const SizedBox.shrink();
        return ColoredBox(
          color: Colors.black87,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 32),
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
}
