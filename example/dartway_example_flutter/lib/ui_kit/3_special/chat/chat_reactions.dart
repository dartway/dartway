part of '../../ui_kit.dart';

/// One kind of reaction under a message: its sign and count, tinted when the
/// caller's own.
class ChatReactionPill extends StatelessWidget {
  const ChatReactionPill({
    required this.sign,
    required this.count,
    required this.isMine,
    required this.onTap,
    super.key,
  });

  final String sign;
  final int count;
  final bool isMine;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: isMine
              ? colors.primary.withValues(alpha: 0.18)
              : colors.surface.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isMine ? colors.primary : colors.outlineVariant,
            width: isMine ? 1.2 : 0.6,
          ),
        ),
        child: Text(
          '$sign $count',
          style: AppTextStyle.caption.resolve(context).copyWith(fontSize: 12),
        ),
      ),
    );
  }
}

/// The row of reactions to pick from, the caller's current one ringed.
class ChatReactionPicker extends StatelessWidget {
  const ChatReactionPicker({
    required this.signs,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final List<String> signs;
  final int? selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: [
      for (var i = 0; i < signs.length; i++)
        InkWell(
          key: ValueKey('chat-reaction-$i'),
          customBorder: const CircleBorder(),
          onTap: () => onSelected(i),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected == i
                  ? context.colorScheme.primary.withValues(alpha: 0.18)
                  : null,
            ),
            child: Text(signs[i], style: const TextStyle(fontSize: 26)),
          ),
        ),
    ],
  );
}
