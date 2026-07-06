import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:dartway_example_client/dartway_example_client.dart';
import 'package:dartway_example_flutter/core/user_profile_provider.dart';
import 'package:dartway_example_flutter/ui_kit/ui_kit.dart';

class ChatMessageBubble extends ConsumerWidget {
  const ChatMessageBubble({required this.message, super.key});

  final ChatMessage message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMine = message.authorProfileId == ref.watchUserProfile.id;

    return ChatBubbleContainer(
      isMine: isMine,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isMine)
            AppText.caption(message.authorProfile?.firstName ?? 'Teammate'),
          AppText.body(message.messageText),
          AppText.caption(message.createdAt.timeLabel),
        ],
      ),
    );
  }
}
