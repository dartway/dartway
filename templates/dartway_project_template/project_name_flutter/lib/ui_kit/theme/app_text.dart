part of '../ui_kit.dart';

enum AppText implements DwTextStylePreset {
  title,
  body,
  link,
  caption;

  @override
  TextStyle resolveStyle(BuildContext context) {
    switch (this) {
      case AppText.title:
        return (context.textTheme.titleLarge ??
                const TextStyle(fontSize: 20, fontWeight: FontWeight.w600))
            .copyWith(
          color: context.colorScheme.onSurface,
        );
      case AppText.body:
        return (context.textTheme.bodyMedium ?? const TextStyle(fontSize: 16))
            .copyWith(
          color: context.colorScheme.onSurface,
        );
      case AppText.link:
        return (context.textTheme.bodyMedium ?? const TextStyle(fontSize: 16))
            .copyWith(
          color: context.colorScheme.primary,
        );
      case AppText.caption:
        return (context.textTheme.labelSmall ?? const TextStyle(fontSize: 12))
            .copyWith(
          color: context.colorScheme.onSurface.withValues(alpha: 0.7),
        );
    }
  }
}
