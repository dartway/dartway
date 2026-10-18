part of '../ui_kit.dart';

/// A keyboard inset shared by every keyboard-dependent part of a surface.
///
/// Native iOS already delivers animated `viewInsets` on each engine frame.
/// Follow them directly: an extra tween makes the layout lag behind the keyboard.
/// Web (including iOS WebKit) and other platforms keep a 250 ms ease-out tween
/// to smooth inset steps. This duration is a fallback, not a system guarantee.
///
/// Compute height, bottom padding and edges from [builder]'s one inset so they
/// move together. A surface opened over an already-raised keyboard starts at
/// that inset without animating.
class AppKeyboardInset extends StatelessWidget {
  const AppKeyboardInset({required this.builder, super.key});

  /// Fallback duration for platforms whose keyboard insets arrive in steps.
  static const duration = Duration(milliseconds: 250);
  static const curve = Curves.easeOut;

  final Widget Function(BuildContext context, double keyboardInset) builder;

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      return builder(context, inset);
    }
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: inset),
      duration: duration,
      curve: curve,
      builder: (context, keyboardInset, _) => builder(context, keyboardInset),
    );
  }
}
