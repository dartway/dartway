part of '../ui_kit.dart';

/// Wraps [child] in [parentBuilder] only when [condition] holds — keeps a large
/// subtree from being duplicated across the two branches of a ternary.
class ConditionalParent extends StatelessWidget {
  const ConditionalParent({
    required this.condition,
    required this.parentBuilder,
    required this.child,
    super.key,
  });

  final bool condition;
  final Widget Function(Widget child) parentBuilder;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      condition ? parentBuilder(child) : child;
}
