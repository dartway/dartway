import 'package:flutter/material.dart';
import 'package:swipe_to/swipe_to.dart';

class DwMessageBubbleSwipes extends StatelessWidget {
  const DwMessageBubbleSwipes({
    super.key,
    required this.isMe,
    required this.messageBubbleWidget,
  });

  final bool isMe;
  final Widget messageBubbleWidget;

  @override
  Widget build(BuildContext context) {
    return SwipeTo(
      onRightSwipe: !isMe
          ? (details) {
              // TODO: restore
              // chatNotifier.setRepliedMessage(message);
              FocusScope.of(context).requestFocus();
            }
          : null,
      onLeftSwipe: isMe
          ? (details) {
              // TODO: restore
              // chatNotifier.setRepliedMessage(message);
              FocusScope.of(context).requestFocus();
            }
          : null,
      child: messageBubbleWidget,
    );
  }
}
