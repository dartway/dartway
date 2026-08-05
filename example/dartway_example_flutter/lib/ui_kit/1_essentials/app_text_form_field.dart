part of '../ui_kit.dart';

class AppTextFormField extends StatefulWidget {
  const AppTextFormField({
    super.key,
    // main contract: controlled value + onChanged
    required this.value,
    required this.onChanged,
    this.enabled,
    this.focusNode,
    this.maxLength,
    this.labelText,
    this.hintText,
    this.inputFormatters,
    this.validator,
    this.textAlign,
    this.keyboardType,
    this.minLines = 1,
    this.maxLines = 1,
    this.textInputAction,
    this.autofillHints,
    this.obscureText = false,
    this.readOnly = false,

    /// If true — when the text is updated externally, the cursor is placed at the end.
    /// This is the most predictable for masks/formatters.
    this.cursorToEndOnExternalUpdate = true,
  });

  final String value;
  final ValueChanged<String> onChanged;

  final bool? enabled;
  final bool readOnly;
  final bool obscureText;
  final FocusNode? focusNode;
  final int? maxLength;
  final String? labelText;
  final String? hintText;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  final TextAlign? textAlign;
  final TextInputType? keyboardType;
  final int minLines;
  final int maxLines;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final bool cursorToEndOnExternalUpdate;

  @override
  State<AppTextFormField> createState() => _AppTextFormFieldState();

  /// Convenient adapter if there is still a `ValueNotifier<String>` somewhere.
  factory AppTextFormField.fromStringNotifier({
    Key? key,
    required ValueNotifier<String> valueNotifier,
    bool? enabled,
    FocusNode? focusNode,
    int? maxLength,
    String? labelText,
    String? hintText,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    TextAlign? textAlign,
    TextInputType? keyboardType,
    int minLines = 1,
    int maxLines = 1,
    TextInputAction? textInputAction,
    Iterable<String>? autofillHints,
    bool obscureText = false,
    bool readOnly = false,
    bool cursorToEndOnExternalUpdate = true,
  }) {
    return AppTextFormField(
      key: key,
      value: valueNotifier.value,
      onChanged: (v) => valueNotifier.value = v,
      enabled: enabled,
      focusNode: focusNode,
      maxLength: maxLength,
      labelText: labelText,
      hintText: hintText,
      inputFormatters: inputFormatters,
      validator: validator,
      textAlign: textAlign,
      keyboardType: keyboardType,
      minLines: minLines,
      maxLines: maxLines,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      obscureText: obscureText,
      readOnly: readOnly,
      cursorToEndOnExternalUpdate: cursorToEndOnExternalUpdate,
    );
  }
}

class _AppTextFormFieldState extends State<AppTextFormField> {
  late final TextEditingController _controller;

  /// True only while this state is writing the parent's value into the
  /// controller, so the resulting notification is not echoed straight back.
  bool _adoptingExternalValue = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    _controller.addListener(_onControllerChanged);
  }

  /// Adopt the parent's value **only when the parent actually changed it** —
  /// the comparison is against the previous widget, not against a value this
  /// state tracked for itself.
  ///
  /// The difference is the whole bug this replaced. `onChanged` is delivered a
  /// frame late (see below), so between a keystroke and the parent catching up
  /// there is a window in which `widget.value` is stale. Any rebuild landing in
  /// that window — a network response, a neighbouring provider, a theme change —
  /// used to look like "the parent set a new value" and overwrote the field with
  /// the stale text, cursor to the end. Typing then continued on a truncated
  /// prefix: "Fitness Club" was saved as "Fitne".
  ///
  /// `oldWidget.value` cannot be stale in that way: it is what the parent held
  /// on the previous build, so a difference means a real external change.
  @override
  void didUpdateWidget(covariant AppTextFormField oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.value != oldWidget.value && widget.value != _controller.text) {
      _adoptingExternalValue = true;
      _syncControllerText(
        widget.value,
        placeCursorAtEnd: widget.cursorToEndOnExternalUpdate,
      );
      _adoptingExternalValue = false;
    }
  }

  void _onControllerChanged() {
    if (_adoptingExternalValue) return;

    final text = _controller.text;
    if (text == widget.value) return;

    // Defer: notifying during a build would rebuild the parent mid-frame.
    // Every keystroke schedules one of these, and they all run in the same
    // post-frame batch — the guard lets only the one still matching the field
    // through, so the parent hears the latest text instead of a replay.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _controller.text != text) return;
      widget.onChanged(text);
    });
  }

  void _syncControllerText(String newText, {required bool placeCursorAtEnd}) {
    final newSelection = placeCursorAtEnd
        ? TextSelection.collapsed(offset: newText.length)
        : _controller.selection;

    // Reset composing needed to prevent IME session from hanging
    _controller.value = TextEditingValue(
      text: newText,
      selection: newSelection,
      composing: TextRange.empty,
    );
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _controller,
      enabled: widget.enabled,
      readOnly: widget.readOnly,
      focusNode: widget.focusNode,
      keyboardType: widget.keyboardType,
      textAlign: widget.textAlign ?? TextAlign.start,
      minLines: widget.minLines,
      maxLines: widget.maxLines,
      maxLength: widget.maxLength,
      inputFormatters: widget.inputFormatters,
      validator: widget.validator,
      textInputAction: widget.textInputAction,
      autofillHints: widget.autofillHints,
      obscureText: widget.obscureText,
      decoration: InputDecoration(
        labelText: widget.labelText,
        hintText: widget.hintText,
        counterText: '',
      ),
    );
  }
}
