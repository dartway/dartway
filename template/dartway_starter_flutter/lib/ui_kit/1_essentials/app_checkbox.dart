part of '../ui_kit.dart';

/// A checkbox that reports a change instead of performing one.
///
/// It used to take the caller's `ValueNotifier` and write into it, which put the
/// caller's state under a kit widget's control: a screen that wanted to save on
/// change, or to refuse a change, had nowhere to stand. Value in, change out —
/// the caller decides what a change means.
class AppCheckbox extends StatelessWidget {
  const AppCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  /// A disabled checkbox still shows its value — it just cannot be changed.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Checkbox(
      value: value,
      onChanged: enabled ? (isChecked) => onChanged(isChecked ?? value) : null,
    );
  }
}
