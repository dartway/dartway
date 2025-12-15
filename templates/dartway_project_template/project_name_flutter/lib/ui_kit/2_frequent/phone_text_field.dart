part of '../ui_kit.dart';

class PhoneTextField extends StatefulWidget {
  const PhoneTextField({
    super.key,
    required this.value,
    required this.onChanged,
    this.additionValidator,
    this.enabled,
    this.focusNode,
    this.labelText = 'Phone',
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
  State<PhoneTextField> createState() => _PhoneTextFieldState();
}

class _PhoneTextFieldState extends State<PhoneTextField> {
  late FocusNode _focusNode;
  bool _ownFocus = false;

  @override
  void initState() {
    super.initState();
    _attachFocusNode(widget.focusNode);
  }

  @override
  void didUpdateWidget(covariant PhoneTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      _detachFocusNode();
      _attachFocusNode(widget.focusNode);
    }
  }

  void _attachFocusNode(FocusNode? external) {
    if (external != null) {
      _focusNode = external;
      _ownFocus = false;
    } else {
      _focusNode = FocusNode();
      _ownFocus = true;
    }
    _focusNode.addListener(_handleFocusChange);
  }

  void _detachFocusNode() {
    _focusNode.removeListener(_handleFocusChange);
    if (_ownFocus) {
      _focusNode.dispose();
    }
  }

  void _handleFocusChange() {
    final prefix = RuPhoneMaskFormatter.minText();
    final text = widget.value;

    if (_focusNode.hasFocus && text.isEmpty) {
      widget.onChanged(prefix);
    }
    if (!_focusNode.hasFocus && text.length == prefix.length) {
      widget.onChanged('');
    }
  }

  @override
  void dispose() {
    _detachFocusNode();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppTextFormField(
      value: widget.value,
      onChanged: widget.onChanged,
      enabled: widget.enabled,
      focusNode: _focusNode,
      labelText: widget.labelText,
      hintText: widget.hintText,
      keyboardType: TextInputType.phone,
      textInputAction: widget.textInputAction,
      autofillHints: widget.autofillHints,
      inputFormatters: [RuPhoneMaskFormatter()],
      validator: (value) {
        final text = value ?? '';
        final digits = text.replaceAll(RegExp(r'\D'), '');
        if (text.isEmpty ||
            text.length == RuPhoneMaskFormatter.minText().length) {
          return 'Required field';
        }
        if (digits.length < 11) {
          return 'Invalid number';
        }
        if (widget.additionValidator != null) {
          return widget.additionValidator!(text);
        }
        return null;
      },
    );
  }
}
