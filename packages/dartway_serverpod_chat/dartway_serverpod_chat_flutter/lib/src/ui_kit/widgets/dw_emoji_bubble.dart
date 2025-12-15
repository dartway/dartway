part of '../dw_chat_ui_kit.dart';

class DwEmojiBubble extends HookWidget {
  const DwEmojiBubble({
    super.key,
    required this.messageText,
    required this.isMe,
  });

  final String messageText;
  final bool isMe;

  final double maxEmojiSize = 96;

  // Извлекаем эмодзи из текста
  List<String> _extractEmojis(String text) {
    final emojiRegExp = RegExp(
        r'[\u{1F300}-\u{1F5FF}\u{1F600}-\u{1F64F}\u{1F680}-\u{1F6FF}\u{1F700}-\u{1F77F}\u{1F780}-\u{1F7FF}\u{1F800}-\u{1F8FF}\u{1F900}-\u{1F9FF}\u{1FA00}-\u{1FA6F}\u{1FA70}-\u{1FAFF}\u{2702}-\u{27B0}\u{24C2}-\u{1F251}]',
        unicode: true);
    return emojiRegExp
        .allMatches(text)
        .map((match) => match.group(0)!)
        .toList();
  }

  // Определяем размер эмодзи в зависимости от их количества
  double _getEmojiSize(int count) {
    if (count == 1) return maxEmojiSize * 1.0;
    if (count == 2) return maxEmojiSize * 0.7;
    if (count == 3) return maxEmojiSize * 0.5;
    return maxEmojiSize * 0.2;
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme = DwChatTheme.of(context);

    final bubbleTheme = isMe ? theme.outgoingBubble : theme.incomingBubble;

    final emojis = _extractEmojis(messageText);
    final emojiSize = _getEmojiSize(emojis.length);

    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      alignment: WrapAlignment.start,
      children: emojis.map((emoji) {
        return Text(
          emoji,
          style: isMe
              ? bubbleTheme.outgoingTextStyle?.copyWith(fontSize: emojiSize)
              : bubbleTheme.incomingTextStyle?.copyWith(fontSize: emojiSize) ??
                  TextStyle(
                    color: bubbleTheme.outgoingTextStyle?.color ?? Colors.black,
                    fontSize: emojiSize,
                  ),
        );
      }).toList(),
    );
  }
}
