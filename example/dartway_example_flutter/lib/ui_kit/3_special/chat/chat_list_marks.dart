part of '../../ui_kit.dart';

/// The day of the messages below it, in the list and floating over it.
class ChatDateChip extends StatelessWidget {
  const ChatDateChip(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerHigh.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: AppTextStyle.caption
            .resolve(context)
            .copyWith(fontWeight: FontWeight.w600),
      ),
    ),
  );
}

/// The date of the topmost message, shown while the list moves and a moment
/// after it stops.
class ChatFloatingDate extends StatelessWidget {
  const ChatFloatingDate({
    required this.label,
    required this.visible,
    super.key,
  });

  final String? label;
  final bool visible;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: visible && label != null ? 1 : 0,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 200),
        offset: visible ? Offset.zero : const Offset(0, -0.3),
        child: label == null ? const SizedBox.shrink() : ChatDateChip(label!),
      ),
    ),
  );
}

/// Where the unread messages begin, as the chat was opened.
class ChatUnreadDivider extends StatelessWidget {
  const ChatUnreadDivider(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(vertical: 8),
    padding: const EdgeInsets.symmetric(vertical: 4),
    color: context.colorScheme.secondaryContainer.withValues(alpha: 0.6),
    alignment: Alignment.center,
    child: Text(
      label,
      style: AppTextStyle.caption
          .resolve(context)
          .copyWith(color: context.colorScheme.onSecondaryContainer),
    ),
  );
}

/// The "↓" over the list: to the newest messages, with how many wait there.
class ChatJumpButton extends StatelessWidget {
  const ChatJumpButton({
    required this.visible,
    required this.count,
    required this.onTap,
    required this.tooltip,
    super.key,
  });

  final bool visible;
  final int count;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return AnimatedSlide(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      offset: visible ? Offset.zero : const Offset(0, 1.5),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: visible ? 1 : 0,
        child: IgnorePointer(
          ignoring: !visible,
          child: Badge(
            isLabelVisible: count > 0,
            label: Text(count > 999 ? '999+' : '$count'),
            backgroundColor: colors.primary,
            textColor: colors.onPrimary,
            child: Material(
              color: colors.surface,
              elevation: 3,
              shape: const CircleBorder(),
              child: IconButton(
                key: const ValueKey('chat-jump-to-newest'),
                tooltip: tooltip,
                onPressed: onTap,
                icon: Icon(Icons.keyboard_arrow_down, color: colors.primary),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A channel of the chat, with its unread count.
class ChatChannelChip extends StatelessWidget {
  const ChatChannelChip({
    required this.title,
    required this.selected,
    required this.unread,
    required this.onTap,
    super.key,
  });

  final String title;
  final bool selected;
  final int unread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ChoiceChip(
    label: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title),
        if (unread > 0) ...[
          const SizedBox(width: 6),
          Badge(
            label: Text(unread > 99 ? '99+' : '$unread'),
            backgroundColor: context.colorScheme.primary,
            textColor: context.colorScheme.onPrimary,
          ),
        ],
      ],
    ),
    selected: selected,
    onSelected: (_) => onTap(),
  );
}
