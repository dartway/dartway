import 'dart:developer';

import 'package:dartway_serverpod_chat_flutter/dartway_serverpod_chat_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:scrollview_observer/scrollview_observer.dart';

import '../../../zarchive/chat_view_state.dart';

part '../../../buffer/chat_ui_state.freezed.dart';
part '../../../buffer/chat_ui_state.g.dart';

@freezed
abstract class ChatUIStateModel with _$ChatUIStateModel {
  const factory ChatUIStateModel({
    @Default(false) bool showScrollToBottom,
    @Default(0) int unreadCount,
    @Default(true) bool isAtBottom,
  }) = _ChatUIStateModel;
}

@Riverpod(keepAlive: false)
class ChatUIState extends _$ChatUIState {
  int? lastReadMessageId;
  @override
  ChatUIStateModel build(int chatId) {
    // ref.onDispose(() {
    // ref.invalidate(voiceMessageBubbleStateProvider);
    // });
    final chatState = ref.read(chatStateProvider(chatId));

    chatState.scrollController.addListener(_onScrollChanged);

    // Слушаем новые сообщения для UI реакций
    ref.listen(chatStateProvider(chatId).select((state) => state.messages), (
      previous,
      next,
    ) {
      if (previous != null && next.length > previous.length) {
        _handleNewMessages(previous, next);
      }
    });

    // Инициализация при загрузке
    ref.listen(chatStateProvider(chatId).select((state) => state.viewState), (
      previous,
      next,
    ) {
      if (previous == ChatViewState.loading &&
          next == ChatViewState.hasMessages) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          _scrollToBottomImmediate();
        });
      }
    });

    ref.listen(
      chatStateProvider(chatId).select((state) => state.lastReadMessageId),
      (previous, next) {
        lastReadMessageId = next;
      },
      fireImmediately: true,
    );

    ref.onDispose(() {
      chatState.scrollController.removeListener(_onScrollChanged);
    });

    return const ChatUIStateModel();
  }

  void _onScrollChanged() {
    final chatState = ref.read(chatStateProvider(chatId));
    final controller = chatState.scrollController;

    if (controller.hasClients) {
      final isAtBottom = controller.offset <= 200;

      if (state.isAtBottom != isAtBottom) {
        state = state.copyWith(
          isAtBottom: isAtBottom,
          showScrollToBottom: !isAtBottom,
        );

        if (isAtBottom) {
          state = state.copyWith(unreadCount: 0);
        } else {
          _updateUnreadCount();
        }
      }
    }
  }

  void _handleNewMessages(
    List<DwChatMessage> previous,
    List<DwChatMessage> next,
  ) {
    final newMessages = next.skip(previous.length).toList();
    final currentUserId = ref.watchUserProfile.id!;

    if (newMessages.any((msg) => msg.userId == currentUserId)) {
      _scrollToBottomWithRetry();
    } else {
      final unreadNewMessages =
          newMessages.where((msg) => msg.userId != currentUserId).toList();
      // Если пользователь внизу - сразу помечаем новые сообщения
      if (state.isAtBottom) {
        if (unreadNewMessages.isNotEmpty) {
          _markMessagesAsRead(unreadNewMessages);
        }
      } else {
        state = state.copyWith(
          unreadCount: state.unreadCount + unreadNewMessages.length,
        );
      }
    }
  }

  /// Обработка видимости сообщений (вызывается из ChatMessagesList)
  void handleVisibilityChange(ListViewObserveModel model) async {
    if (!state.isAtBottom) return;

    final chatState = ref.read(chatStateProvider(chatId));
    final currentUserId = ref.watchUserProfile.id!;

    final visibleUnreadMessages = <DwChatMessage>[];

    // Получаем видимые непрочитанные сообщения
    for (final index in model.displayingChildIndexList) {
      final reversedIndex = chatState.messages.length - 1 - index;

      if (reversedIndex >= 0 && reversedIndex < chatState.messages.length) {
        final message = chatState.messages[reversedIndex];

        if (message.userId != currentUserId) {
          visibleUnreadMessages.add(message);
        }
      }
    }

    // Помечаем как прочитанные
    if (visibleUnreadMessages.isNotEmpty &&
        (lastReadMessageId ?? 0) < visibleUnreadMessages.first.id!) {
      lastReadMessageId = visibleUnreadMessages
          .first.id!; // предварительно делаем так, чтобы не было лишних вызовов
      await _markMessagesAsRead(visibleUnreadMessages);
    }
  }

  Future<void> _markMessagesAsRead(List<DwChatMessage> messages) async {
    if (messages.isEmpty) return;

    log('Marking messages as read up to ${messages.last.id} in chat $chatId');

    await dw.client.chat.readChatMessages(
      messages.map((e) => e.id).nonNulls.toList(),
      chatId,
    );
  }

  void scrollToBottomForced() {
    _scrollToBottomImmediate();
    resetUnreadCount();
  }

  void _scrollToBottomImmediate() {
    final chatState = ref.read(chatStateProvider(chatId));
    if (chatState.scrollController.hasClients) {
      chatState.scrollController.jumpTo(0);
    }
  }

  void _scrollToBottomWithRetry() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _scrollToBottomImmediate();

      Future.delayed(const Duration(milliseconds: 100), () {
        final chatState = ref.read(chatStateProvider(chatId));
        if (chatState.scrollController.hasClients) {
          chatState.scrollController.jumpTo(0);
        }
      });
    });
  }

  void _updateUnreadCount() {
    final chatState = ref.read(chatStateProvider(chatId));
    final currentUserId = ref.watchUserProfile.id!;
    final lastReadMessageId = chatState.lastReadMessageId ?? 0;

    final unreadCount = chatState.messages
        .where(
          (msg) => msg.userId != currentUserId && msg.id! > lastReadMessageId,
        )
        .length;

    state = state.copyWith(unreadCount: unreadCount);
  }

  void resetUnreadCount() {
    state = state.copyWith(unreadCount: 0);
  }

  void scrollToMessage(int messageId) {
    final chatState = ref.read(chatStateProvider(chatId));
    final index = chatState.messages.indexWhere((msg) => msg.id == messageId);

    if (index != -1) {
      final reversedIndex = chatState.messages.length - 1 - index;
      chatState.observerController.animateTo(
        index: reversedIndex,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  bool get isUserAtBottom => state.isAtBottom;
  int get visibleUnreadCount => state.unreadCount;
  bool get shouldShowScrollButton => state.showScrollToBottom;
}
