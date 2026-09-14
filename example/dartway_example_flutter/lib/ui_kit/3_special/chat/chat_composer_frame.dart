part of '../../ui_kit.dart';

/// The bar under the list the composer or the search controls sit in.
class ChatBottomBar extends StatelessWidget {
  const ChatBottomBar({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
    color: context.colorScheme.surface,
    elevation: 4,
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
        child: child,
      ),
    ),
  );
}

/// The message field of the composer: grows to a few lines, then scrolls.
class ChatMessageField extends StatelessWidget {
  const ChatMessageField({
    required this.controller,
    required this.focusNode,
    required this.hintText,
    this.prefix,
    super.key,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final Widget? prefix;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: context.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(22),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        ?prefix,
        Expanded(
          child: TextField(
            key: const ValueKey('chat-message-field'),
            controller: controller,
            focusNode: focusNode,
            minLines: 1,
            maxLines: 6,
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
            style: AppTextStyle.body.resolve(context),
            decoration: InputDecoration(
              hintText: hintText,
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.fromLTRB(
                prefix == null ? 16 : 0,
                12,
                12,
                12,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

/// The search controls in place of the composer: how many matches, which
/// one, and the way to the next older and newer.
class ChatSearchControls extends StatelessWidget {
  const ChatSearchControls({
    required this.label,
    required this.onOlder,
    required this.onNewer,
    required this.olderTooltip,
    required this.newerTooltip,
    super.key,
  });

  final String label;
  final VoidCallback? onOlder;
  final VoidCallback? onNewer;
  final String olderTooltip;
  final String newerTooltip;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const SizedBox(width: 8),
      Expanded(child: AppText.body(label)),
      IconButton(
        key: const ValueKey('chat-search-older'),
        tooltip: olderTooltip,
        onPressed: onOlder,
        icon: const Icon(Icons.keyboard_arrow_up),
      ),
      IconButton(
        key: const ValueKey('chat-search-newer'),
        tooltip: newerTooltip,
        onPressed: onNewer,
        icon: const Icon(Icons.keyboard_arrow_down),
      ),
    ],
  );
}

/// The search field in the app bar.
class ChatSearchField extends StatelessWidget {
  const ChatSearchField({
    required this.controller,
    required this.hintText,
    super.key,
  });

  final TextEditingController controller;
  final String hintText;

  @override
  Widget build(BuildContext context) => TextField(
    key: const ValueKey('chat-search-field'),
    controller: controller,
    autofocus: true,
    style: AppTextStyle.body.resolve(context),
    decoration: InputDecoration(
      hintText: hintText,
      border: InputBorder.none,
      isDense: true,
    ),
  );
}
