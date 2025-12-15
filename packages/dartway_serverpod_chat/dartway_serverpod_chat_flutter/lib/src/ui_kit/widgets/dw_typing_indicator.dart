part of '../dw_chat_ui_kit.dart';

class TypingIndicator extends StatelessWidget {
  const TypingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final chatTheme = DwChatTheme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: chatTheme.incomingBubble.backgroundColor.withOpacity(0.5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                DwTypingDot(
                  delay: 0,
                ),
                SizedBox(width: 4),
                DwTypingDot(
                  delay: 200,
                ),
                SizedBox(width: 4),
                DwTypingDot(
                  delay: 400,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
