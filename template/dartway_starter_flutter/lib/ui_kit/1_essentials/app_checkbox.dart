part of '../ui_kit.dart';

class AppCheckbox extends StatelessWidget {
  const AppCheckbox({
    super.key,
    required this.valueNotifier,
    this.checkboxSize = 24,
    this.iconSize = 16,
    this.enabled = true,
  });

  final ValueNotifier<bool> valueNotifier;
  final double checkboxSize;
  final double? iconSize;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: valueNotifier,
      builder: (context, isChecked, child) => Checkbox(
        value: isChecked,
        onChanged: (value) => valueNotifier.value = value!,
      ),
    );
  }
}
