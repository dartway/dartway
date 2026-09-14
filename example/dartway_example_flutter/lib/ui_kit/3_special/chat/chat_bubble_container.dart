part of '../../ui_kit.dart';

/// A message bubble: the caller's own on the right in the primary tint,
/// everyone else's on the left. Bubbles of one author in a row share their
/// inner corners, so a run of messages reads as one voice.
class ChatBubbleContainer extends StatelessWidget {
  const ChatBubbleContainer({
    required this.isMine,
    required this.child,
    this.isFirstInGroup = true,
    this.isLastInGroup = true,
    this.isHighlighted = false,
    this.maxWidth = 340,
    super.key,
  });

  final bool isMine;
  final bool isFirstInGroup;
  final bool isLastInGroup;

  /// Just scrolled to (a pinned message, a search result, a quote).
  final bool isHighlighted;
  final double maxWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    const round = Radius.circular(18);
    const tight = Radius.circular(6);
    final colors = context.colorScheme;
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        constraints: BoxConstraints(maxWidth: maxWidth),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
        decoration: BoxDecoration(
          color: isHighlighted
              ? colors.tertiaryContainer
              : isMine
              ? colors.primaryContainer
              : colors.surfaceContainerHighest,
          borderRadius: BorderRadius.only(
            topLeft: !isMine && !isFirstInGroup ? tight : round,
            bottomLeft: !isMine && !isLastInGroup ? tight : round,
            topRight: isMine && !isFirstInGroup ? tight : round,
            bottomRight: isMine && !isLastInGroup ? tight : round,
          ),
        ),
        child: child,
      ),
    );
  }
}

/// The initials of a message's author, beside the last bubble of their run.
class ChatAuthorAvatar extends StatelessWidget {
  const ChatAuthorAvatar({required this.name, this.visible = true, super.key});

  static const double size = 32;

  final String name;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox(width: size);
    final initials = name.trim().isEmpty
        ? '?'
        : name.trim().split(RegExp(r'\s+')).take(2).map((w) => w[0]).join();
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: context.colorScheme.secondaryContainer,
      child: Text(
        initials.toUpperCase(),
        style: AppTextStyle.caption
            .resolve(context)
            .copyWith(color: context.colorScheme.onSecondaryContainer),
      ),
    );
  }
}

/// The author's name over the first bubble of their run.
class ChatAuthorName extends StatelessWidget {
  const ChatAuthorName(this.name, {super.key});

  final String name;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Text(
      name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTextStyle.caption
          .resolve(context)
          .copyWith(
            color: context.colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
    ),
  );
}

/// Time, "edited" and a pin mark at the end of a bubble.
class ChatMessageMeta extends StatelessWidget {
  const ChatMessageMeta({
    required this.time,
    this.editedLabel,
    this.isPinned = false,
    super.key,
  });

  final String time;

  /// Shown when the message was edited.
  final String? editedLabel;
  final bool isPinned;

  @override
  Widget build(BuildContext context) {
    final style = AppTextStyle.caption.resolve(context).copyWith(fontSize: 11);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isPinned)
          Padding(
            padding: const EdgeInsets.only(right: 3),
            child: Icon(Icons.push_pin, size: 11, color: style.color),
          ),
        if (editedLabel != null) Text('$editedLabel · ', style: style),
        Text(time, style: style),
      ],
    );
  }
}
