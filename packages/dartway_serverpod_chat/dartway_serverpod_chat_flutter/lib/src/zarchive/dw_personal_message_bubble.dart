// import 'package:dartway_serverpod_chat_flutter/dartway_serverpod_chat_flutter.dart';
// import 'package:flutter/material.dart';
// import 'package:hooks_riverpod/hooks_riverpod.dart';

// class PersonalMessageBubble extends ConsumerWidget {
//   final DwChatMessage message;
//   final Map<String, Widget Function(DwChatMessage)>? customMessageBuilders;
//   final int chatId;

//   const PersonalMessageBubble({
//     super.key,
//     required this.message,
//     this.customMessageBuilders,
//     required this.chatId,
//   });

//   @override
//   Widget build(BuildContext context, WidgetRef ref) {
//     final theme = DwChatTheme.of(context);
//     final isMe = message.userId == ref.watchUserProfile.id;

//     final bubbleTheme = isMe ? theme.outgoingBubble : theme.incomingBubble;

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
//               if (message.attachmentIds?.isNotEmpty == true) ...[
//                 MediaGrid(message: message),
//                 const Gap(8),
//               ],
//               if (message.text?.isOnlyEmoji == true &&
//                   (message.attachmentIds == null ||
//                       message.attachmentIds?.isEmpty == true))
//                 EmojiBubble(message: message)
//               else if (message.text?.trim().isNotEmpty == true &&
//                   message.text?.trim() != 'Голосовое сообщение') //TODO: плохо
//                 Text(
//                   message.text!,
//                   style: isMe
//                       ? bubbleTheme.outgoingTextStyle
//                       : bubbleTheme.incomingTextStyle ??
//                           TextStyle(
//                             color: bubbleTheme.incomingTextStyle?.color ??
//                                 Colors.black,
//                             fontSize: 16,
//                             height: 1.3,
//                           ),
//                 ),
//               const Gap(6),
//               Row(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   DwMessageTime(messageSentAt: message.sentAt),
//                   const Gap(6),
//                   ReadIndicator(message: message),
//                 ],
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
