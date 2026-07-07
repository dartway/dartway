import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
import 'package:dartway_studio_bridge/dartway_studio_bridge.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:dartway_example_client/dartway_example_client.dart';
import 'package:dartway_example_flutter/app/chat/widgets/chat_message_bubble.dart';
import 'package:dartway_example_flutter/core/app_backend_filters.dart';
import 'package:dartway_example_flutter/ui_kit/ui_kit.dart';

/// Live message list: new messages arrive through the framework's realtime
/// subscription — no polling, no manual socket code.
class ChatMessageList extends ConsumerWidget implements DwFeature {
  const ChatMessageList({required this.channel, super.key});

  final ChatChannel channel;

  @override
  DwFeatureSpec get dwFeature => const DwFeatureSpec(
        id: 'chat-message-list',
        title: StudioText('Realtime staff chat', 'Живой чат команды'),
        description: StudioText(
          'A realtime chat is ~40 lines of DwCrudConfig, secure-by-default: '
              'the staff-only access filter means clients never receive it.',
          'Realtime-чат — ~40 строк DwCrudConfig, secure-by-default: '
              'staff-фильтр не отдаёт данные чата клиенту вообще.',
        ),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watchModelList<ChatMessage>(
          backendFilter: AppBackendFilters.channelMessages(channel.id!),
        )
        .dwBuildListAsync(
          loadingItemsCount: 5,
          childBuilder: (messages) {
            if (messages.isEmpty) {
              return Center(
                child: AppText.body('Say hi to the team!'),
              );
            }

            final sorted = [...messages]
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

            return ListView.builder(
              reverse: true,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: sorted.length,
              itemBuilder: (context, index) => ChatMessageBubble(
                message: sorted[index],
              ),
            );
          },
        );
  }
}
