part of '../dw_chat_ui_kit.dart';

class DwMessageBubbleContainer extends StatelessWidget {
  const DwMessageBubbleContainer(
      {super.key, required this.isMe, required this.children});
  final bool isMe;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final theme = DwChatTheme.of(context);
    final bubbleTheme = isMe ? theme.outgoingBubble : theme.incomingBubble;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.7,
        ),
        child: Container(
          margin: bubbleTheme.margin,
          padding: bubbleTheme.padding,
          decoration: BoxDecoration(
            color: bubbleTheme.backgroundColor,
            borderRadius:
                BorderRadius.all(Radius.circular(bubbleTheme.borderRadius)),
            border: bubbleTheme.border,
            boxShadow: bubbleTheme.boxShadow ??
                [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
          ),
          child: Column(
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: children,
          ),
        ),
      ),
    );
  }
}
