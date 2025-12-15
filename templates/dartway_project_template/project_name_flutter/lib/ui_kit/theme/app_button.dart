part of '../ui_kit.dart';

enum AppButton implements DwButtonStylePreset {
  primary,
  secondary,
  text;

  @override
  ButtonStyle resolveStyle(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    switch (this) {
      case AppButton.primary:
        return ElevatedButton.styleFrom(
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        );
      case AppButton.secondary:
        return OutlinedButton.styleFrom(
          foregroundColor: cs.primary,
          side: BorderSide(color: cs.primary),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        );
      case AppButton.text:
        return TextButton.styleFrom(
          foregroundColor: cs.primary,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        );
    }
  }
}
