part of '../ui_kit.dart';

class PhoneTextField extends HookWidget {
  const PhoneTextField({
    super.key,
    required this.value,
    required this.onChanged,
    this.additionValidator,
    this.enabled,
    this.focusNode,
    this.labelText,
    this.hintText = '+7 (___) ___-__-__',
    this.textInputAction,
    this.autofillHints = const [AutofillHints.telephoneNumber],
  });

  final String value;
  final ValueChanged<String> onChanged;

  final String? Function(String value)? additionValidator;

  final bool? enabled;
  final FocusNode? focusNode;
  final String? labelText;
  final String? hintText;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;

  @override
  Widget build(BuildContext context) {
    // The caller's focus node, or the field's own — a hook is called on every
    // build, so the own one exists either way and is disposed with the field.
    final ownFocusNode = useFocusNode();
    final node = focusNode ?? ownFocusNode;
    // This widget as last built, for the listener registered by an earlier
    // build.
    final latest = useRef(this)..value = this;

    useEffect(() {
      void onFocusChange() {
        final prefix = RuPhoneMaskFormatter.minText();
        final text = latest.value.value;

        if (node.hasFocus && text.isEmpty) {
          latest.value.onChanged(prefix);
        }
        if (!node.hasFocus && text.length == prefix.length) {
          latest.value.onChanged('');
        }
      }

      node.addListener(onFocusChange);
      return () => node.removeListener(onFocusChange);
    }, [node]);

    return AppTextFormField(
      value: value,
      onChanged: onChanged,
      enabled: enabled,
      focusNode: node,
      labelText: labelText,
      hintText: hintText,
      keyboardType: TextInputType.phone,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      inputFormatters: [RuPhoneMaskFormatter()],
      validator: (value) {
        final text = value ?? '';
        final digits = text.replaceAll(RegExp(r'\D'), '');
        if (text.isEmpty ||
            text.length == RuPhoneMaskFormatter.minText().length) {
          return context.l10n.requiredField;
        }
        if (digits.length < 11) {
          return context.l10n.invalidPhoneNumber;
        }
        if (additionValidator != null) {
          return additionValidator!(text);
        }
        return null;
      },
    );
  }
}
