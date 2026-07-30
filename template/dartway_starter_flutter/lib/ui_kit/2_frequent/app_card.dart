part of '../ui_kit.dart';

/// Rounded surface tile — the standard card container of the app (stat tiles,
/// grouped content blocks).
class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child});

  final Widget child;

  static const _padding = EdgeInsets.all(16);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: _padding,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }
}
