part of '../../ui_kit.dart';

/// What `DwMiniPlayerHost`'s builder returns — mechanics (visibility, drag,
/// scale, `expand`/`close`) all come from the package; this is only the look.
///
/// Copied from the framework's example into a project's own `ui_kit/` and
/// restyled — see the `dartway-media` toolkit skill.
class AppMiniPlayerChrome extends StatelessWidget {
  const AppMiniPlayerChrome({
    super.key,
    required this.session,
    required this.onExpand,
    required this.onClose,
  });

  final DwMediaSession session;
  final VoidCallback onExpand;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onExpand,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (session.currentItem.kind == DwMediaKind.video)
              DwVideoSurface(session: session)
            else
              ColoredBox(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: const Icon(Icons.music_note),
              ),
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                iconSize: 16,
                color: Colors.white,
                icon: const Icon(Icons.close),
                onPressed: onClose,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
