part of '../ui_kit.dart';

class AppTextFormField extends HookWidget {
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
  Widget build(BuildContext context) {
    final controller = useTextEditingController(text: value);
    // This widget as last built, for the callbacks below that run after the
    // build that registered them.
    final latest = useRef(this)..value = this;

    // True only while the parent's value is being written into the
    // controller, so the resulting notification is not echoed straight back.
    final adoptingExternalValue = useRef(false);

    // Adopt the parent's value **only when the parent actually changed it** —
    // the comparison is against the value of the previous build, not against
    // a value this widget tracked for itself.
    //
    // The difference is the whole bug this replaced. `onChanged` is delivered
    // a frame late (see below), so between a keystroke and the parent catching
    // up there is a window in which [value] is stale. Any rebuild landing in
    // that window — a network response, a neighbouring provider, a theme
    // change — used to look like "the parent set a new value" and overwrote
    // the field with the stale text, cursor to the end. Typing then continued
    // on a truncated prefix: "Fitness Club" was saved as "Fitne".
    //
    // The previous value cannot be stale in that way: it is what the parent
    // held on the previous build, so a difference means a real external
    // change.
    //
    // The adoption itself waits for the end of the frame. Writing the
    // controller here, during a build, makes the `TextFormField` report the
    // change to its enclosing `Form`, which rebuilds — and a `Form` above the
    // widget being built may not be marked dirty mid-build: the phone field,
    // putting its prefix in on focus, asserted on exactly that.
    useValueChanged<String, void>(value, (_, _) {
      final adopted = value;
      if (adopted == controller.text) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Superseded by a newer parent value, or already typed in.
        if (!context.mounted ||
            latest.value.value != adopted ||
            controller.text == adopted) {
          return;
        }
        adoptingExternalValue.value = true;
        _syncControllerText(
          controller,
          adopted,
          placeCursorAtEnd: latest.value.cursorToEndOnExternalUpdate,
        );
        adoptingExternalValue.value = false;
      });
    });

    useEffect(() {
      void onControllerChanged() {
        if (adoptingExternalValue.value) return;

        final text = controller.text;
        if (text == latest.value.value) return;

        // Defer: notifying during a build would rebuild the parent mid-frame.
        // Every keystroke schedules one of these, and they all run in the
        // same post-frame batch — the guard lets only the one still matching
        // the field through, so the parent hears the latest text instead of a
        // replay.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted || controller.text != text) return;
          latest.value.onChanged(text);
        });
      }

      controller.addListener(onControllerChanged);
      return () => controller.removeListener(onControllerChanged);
    }, [controller]);

    return TextFormField(
      controller: controller,
      enabled: enabled,
      readOnly: readOnly,
      focusNode: focusNode,
      keyboardType: keyboardType,
      textAlign: textAlign ?? TextAlign.start,
      minLines: minLines,
      maxLines: maxLines,
      maxLength: maxLength,
      inputFormatters: inputFormatters,
      validator: validator,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        counterText: '',
      ),
    );
  }

  static void _syncControllerText(
    TextEditingController controller,
    String newText, {
    required bool placeCursorAtEnd,
  }) {
    final newSelection = placeCursorAtEnd
        ? TextSelection.collapsed(offset: newText.length)
        : controller.selection;

    // Reset composing needed to prevent IME session from hanging
    controller.value = TextEditingValue(
      text: newText,
      selection: newSelection,
      composing: TextRange.empty,
    );
  }
}
