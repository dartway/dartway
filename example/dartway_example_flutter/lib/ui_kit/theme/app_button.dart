part of '../ui_kit.dart';

/// The app's buttons. Call a variant to get the widget:
/// `AppButton.primary('Save', onTap: saveAction)`.
///
/// The framework ships no button of its own — it ships [DwActionBuilder], which
/// guards the action (no re-entrant taps, in-flight flag, optional form
/// validation). Everything below the guard is the app's: which Material widget,
/// what it looks like, how "busy" is rendered.
enum AppButton {
  primary,
  secondary,
  text;

  Widget call(
    String label, {
    required DwUiAction<dynamic>? onTap,
    Key? key,
    Widget? leading,
    Widget? trailing,
    bool showProgress = true,
    bool requireValidation = false,
    double? width,
    double? height,
  }) => _AppButtonView(
    key: key,
    label: label,
    variant: this,
    onTap: onTap,
    leading: leading,
    trailing: trailing,
    showProgress: showProgress,
    requireValidation: requireValidation,
    width: width,
    height: height,
  );

  ButtonStyle _style(BuildContext context) {
    final cs = context.colorScheme;
    return switch (this) {
      AppButton.primary => ElevatedButton.styleFrom(
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      AppButton.secondary => OutlinedButton.styleFrom(
        foregroundColor: cs.primary,
        side: BorderSide(color: cs.primary),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      AppButton.text => TextButton.styleFrom(
        foregroundColor: cs.primary,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      ),
    };
  }
}

class _AppButtonView extends StatelessWidget {
  const _AppButtonView({
    required this.label,
    required this.variant,
    required this.onTap,
    required this.showProgress,
    required this.requireValidation,
    super.key,
    this.leading,
    this.trailing,
    this.width,
    this.height,
  });

  final String label;
  final AppButton variant;
  final DwUiAction<dynamic>? onTap;
  final Widget? leading;
  final Widget? trailing;
  final bool showProgress;
  final bool requireValidation;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return DwActionBuilder(
      action: onTap,
      requireValidation: requireValidation,
      builder: (context, onPressed, busy) {
        final style = variant._style(context);
        final child = showProgress && busy
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (leading != null) ...[leading!, const SizedBox(width: 8)],
                  Text(label),
                  if (trailing != null) ...[
                    const SizedBox(width: 8),
                    trailing!,
                  ],
                ],
              );

        // The variant picks the real Material widget, so an outlined style is
        // worn by an OutlinedButton rather than painted onto an ElevatedButton.
        final button = switch (variant) {
          AppButton.primary => ElevatedButton(
            style: style,
            onPressed: onPressed,
            child: child,
          ),
          AppButton.secondary => OutlinedButton(
            style: style,
            onPressed: onPressed,
            child: child,
          ),
          AppButton.text => TextButton(
            style: style,
            onPressed: onPressed,
            child: child,
          ),
        };

        if (width == null && height == null) return button;
        return SizedBox(width: width, height: height, child: button);
      },
    );
  }
}
