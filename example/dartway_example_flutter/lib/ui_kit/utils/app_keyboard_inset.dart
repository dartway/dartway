part of '../ui_kit.dart';

/// A keyboard inset that arrives with the keyboard instead of ahead of it.
///
/// The system reports the keyboard as a **step change** in `viewInsets` — on
/// iOS as two steps, first for the accessory bar above the keyboard and then
/// for the keyboard itself — while the keyboard actually travels for about
/// 250 ms. Layout computed straight from the raw inset therefore snaps to its
/// final geometry while the keyboard is still on its way, and what the user
/// sees reads as "it blinked and re-opened".
///
/// [builder] receives the same inset, travelling at the keyboard's own pace.
/// Compute *everything* that depends on the keyboard from it — height, bottom
/// padding, edges. Half the layout left on the raw inset drifts apart from the
/// other half, and that looks worse than the original snap.
///
/// Nothing animates on the first build: with no `begin` the tween starts at its
/// end value, so a sheet opened over an already-raised keyboard is simply in
/// place.
class AppKeyboardInset extends StatelessWidget {
  const AppKeyboardInset({required this.builder, super.key});

  /// Exactly as long as the keyboard itself travels.
  static const duration = Duration(milliseconds: 250);
  static const curve = Curves.easeOut;

  final Widget Function(BuildContext context, double keyboardInset) builder;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween<double>(end: MediaQuery.viewInsetsOf(context).bottom),
    duration: duration,
    curve: curve,
    builder: (context, keyboardInset, _) => builder(context, keyboardInset),
  );
}
