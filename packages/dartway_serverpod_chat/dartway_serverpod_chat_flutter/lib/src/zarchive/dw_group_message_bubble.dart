// import 'package:dartway_serverpod_chat_client/dartway_serverpod_chat_client.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_hooks/flutter_hooks.dart';
// import 'package:hooks_riverpod/hooks_riverpod.dart';

// import '../../../ui_kit/dw_chat_ui_kit.dart';

// class DwGroupMessageBubble extends HookConsumerWidget {
//   final DwChatMessage message;
//   final int chatId;

//   const DwGroupMessageBubble({
//     super.key,
//     required this.message,
//     required this.chatId,
//   });

//   @override
//   Widget build(BuildContext context, WidgetRef ref) {
//     final theme = DwChatTheme.of(context);
//     final isMe = message.userId == ref.watchUserProfile.id;
//     final bubbleTheme = isMe ? theme.outgoingBubble : theme.incomingBubble;

//     //TODO: сомнительно
//     final senderNameFuture = useMemoized(
//       () => isMe ? null : theme.groupMessageTheme.getSenderName(message.userId),
//       [isMe, message.userId],
//     );

//     final senderNameSnapshot = useFuture(senderNameFuture);

//     return Align(
//       alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
//       child: ConstrainedBox(
//         constraints: BoxConstraints(
//           maxWidth: MediaQuery.sizeOf(context).width * 0.7,
//         ),
//         child: Container(
//           margin: bubbleTheme.margin,
//           padding: bubbleTheme.padding,
//           decoration: BoxDecoration(
//             color: bubbleTheme.backgroundColor,
//             borderRadius:
//                 BorderRadius.all(Radius.circular(bubbleTheme.borderRadius)),
//             border: bubbleTheme.border,
//             boxShadow: bubbleTheme.boxShadow ??
//                 [
//                   BoxShadow(
//                     color: Colors.black.withValues(alpha: 0.1),
//                     blurRadius: 2,
//                     offset: const Offset(0, 1),
//                   ),
//                 ],
//           ),
//           child: Column(
//             crossAxisAlignment:
//                 isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               if (message.replyMessageId != null)
//                 ReplyIndicator(
//                   repliedMessageId: message.replyMessageId!,
//                   chatId: chatId,
//                 ),
//               Row(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   Flexible(
//                     child: Text(
//                       isMe ? '' : senderNameSnapshot.data ?? 'n',
//                       style: theme.groupMessageTheme.senderNameTextStyle,
//                     ),
//                   ),
//                   const Gap(8),
//                   DwMessageTime(messageSentAt: message.sentAt),
//                 ],
//               ),
//               if (message.attachmentIds?.isNotEmpty == true) ...[
//                 const Gap(8),
//                 DwMediaGrid(message: message),
//                 const Gap(8),
//               ],
//               const Gap(8),
//               if (message.text?.isOnlyEmoji == true &&
//                   (message.attachmentIds == null ||
//                       message.attachmentIds?.isEmpty == true))
//                 EmojiBubble(message: message)
//               else if (message.text?.trim().isNotEmpty == true)
//                 Text(
//                   message.text!,
//                   style: isMe
//                       ? bubbleTheme.outgoingTextStyle
//                       : bubbleTheme.incomingTextStyle,
//                 ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
