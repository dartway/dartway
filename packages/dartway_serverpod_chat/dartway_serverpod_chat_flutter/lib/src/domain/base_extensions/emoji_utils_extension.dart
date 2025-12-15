part of '../domain.dart';

extension StringEmojiExtension on String {
  bool get isOnlyEmoji {
    // Удаляем пробелы и другие невидимые символы, если нужно проверять только эмодзи
    final textWithoutSpaces = replaceAll(RegExp(r'\s+'), '');
    if (textWithoutSpaces.isEmpty) return false;

    // Регулярное выражение для эмодзи (охватывает основные диапазоны Unicode)
    final emojiRegExp = RegExp(
      r'[\u{1F300}-\u{1F5FF}\u{1F600}-\u{1F64F}\u{1F680}-\u{1F6FF}\u{1F700}-\u{1F77F}\u{1F780}-\u{1F7FF}\u{1F800}-\u{1F8FF}\u{1F900}-\u{1F9FF}\u{1FA00}-\u{1FA6F}\u{1FA70}-\u{1FAFF}\u{2702}-\u{27B0}\u{24C2}-\u{1F251}]',
      unicode: true,
    );

    // Проверяем, что каждый символ в строке является эмодзи
    return textWithoutSpaces.runes.every((rune) {
      final char = String.fromCharCode(rune);
      return emojiRegExp.hasMatch(char);
    });
  }
}
