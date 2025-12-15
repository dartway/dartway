part of '../ui_kit.dart';

/// Маска российского номера: +7 (###) ###-##-##
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

    // Убираем ведущие 7/8, если пользователь вставил номер с кодом страны/междугородним.
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

// class RuPhoneMaskFormatter extends TextInputFormatter {
//   static const _prefix = '+7 (';
//   static const _maxDigits = 10; // после кода страны

//   String _format(String digits) {
//     final b = StringBuffer(_prefix);
//     final d =
//         digits.length > _maxDigits ? digits.substring(0, _maxDigits) : digits;
//     if (d.isNotEmpty) {
//       b.write(d.substring(0, d.length.clamp(0, 3)));
//     }
//     if (d.length > 3) {
//       b.write(') ');
//       b.write(d.substring(3, d.length.clamp(3, 6)));
//     }
//     if (d.length > 6) {
//       b.write('-');
//       b.write(d.substring(6, d.length.clamp(6, 8)));
//     }
//     if (d.length > 8) {
//       b.write('-');
//       b.write(d.substring(8, d.length.clamp(8, 10)));
//     }
//     return b.toString();
//   }

//   @override
//   TextEditingValue formatEditUpdate(
//       TextEditingValue oldValue, TextEditingValue newValue) {
//     // Все цифры из ввода
//     var digits = newValue.text.replaceAll(RegExp(r'\D'), '');

//     // Нормализация: 8XXXXXXXXXX -> 7XXXXXXXXXX
//     if (digits.startsWith('8')) {
//       digits = '7${digits.substring(1)}';
//     }
//     // Отбрасываем ведущую 7 (код страны) — дальше форматируем только 10 цифр номера
//     if (digits.startsWith('7')) {
//       digits = digits.substring(1);
//     }

//     final text = _format(digits);
//     return TextEditingValue(
//       text: text,
//       selection: TextSelection.collapsed(offset: text.length),
//       composing: TextRange.empty,
//     );
//   }
// }
