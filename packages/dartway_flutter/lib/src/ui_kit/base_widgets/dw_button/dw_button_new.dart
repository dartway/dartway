import 'package:dartway_flutter/dartway_flutter.dart';
import 'package:flutter/material.dart';

class DwButtonNew<T> extends StatelessWidget {
  const DwButtonNew._({
    this.label,
    this.icon,
    this.builder,
    this.iconBuilder,
    this.action,
    super.key,
  });

  final String? label;
  final IconData? icon;
  final DwUiAction<T>? action;

  final ButtonStyleButton Function({
    Key? key,
    required VoidCallback? onPressed,
    VoidCallback? onLongPress,
    ValueChanged<bool>? onHover,
    ValueChanged<bool>? onFocusChange,
    ButtonStyle? style,
    FocusNode? focusNode,
    bool autofocus,
    Clip? clipBehavior,
    MaterialStatesController? statesController,
    bool? isSemanticButton,
    required Widget child,
  })?
  builder;

  final ButtonStyleButton Function({
    Key? key,
    required VoidCallback? onPressed,
    VoidCallback? onLongPress,
    ValueChanged<bool>? onHover,
    ValueChanged<bool>? onFocusChange,
    ButtonStyle? style,
    FocusNode? focusNode,
    bool autofocus,
    Clip? clipBehavior,
    MaterialStatesController? statesController,
    required Widget icon,
    required Widget label,
    IconAlignment? iconAlignment,
  })?
  iconBuilder;

  // === TextButton ==========================================================

  factory DwButtonNew.text(
    String text, {
    Key? key,
    DwUiAction<T>? dwCallback,
  }) => DwButtonNew._(
    key: key,
    label: text,
    action: dwCallback,
    builder: TextButton.new,
  );

  factory DwButtonNew.textIcon(
    IconData icon,
    String label, {
    Key? key,
    DwUiAction<T>? dwCallback,
  }) => DwButtonNew._(
    key: key,
    icon: icon,
    label: label,
    action: dwCallback,
    iconBuilder: TextButton.icon,
  );

  // === Build ===============================================================

  @override
  Widget build(BuildContext context) {
    VoidCallback? onPressed = action != null ? () => action!(context) : null;

    if (builder != null) {
      return builder!(
        key: key,
        onPressed: onPressed,
        child: Text(label ?? ''),
        autofocus: false,
        clipBehavior: Clip.none,
      );
    }

    return iconBuilder!(
      key: key,
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label ?? ''),
      autofocus: false,
      clipBehavior: Clip.none,
    );
  }
}
