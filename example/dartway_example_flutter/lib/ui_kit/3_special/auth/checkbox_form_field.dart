part of '../../ui_kit.dart';

class CheckboxFormField extends StatelessWidget {
  const CheckboxFormField({
    super.key,
    required this.value,
    required this.onChanged,
    required this.titleWidget,
    this.enabled = true,
    this.autovalidateMode = AutovalidateMode.onUserInteraction,
    this.validator,
    this.contentPadding,
    this.controlAffinity = ListTileControlAffinity.leading,
    this.dense,
  });

  final bool value;
  final Function(bool) onChanged;
  final Widget titleWidget;
  final bool enabled;
  final AutovalidateMode autovalidateMode;
  final String? Function(bool value)? validator;

  final EdgeInsetsGeometry? contentPadding;
  final ListTileControlAffinity controlAffinity;
  final bool? dense;

  @override
  Widget build(BuildContext context) {
    return FormField<bool>(
      initialValue: value,
      autovalidateMode: autovalidateMode,
      enabled: enabled,
      validator: (v) => validator?.call(v ?? false),
      builder: (fieldState) {
        // --- Синхронизация внешних изменений VN -> FormFieldState ---
        if ((fieldState.value ?? false) != value) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (fieldState.mounted) fieldState.didChange(value);
          });
        }

        final hasError =
            fieldState.hasError && (fieldState.errorText?.isNotEmpty ?? false);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CheckboxListTile(
              value: fieldState.value ?? false,
              onChanged: enabled
                  ? (checked) {
                      final next = checked ?? false;
                      if ((fieldState.value ?? false) != next) {
                        fieldState.didChange(next);
                      }
                      if (value != next) {
                        onChanged(next);
                      }
                    }
                  : null,
              title: titleWidget,
              dense: dense,
              contentPadding: contentPadding,
              controlAffinity: controlAffinity,
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child: hasError
                  ? Padding(
                      key: const ValueKey('error'),
                      padding: const EdgeInsetsDirectional.only(
                        start: 16.0,
                        bottom: 4.0,
                      ),
                      child: Text(
                        fieldState.errorText!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.error,
                            ),
                      ),
                    )
                  : const SizedBox(height: 0, key: ValueKey('no_error')),
            ),
          ],
        );
      },
    );
  }
}
