part of '../ui_kit.dart';

/// The app's text styles. Call a preset to get the widget: `AppText.title('Hi')`
/// — the style is resolved at build time, against the current theme.
enum AppText {
  title,
  body,
  link,
  caption;

  TextStyle resolve(BuildContext context) => switch (this) {
    AppText.title => (context.textTheme.titleLarge ??
            const TextStyle(fontSize: 20, fontWeight: FontWeight.w600))
        .copyWith(color: context.colorScheme.onSurface),
    AppText.body =>
      (context.textTheme.bodyMedium ?? const TextStyle(fontSize: 16)).copyWith(
        color: context.colorScheme.onSurface,
      ),
    AppText.link =>
      (context.textTheme.bodyMedium ?? const TextStyle(fontSize: 16)).copyWith(
        color: context.colorScheme.primary,
      ),
    AppText.caption =>
      (context.textTheme.labelSmall ?? const TextStyle(fontSize: 12)).copyWith(
        color: context.colorScheme.onSurface.withValues(alpha: 0.7),
      ),
  };

  Widget call(
    String text, {
    TextAlign? textAlign,
    TextOverflow? overflow,
    int? maxLines,
  }) => _AppTextView(
    text,
    preset: this,
    textAlign: textAlign,
    overflow: overflow,
    maxLines: maxLines,
  );
}

/// Resolves an [AppText] preset at build time — the reason a preset call
/// returns a widget rather than a [TextStyle]: there is no context at call site.
class _AppTextView extends StatelessWidget {
  const _AppTextView(
    this.text, {
    required this.preset,
    this.textAlign,
    this.overflow,
    this.maxLines,
  });

  final String text;
  final AppText preset;
  final TextAlign? textAlign;
  final TextOverflow? overflow;
  final int? maxLines;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: preset.resolve(context),
    textAlign: textAlign,
    overflow: overflow,
    maxLines: maxLines,
  );
}
