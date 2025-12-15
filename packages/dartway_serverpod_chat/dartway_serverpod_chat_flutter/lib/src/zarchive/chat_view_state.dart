// import 'dart:async';
// import 'dart:developer';

// import 'package:collection/collection.dart';
// import 'package:dartway_serverpod_chat_flutter/dartway_serverpod_chat_flutter.dart';
// import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
// import 'package:flutter/material.dart';
// import 'package:freezed_annotation/freezed_annotation.dart';
// import 'package:riverpod_annotation/riverpod_annotation.dart';
// import 'package:scrollview_observer/scrollview_observer.dart';

// import '../../../ui/widget/message_bubbles/widgets/voice_message/state/voice_message_bubble_state.dart';

// part 'chat_view_state.freezed.dart';
// part 'chat_view_state.g.dart';

// enum ChatViewState { hasMessages, noData, loading, error }

// @freezed
// abstract class ChatStateModel with _$ChatStateModel {
//   const factory ChatStateModel({
//     required ChatViewState viewState,
//     @Default([]) List<DwChatMessage> messages,
//     int? lastReadMessageId, // последнее прочитанное сообщение в чате
//     @Default(false) bool isTyping,
//     required ScrollController scrollController,
//     required ListObserverController observerController,
//     required ChatScrollObserver chatObserver,
//     DwChatMessage? repliedMessage,
//     DwChatMessage? editedMessage,
//   }) = _ChatStateModel;
// }

// @Riverpod(keepAlive: true)
// class ChatState extends _$ChatState {
//   StreamSubscription<SerializableModel>? _updatesSubscription;

//   @override
//   ChatStateModel build(int chatId) {
//     ref.onDispose(() {
//       _updatesSubscription?.cancel();
//       state.scrollController.dispose();
//       // TODO: rework
//       ref.invalidate(voiceMessageBubbleStateProvider);
//     });

//     // Инициализация контроллеров
//     final scrollController = ScrollController();
//     final observerController = ListObserverController(
//       controller: scrollController,
//     );
//     final chatObserver = ChatScrollObserver(observerController);

//     _setupUpdatesStream();
//     // TODO update
//     // ref.listen(nitSocketStateProvider, (previous, next) {
//     //   if (next.websocketStatus == StreamingConnectionStatus.connected) {
//     //     _setupUpdatesStream();
//     //   }
//     // });

//     return ChatStateModel(
//       viewState: ChatViewState.loading,
//       scrollController: scrollController,
//       observerController: observerController,
//       chatObserver: chatObserver,
//     );
//   }

//   void _setupUpdatesStream() {
//     _updatesSubscription = dw.client.chat.updatesStream(chatId: chatId).listen(
//       (update) {
//         if (update is DwChatInitialData) {
//           // ref.updateRepository(update.additionalEntities);

//           state = state.copyWith(
//             viewState: update.messages.isEmpty
//                 ? ChatViewState.noData
//                 : ChatViewState.hasMessages,
//             messages: update.messages,
//             lastReadMessageId: update.lastReadMessageId,
//             isTyping: false,
//           );
//         } else if (update is DwChatMessage) {
//           state.chatObserver.standby();

//           final idx = state.messages.indexWhere((m) => m.id == update.id);
//           if (idx != -1) {
//             final updated = [...state.messages];
//             updated[idx] = update;
//             if (update.isDeleted) {
//               updated.removeAt(idx);
//             }

//             state = state.copyWith(messages: updated);
//           } else {
//             if (update.isDeleted) {
//               return;
//             }
//             final updatedMessages = [...state.messages];

//             final insertIndex = lowerBound(
//               updatedMessages,
//               update,
//               compare: (a, b) => a.id!.compareTo(b.id!),
//             );

//             updatedMessages.insert(insertIndex, update);

//             state = state.copyWith(messages: updatedMessages);
//           }

//           if (state.viewState == ChatViewState.noData) {
//             state = state.copyWith(viewState: ChatViewState.hasMessages);
//           }
//         } else if (update is DwChatReadMessageEvent) {
//           state = state.copyWith(lastReadMessageId: update.messageId);
//         } else if (update is DwChatTypingMessageEvent) {
//           if (update.userId != ref.watchUserProfile.id) {
//             state = state.copyWith(isTyping: update.isTyping);
//           }
//         }
//       },
//       onError: (Object error, StackTrace stackTrace) =>
//           debugPrint('$error\n$stackTrace'),
//       onDone: () => debugPrint("Chat Channel $chatId subscription done"),
//     );
//   }

//   /// Отправка сообщения
//   Future<void> sendMessage(String text, [Media? additionalAtttachment]) async {
//     state.chatObserver.standby();

//     final attachment =
//         await ref.read(attachmentStateProvider.notifier).uploadMedia();

//     if (additionalAtttachment != null) {
//       attachment.add(additionalAtttachment);
//     }
//     ref.saveModel(
//       DwChatMessage(
//         text: text,
//         userId: ref.watchUserProfile.id!,
//         chatChannelId: chatId,
//         sentAt: DateTime.now(),
//         attachmentIds: attachment.map((e) => e.id).nonNulls.toList(),
//         replyMessageId: state.repliedMessage?.id,
//       ),
//     );
//     // nitToolsCaller!.nitChat.;

//     ref.invalidate(attachmentStateProvider);
//     setRepliedMessage(null);
//   }

//   /// Отправка сообщения
//   Future<void> deleteMessage(DwChatMessage message) async {
//     state.chatObserver.standby();

//     await ref.saveModel(message.copyWith(isDeleted: true));
//   }

//   /// Отправка сообщения
//   Future<void> editMessage(String text) async {
//     if (state.editedMessage == null) {
//       log('No edited message');
//       return;
//     }

//     state.chatObserver.standby();

//     await ref.saveModel(state.editedMessage!.copyWith(text: text));
//     setEditedMessage(null);
//   }

//   bool get isEditMode => state.editedMessage != null;

//   void typingToggle(bool isTyping) {
//     log('Typing $isTyping in chat $chatId');
//     dw.client.chat.typingToggle(chatId, isTyping);
//   }

//   // /// Добавление исторических сообщений
//   // void addHistoryMessages(List<ChatMessage> historyMessages) {
//   //   if (historyMessages.isNotEmpty) {
//   //     state.chatObserver.standby(changeCount: historyMessages.length);
//   //     state = state.copyWith(
//   //       messages: [...historyMessages, ...state.messages],
//   //     );
//   //   }
//   // }

//   // /// Обновление существующего сообщения
//   // void updateMessage(ChatMessage updatedMessage) {
//   //   final updatedMessages = state.messages.map((msg) {
//   //     return msg.id == updatedMessage.id ? updatedMessage : msg;
//   //   }).toList();

//   //   state = state.copyWith(messages: updatedMessages);
//   // }

//   // void handleStreamingMessage(ChatMessage streamingMessage) {
//   //   state.chatObserver.standby(mode: ChatScrollObserverHandleMode.generative);
//   //   updateMessage(streamingMessage);
//   // }

//   void setRepliedMessage(DwChatMessage? message) {
//     state = state.copyWith(repliedMessage: message, editedMessage: null);
//   }

//   void setEditedMessage(DwChatMessage? message) {
//     state = state.copyWith(editedMessage: message, repliedMessage: null);
//   }
// }
