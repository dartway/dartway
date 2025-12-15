import 'package:dartway_serverpod_chat_client/dartway_serverpod_chat_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:scrollview_observer/scrollview_observer.dart';

import '../logic/chat_state.dart';
import 'dw_message_widget.dart';

class DwChatMessagesList extends HookConsumerWidget {
  final int chatId;
  final Map<String, Widget Function(DwChatMessage)>? customMessageBuilders;

  const DwChatMessagesList({
    super.key,
    required this.chatId,
    this.customMessageBuilders,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatState = ref.watch(dwChatStateProvider(chatId));

    if (chatState.viewState == DwChatViewState.noData) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Нет сообщений'),
          ],
        ),
      );
    }
    // TODO: restore this
    useEffect(() {
      // Для того чтобы стриггерить uiNotifier.handleVisibilityChange
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // TODO: непонятно, зачем это нужно
        // final chatState = ref.read(dwChatStateProvider(chatId));
        chatState.observerController.controller!.jumpTo(1);
      });
      return null;
    }, [chatId]);

    return ListViewObserver(
      controller: chatState.observerController,
      // TODO: restore this
      // onObserve: uiNotifier.handleVisibilityChange,
      child: NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification notification) {
          if (notification is ScrollUpdateNotification &&
              notification.scrollDelta != null &&
              notification.scrollDelta! > 0) {
            FocusScope.of(context).unfocus();
          }
          return false;
        },
        child: ListView.builder(
          physics: ChatObserverBouncingScrollPhysics(
            observer: chatState.chatObserver,
          ),
          controller: chatState.scrollController,
          reverse: true,
          itemCount: chatState.messages.length,
          cacheExtent: 1000,
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemBuilder: (context, index) {
            final reversedIndex = chatState.messages.length - 1 - index;
            final message = chatState.messages[reversedIndex];

            final customWidget = customMessageBuilders != null &&
                    message.customMessageType?.type != null
                ? customMessageBuilders![message.customMessageType!.type]
                    ?.call(message)
                : null;

            return customWidget ??
                DwMessageBubble(
                  key: ValueKey('message-${message.id}'),
                  chatId: chatId,
                  message: message,
                );
          },
        ),
      ),
    );
  }
}
