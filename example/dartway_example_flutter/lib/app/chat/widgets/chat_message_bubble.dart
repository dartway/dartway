import 'package:dartway_example_flutter/core/profile/my_profile.dart';
import 'package:dartway_example_flutter/ui_kit/ui_kit.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';
import 'package:flutter/material.dart';

class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({required this.message, super.key});

  final ChatMessageView message;

  @override
  Widget build(BuildContext context) {
    final isMine = message.author.id == context.profile.id;

    return ChatBubbleContainer(
      isMine: isMine,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isMine) AppText.caption(message.author.firstName),
          AppText.body(message.text),
          AppText.caption(message.createdAt.timeLabel),
        ],
      ),
    );
  }
}
