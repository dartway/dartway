part of '../../ui_kit.dart';

/// A quoted message: inside a reply's bubble, and over the composer while
/// replying or editing.
class ChatQuoteBlock extends StatelessWidget {
  const ChatQuoteBlock({
    required this.title,
    required this.text,
    this.icon,
    this.onTap,
    this.onCancel,
    this.cancelTooltip,
    this.muted = false,
    super.key,
  });

  final String title;
  final String text;
  final IconData? icon;
  final VoidCallback? onTap;
  final VoidCallback? onCancel;
  final String? cancelTooltip;

  /// A deleted original: the text is a note, not a quote.
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final caption = AppTextStyle.caption.resolve(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
        decoration: BoxDecoration(
          color: colors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border(left: BorderSide(color: colors.primary, width: 3)),
        ),
        child: Row(
          children: [
            if (icon != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(icon, size: 18, color: colors.primary),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: caption.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: caption.copyWith(
                      fontStyle: muted ? FontStyle.italic : null,
                    ),
                  ),
                ],
              ),
            ),
            if (onCancel != null)
              IconButton(
                tooltip: cancelTooltip,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close, size: 18),
                onPressed: onCancel,
              ),
          ],
        ),
      ),
    );
  }
}

/// The pinned messages over the list: the one shown, where it stands among
/// them, and a tap that goes to it and turns to the next.
class ChatPinnedBar extends StatelessWidget {
  const ChatPinnedBar({
    required this.label,
    required this.text,
    required this.index,
    required this.count,
    required this.onTap,
    this.onUnpin,
    this.unpinTooltip,
    super.key,
  });

  static const double height = 52;

  final String label;
  final String text;

  /// The shown message's place, 0 for the newest.
  final int index;
  final int count;
  final VoidCallback onTap;
  final VoidCallback? onUnpin;
  final String? unpinTooltip;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final caption = AppTextStyle.caption.resolve(context);
    return Material(
      color: colors.surface,
      elevation: 1,
      child: InkWell(
        key: const ValueKey('chat-pinned-bar'),
        onTap: onTap,
        child: SizedBox(
          height: height,
          child: Row(
            children: [
              const SizedBox(width: 12),
              _PinnedPositionStrip(index: index, count: count),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: caption.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween(
                            begin: const Offset(0, 0.4),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      ),
                      child: Text(
                        text,
                        key: ValueKey('$index:$text'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyle.body.resolve(context),
                      ),
                    ),
                  ],
                ),
              ),
              if (onUnpin != null)
                IconButton(
                  tooltip: unpinTooltip,
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: onUnpin,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Up to five dashes, the shown pinned message's one solid — the window of
/// dashes moves with it when there are more.
class _PinnedPositionStrip extends StatelessWidget {
  const _PinnedPositionStrip({required this.index, required this.count});

  final int index;
  final int count;

  @override
  Widget build(BuildContext context) {
    const total = 36.0;
    const gap = 3.0;
    final color = context.colorScheme.primary;
    final visible = count.clamp(1, 5);
    final start = count <= 5 ? 0 : (index - 2).clamp(0, count - visible);
    final dash = (total - gap * (visible - 1)) / visible;
    return SizedBox(
      width: 3,
      height: total,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (var i = 0; i < visible; i++)
            Container(
              height: dash,
              decoration: BoxDecoration(
                color: color.withValues(alpha: start + i == index ? 1 : 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
        ],
      ),
    );
  }
}
