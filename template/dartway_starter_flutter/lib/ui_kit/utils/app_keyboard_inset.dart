part of '../ui_kit.dart';

/// One keyboard inset for all geometry that depends on the keyboard.
///
/// Native iOS already reports animated insets frame by frame. Using another
/// tween there makes content trail the keyboard after it has stopped. Other
/// platforms retain smoothing for step changes. An already raised keyboard
/// is delivered immediately on the first build.
class AppKeyboardInset extends StatelessWidget {
  const AppKeyboardInset({required this.builder, super.key});

  static const duration = Duration(milliseconds: 250);
  static const curve = Curves.easeOut;

  static bool get followsSystemAnimation =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  final Widget Function(BuildContext context, double keyboardInset) builder;

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    if (followsSystemAnimation) return builder(context, inset);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: inset),
      duration: duration,
      curve: curve,
      builder: (context, keyboardInset, _) => builder(context, keyboardInset),
    );
  }
}
