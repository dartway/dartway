part of '../ui_kit.dart';

/// The app's buttons. One named constructor per variant:
/// `AppButton.primary('Save', onTap: saveAction)`.
///
/// The framework ships no button of its own — it ships [DwActionBuilder], which
/// guards the action (no re-entrant taps, an in-flight flag, optional form
/// validation). Everything below the guard is the app's: which Material widget,
/// what it looks like, how "busy" is rendered.
///
/// There is no width mode here. A Material button already hugs its content, and
/// making one fill the row is the parent's job in Flutter — wrap it in a
/// `SizedBox(width: double.infinity)` or an `Expanded`. [width] and [height] are
/// for the rare case of an exact size.
class AppButton extends StatelessWidget {
  const AppButton.primary(
    this.label, {
    required this.onTap,
    super.key,
    this.leading,
    this.trailing,
    this.showProgress = true,
    this.requireValidation = false,
    this.unfocusOnTap = true,
    this.backgroundColor,
    this.foregroundColor,
    this.borderColor,
    this.labelStyle,
    this.padding,
    this.width,
    this.height,
  }) : _variant = _AppButtonVariant.primary;

  const AppButton.secondary(
    this.label, {
    required this.onTap,
    super.key,
    this.leading,
    this.trailing,
    this.showProgress = true,
    this.requireValidation = false,
    this.unfocusOnTap = true,
    this.backgroundColor,
    this.foregroundColor,
    this.borderColor,
    this.labelStyle,
    this.padding,
    this.width,
    this.height,
  }) : _variant = _AppButtonVariant.secondary;

  const AppButton.text(
    this.label, {
    required this.onTap,
    super.key,
    this.leading,
    this.trailing,
    this.showProgress = true,
    this.requireValidation = false,
    this.unfocusOnTap = true,
    this.backgroundColor,
    this.foregroundColor,
    this.borderColor,
    this.labelStyle,
    this.padding,
    this.width,
    this.height,
  }) : _variant = _AppButtonVariant.text;

  final String label;
  final DwUiAction<dynamic>? onTap;
  final _AppButtonVariant _variant;
  final Widget? leading;
  final Widget? trailing;

  /// Renders a spinner in place of the label while the action runs.
  final bool showProgress;

  /// Validates the enclosing [Form] before running the action.
  final bool requireValidation;

  /// Drops keyboard focus before the action runs.
  final bool unfocusOnTap;

  /// Per-call overrides of the variant's colors — a brand has exceptions, and
  /// making the app fork the whole variant for one of them is how kits rot.
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? borderColor;
  final TextStyle? labelStyle;
  final EdgeInsetsGeometry? padding;

  /// An exact size, when the design really calls for one. To fill the available
  /// width, wrap the button instead — that is Flutter's own answer.
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) => DwActionBuilder(
    action: onTap,
    requireValidation: requireValidation,
    unfocusOnTap: unfocusOnTap,
    builder: (context, onPressed, busy) {
      final style = _style(context);
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
                if (trailing != null) ...[const SizedBox(width: 8), trailing!],
              ],
            );

      // The variant picks the real Material widget, so an outlined style is
      // worn by an OutlinedButton rather than painted onto an ElevatedButton.
      final button = switch (_variant) {
        _AppButtonVariant.primary => ElevatedButton(
          style: style,
          onPressed: onPressed,
          child: child,
        ),
        _AppButtonVariant.secondary => OutlinedButton(
          style: style,
          onPressed: onPressed,
          child: child,
        ),
        _AppButtonVariant.text => TextButton(
          style: style,
          onPressed: onPressed,
          child: child,
        ),
      };

      if (width == null && height == null) return button;
      return SizedBox(width: width, height: height, child: button);
    },
  );

  ButtonStyle _style(BuildContext context) {
    final cs = context.colorScheme;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );
    final defaultPadding = _variant == _AppButtonVariant.text
        ? const EdgeInsets.symmetric(horizontal: 8, vertical: 8)
        : const EdgeInsets.symmetric(horizontal: 16, vertical: 12);

    return switch (_variant) {
      _AppButtonVariant.primary => ElevatedButton.styleFrom(
        backgroundColor: backgroundColor ?? cs.primary,
        foregroundColor: foregroundColor ?? cs.onPrimary,
        textStyle: labelStyle,
        padding: padding ?? defaultPadding,
        shape: shape,
      ),
      _AppButtonVariant.secondary => OutlinedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor ?? cs.primary,
        side: BorderSide(color: borderColor ?? cs.primary),
        textStyle: labelStyle,
        padding: padding ?? defaultPadding,
        shape: shape,
      ),
      _AppButtonVariant.text => TextButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor ?? cs.primary,
        textStyle: labelStyle,
        padding: padding ?? defaultPadding,
      ),
    };
  }
}

enum _AppButtonVariant { primary, secondary, text }
