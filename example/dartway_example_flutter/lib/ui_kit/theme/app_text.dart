part of '../ui_kit.dart';

/// The app's text styles, as tokens.
///
/// A token is what you reach for when Flutter insists on a [TextStyle] rather
/// than a widget — `InputDecoration.labelStyle`, a `TextSpan`, a third-party
/// widget's `style:` field. Everywhere else, use the [AppText] widget: it
/// carries the token *and* renders it.
///
/// The two are deliberately separate. A single "callable preset" that both
/// styles and renders looks tidy until Flutter asks for the style alone — and
/// it can never be `const`, because a method call is not a constant expression.
enum AppTextStyle {
  title,
  body,
  link,
  caption;

  /// Resolves the token against the current theme — hence the context: there is
  /// no theme at call site, only in the tree.
  TextStyle resolve(BuildContext context) => switch (this) {
    AppTextStyle.title =>
      (context.textTheme.titleLarge ??
              const TextStyle(fontSize: 20, fontWeight: FontWeight.w600))
          .copyWith(color: context.colorScheme.onSurface),
    AppTextStyle.body =>
      (context.textTheme.bodyMedium ?? const TextStyle(fontSize: 16)).copyWith(
        color: context.colorScheme.onSurface,
      ),
    AppTextStyle.link =>
      (context.textTheme.bodyMedium ?? const TextStyle(fontSize: 16)).copyWith(
        color: context.colorScheme.primary,
      ),
    AppTextStyle.caption =>
      (context.textTheme.labelSmall ?? const TextStyle(fontSize: 12)).copyWith(
        color: context.colorScheme.onSurface.withValues(alpha: 0.7),
      ),
  };
}

/// The app's text. One named constructor per style: `AppText.title('Hi')`.
///
/// A plain widget with `const` constructors, the way Flutter names its own
/// variants (`TextButton.icon`, `Text.rich`). That `const` matters: a text leaf
/// that cannot be constant takes every enclosing `const Padding`, `const Center`
/// and `const Expanded` down with it.
class AppText extends StatelessWidget {
  const AppText.title(
    this.text, {
    super.key,
    this.textAlign,
    this.overflow,
    this.maxLines,
  }) : style = AppTextStyle.title;

  const AppText.body(
    this.text, {
    super.key,
    this.textAlign,
    this.overflow,
    this.maxLines,
  }) : style = AppTextStyle.body;

  const AppText.link(
    this.text, {
    super.key,
    this.textAlign,
    this.overflow,
    this.maxLines,
  }) : style = AppTextStyle.link;

  const AppText.caption(
    this.text, {
    super.key,
    this.textAlign,
    this.overflow,
    this.maxLines,
  }) : style = AppTextStyle.caption;

  final String text;
  final AppTextStyle style;
  final TextAlign? textAlign;
  final TextOverflow? overflow;
  final int? maxLines;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: style.resolve(context),
    textAlign: textAlign,
    overflow: overflow,
    maxLines: maxLines,
  );
}
