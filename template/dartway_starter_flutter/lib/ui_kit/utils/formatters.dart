part of '../ui_kit.dart';

/// Keeps what a phone number is typed with — digits, a plus at the start,
/// spaces, dashes and parentheses — and at most 15 digits, the longest
/// international number. Everything else is dropped as it is typed or pasted.
class PhoneInputFormatter extends TextInputFormatter {
  static const int maxDigits = 15;

  /// Besides the digits: `+`, `(`, `)`, `-` and the space, by code unit.
  static const Set<int> _separators = {0x2B, 0x28, 0x29, 0x2D, 0x20};

  static bool _isDigit(int unit) => unit >= 0x30 && unit <= 0x39;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final buffer = StringBuffer();
    var digits = 0;
    for (final unit in newValue.text.codeUnits) {
      if (_isDigit(unit)) {
        if (digits == maxDigits) continue;
        digits++;
      } else if (!_separators.contains(unit) ||
          // A plus means a country code, and only at the very start.
          (unit == 0x2B && buffer.isNotEmpty)) {
        continue;
      }
      buffer.writeCharCode(unit);
    }
    final text = buffer.toString();
    if (text == newValue.text) return newValue;
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
