part of '../ui_kit.dart';

/// A phone number field: digits, and the characters people type around them —
/// a leading plus, spaces, dashes, parentheses. No national mask: the number
/// is read by its digits, so `+44 20 7946 0958` and `8 (999) 123-45-67` both
/// fit, and the rule deciding what a valid number is stays in one place — the
/// [validator] a screen passes, usually the shared `AuthIdentifier`.
class PhoneTextField extends StatelessWidget {
  const PhoneTextField({
    super.key,
    required this.value,
    required this.onChanged,
    this.validator,
    this.enabled,
    this.focusNode,
    this.labelText,
    this.hintText,
    this.textInputAction,
    this.autofillHints = const [AutofillHints.telephoneNumber],
  });

  final String value;
  final ValueChanged<String> onChanged;

  /// Why the typed number is not acceptable, or `null` when it is.
  final String? Function(String value)? validator;

  final bool? enabled;
  final FocusNode? focusNode;
  final String? labelText;
  final String? hintText;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;

  @override
  Widget build(BuildContext context) {
    return AppTextFormField(
      value: value,
      onChanged: onChanged,
      enabled: enabled,
      focusNode: focusNode,
      labelText: labelText,
      hintText: hintText,
      keyboardType: TextInputType.phone,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      inputFormatters: [PhoneInputFormatter()],
      validator: (text) => validator?.call(text ?? ''),
    );
  }
}
