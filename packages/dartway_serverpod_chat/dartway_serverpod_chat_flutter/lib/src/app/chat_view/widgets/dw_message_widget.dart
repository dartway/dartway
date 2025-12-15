import 'package:dartway_serverpod_chat_client/dartway_serverpod_chat_client.dart';
import 'package:dartway_serverpod_chat_flutter/dartway_serverpod_chat_flutter.dart';
import 'package:dartway_serverpod_chat_flutter/src/app/chat_view/logic/chat_state.dart';
import 'package:dartway_serverpod_chat_flutter/src/app/chat_view/widgets/dw_message_bubble_swipes.dart';
import 'package:dartway_serverpod_chat_flutter/src/domain/domain.dart';
import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dw_message_status_widget.dart';

class DwMessageBubble extends ConsumerWidget {
  const DwMessageBubble({
    super.key,
    required this.message,
    required this.chatId,
  });

  final int chatId;
  final DwChatMessage message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = DwChatTheme.of(context);
    final isMe = message.userId == ref.watchSignedInUserId;
    final bubbleTheme = isMe ? theme.outgoingBubble : theme.incomingBubble;
    final chatNotifier = ref.read(dwChatStateProvider(chatId).notifier);

    return ConditionalParentWidget(
      condition: theme.settings.enableMessageOverlay,
      parentBuilder: (Widget child) => DwBubbleOverlay(
        isMe: isMe,
        onReply: () {
          chatNotifier.setRepliedMessage(message);
          FocusScope.of(context).requestFocus();
        },
        onDelete: () async {
          await chatNotifier.deleteMessage(message);
          chatNotifier.setRepliedMessage(null);
          chatNotifier.setEditedMessage(null);
        },
        onEdit: () {
          chatNotifier.setEditedMessage(message);
          FocusScope.of(context).requestFocus();
        },
        onReact: (emoji) {
          // chatNotifier.reactToMessage(message.id!, emoji);
        },
        isCustomMessage: message.customMessageType?.type != null,
        child: child,
      ),
      child: DwMessageBubbleSwipes(
        isMe: isMe,
        messageBubbleWidget: DwMessageBubbleContainer(
          isMe: isMe,
          children: [
            if (message.replyMessageId != null)
              DwReplyIndicator(
                repliedMessageId: message.replyMessageId!,
                chatId: chatId,
              ),
            if (ChatBubbleType.group == theme.settings.chatBubbleType && !isMe)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      'TODO: Имя отправителя',
                      style: theme.groupMessageTheme.senderNameTextStyle,
                    ),
                  ),
                  const Gap(8),
                  DwMessageTime(messageSentAt: message.sentAt),
                ],
              ),
            // if (message.attachmentIds?.isNotEmpty == true) ...[
            //   MediaGrid(message: message),
            //   const Gap(8),
            // ],
            if (message.text?.isOnlyEmoji == true &&
                (message.attachmentIds == null ||
                    message.attachmentIds?.isEmpty == true))
              DwEmojiBubble(messageText: message.text!, isMe: isMe)
            else if (message.text?.trim().isNotEmpty == true &&
                message.text?.trim() != 'Голосовое сообщение') //TODO: плохо
              Text(
                message.text!,
                style: isMe
                    ? bubbleTheme.outgoingTextStyle
                    : bubbleTheme.incomingTextStyle ??
                        TextStyle(
                          color: bubbleTheme.incomingTextStyle?.color ??
                              Colors.black,
                          fontSize: 16,
                          height: 1.3,
                        ),
              ),
            const Gap(6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                DwMessageTime(messageSentAt: message.sentAt),
                const Gap(6),
                DwMessageStatusWidget(message: message),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
