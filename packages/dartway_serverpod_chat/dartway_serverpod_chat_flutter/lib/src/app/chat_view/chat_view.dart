import 'package:dartway_serverpod_chat_client/dartway_serverpod_chat_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ui_kit/dw_chat_ui_kit.dart';
import 'widgets/dw_chat_message_list.dart';

/// Чистый вид чата без Scaffold, верстка сохранена как в исходном файле (внутри бывшего body).
class ChatView extends ConsumerWidget {
  final int chatId;
  final Map<String, Widget Function(DwChatMessage)>? customMessageBuilders;

  const ChatView({
    super.key,
    required this.chatId,
    this.customMessageBuilders,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: DwChatTheme.of(context).mainTheme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  DwChatMessagesList(
                    chatId: chatId,
                    customMessageBuilders: customMessageBuilders,
                  ),
                  // Should be consumer inside widgets?
                  if (DwChatTheme.of(context).settings.showScrollToBottomButton)
                    Consumer(
                      builder:
                          (BuildContext context, WidgetRef ref, Widget? child) {
                        return ref.watch(
                          chatUIStateProvider(chatId).select(
                            (state) => state.showScrollToBottom,
                          ),
                        )
                            ? Positioned(
                                bottom: 16,
                                right: 16,
                                child: DwScrollToBottomButton(),
                              )
                            : const SizedBox.shrink();
                      },
                    ),
                ],
              ),
            ),
            Consumer(
              builder: (BuildContext context, WidgetRef ref, Widget? child) {
                return ref.watch(
                  chatStateProvider(chatId).select((state) => state.isTyping),
                )
                    ? const TypingIndicator()
                    : const SizedBox.shrink();
              },
            ),
            DwChatInputBlock(),
          ],
        ),
      ),
    );
  }
}
