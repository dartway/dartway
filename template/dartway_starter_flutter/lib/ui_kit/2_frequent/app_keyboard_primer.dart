part of '../ui_kit.dart';

/// A mounted, invisible field for synchronous browser gesture focus.
///
/// Keep it inside the viewport (1 px at the bottom), then transfer focus to
/// the real input next frame. An off-screen field can make Safari scroll.
class AppKeyboardPrimer extends HookWidget {
  const AppKeyboardPrimer({required this.focusNode, super.key});

  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
    final controller = useTextEditingController();
    return ExcludeSemantics(
      child: IgnorePointer(
        child: Opacity(
          opacity: 0,
          child: EditableText(
            controller: controller,
            focusNode: focusNode,
            style: const TextStyle(),
            cursorColor: Colors.transparent,
            backgroundCursorColor: Colors.transparent,
            showCursor: false,
            autocorrect: false,
            enableSuggestions: false,
          ),
        ),
      ),
    );
  }
}
