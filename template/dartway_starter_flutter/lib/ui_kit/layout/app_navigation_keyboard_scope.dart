part of '../ui_kit.dart';

/// Navigation stays mounted at the physical bottom beneath sheet and keyboard.
/// Start revealing it when dismissal begins, even with a nonzero keyboard inset.
class AppNavigationKeyboardScope extends StatelessWidget {
  const AppNavigationKeyboardScope({
    required this.isCovered,
    required this.child,
    super.key,
  });

  final bool isCovered;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return IgnorePointer(
      ignoring: media.viewInsets.bottom > 0,
      child: ExcludeSemantics(
        excluding: isCovered,
        child: AnimatedOpacity(
          opacity: isCovered ? 0 : 1,
          duration: AppKeyboardInset.duration,
          curve: AppKeyboardInset.curve,
          child: MediaQuery(
            data: media.copyWith(
              viewInsets: EdgeInsets.zero,
              padding: media.padding.copyWith(bottom: media.viewPadding.bottom),
            ),
            child: Material(type: MaterialType.transparency, child: child),
          ),
        ),
      ),
    );
  }
}
