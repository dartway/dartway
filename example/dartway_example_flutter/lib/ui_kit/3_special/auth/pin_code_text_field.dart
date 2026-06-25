part of '../../ui_kit.dart';

class PinCodeTextFieldWidget extends HookWidget {
  const PinCodeTextFieldWidget({
    super.key,
    required this.pinCode,
    required this.onChanged,
    this.externalError,
    this.internalValidator,
    this.enabled = true,
  });

  final String pinCode;
  final Function(String) onChanged;
  final String? externalError;
  final String? Function(String?)? internalValidator;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final scaffoldWidth = MediaQuery.of(context).size.width;

    final controller = useTextEditingController(text: pinCode);

    return PinCodeTextField(
      appContext: context,
      controller: controller,
      enabled: enabled,
      length: 6,
      keyboardType: TextInputType.number,
      enablePinAutofill: false,
      enableActiveFill: true,
      showCursor: false,
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      autoDisposeControllers: false,
      onChanged: onChanged,
      textStyle: AppText.body.resolveStyle(context).copyWith(
            color: context.colorScheme.onSurface,
          ),
      validator: (value) => externalError ?? internalValidator?.call(value),
      autovalidateMode: AutovalidateMode.always,
      // errorTextSpace:
      //     (effectiveError != null && effectiveError.isNotEmpty) ? 24 : 0,
      pinTheme: PinTheme(
        shape: PinCodeFieldShape.box,
        borderRadius: BorderRadius.circular(10),
        fieldHeight: scaffoldWidth * 0.14,
        fieldWidth: scaffoldWidth * 0.12,
        activeColor: context.colorScheme.surfaceContainerLow,
        selectedColor: context.colorScheme.secondaryFixedDim,
        inactiveColor: context.colorScheme.surfaceContainerLow,
        disabledColor: context.colorScheme.surfaceContainerLow,
        activeFillColor: context.colorScheme.surfaceContainerLow,
        selectedFillColor: context.colorScheme.surfaceContainerLow,
        inactiveFillColor: context.colorScheme.surfaceContainerLow,
        errorBorderColor: context.colorScheme.error,
        // effectiveError != null
        //     ?
        //     : context.colorScheme.surfaceContainerLow,
        borderWidth: 1.5,
        activeBorderWidth: 1.5,
        disabledBorderWidth: 1.5,
        inactiveBorderWidth: 1.5,
        selectedBorderWidth: 1.5,
        errorBorderWidth: 1.5,
      ),
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(6),
      ],
    );
  }
}
