part of '../ui_kit.dart';

/// Russian phone mask: +7 (###) ###-##-##
class RuPhoneMaskFormatter extends TextInputFormatter {
  static const String _prefix = '+7 (';

  static String minText() => _prefix;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final raw = newValue.text;
    var digits = raw.replaceAll(RegExp(r'\D'), '');

    // Drop a leading 7/8 — the user pasted the number with a country or
    // long-distance code in front of it.
    if (raw.startsWith('+7') && digits.startsWith('7')) {
      digits = digits.substring(1);
    } else if (digits.startsWith('8')) {
      digits = digits.substring(1);
    } else if (digits.startsWith('7') && !raw.startsWith('+7')) {
      digits = digits.substring(1);
    }

    if (digits.length > 10) digits = digits.substring(0, 10);

    final formatted = _format(digits);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
      composing: TextRange.empty,
    );
  }

  static String _format(String digits) {
    final b = StringBuffer(_prefix);
    var i = 0;

    while (i < digits.length && i < 3) {
      b.write(digits[i++]);
    }
    if (i < 3) return b.toString();

    b.write(') ');
    while (i < digits.length && i < 6) {
      b.write(digits[i++]);
    }
    if (i < 6) return b.toString();

    b.write('-');
    while (i < digits.length && i < 8) {
      b.write(digits[i++]);
    }
    if (i < 8) return b.toString();

    b.write('-');
    while (i < digits.length && i < 10) {
      b.write(digits[i++]);
    }
    return b.toString();
  }
}
