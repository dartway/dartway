import 'package:dartway_example_flutter/core/dw_core.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:dartway_example_client/dartway_example_client.dart';
import 'package:dartway_example_flutter/app/chat/widgets/chat_message_bubble.dart';
import 'package:dartway_example_flutter/core/app_backend_filters.dart';
import 'package:dartway_example_flutter/core/app_l10n.dart';
import 'package:dartway_example_flutter/ui_kit/ui_kit.dart';

/// Live message list: new messages arrive through the framework's realtime
/// subscription — no polling, no manual socket code.
class ChatMessageList extends ConsumerWidget implements DwFeature {
  const ChatMessageList({required this.channel, super.key});

  final ChatChannel channel;

  @override
  DwFeatureSpec get dwFeature => const DwFeatureSpec(
    id: 'chat/message-list',
    title: 'Realtime staff chat',
    purpose:
        'Coaches and admins keep one running conversation about the club day.',
    behaviors: [
      'Messages appear for every staff member without a refresh.',
      'Each message shows its author and time.',
    ],
    requirements: [
      'Clients never receive staff messages — the access filter is the '
          'enforcement, not the UI.',
    ],
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(
          dw.repo.modelList<ChatMessage>(
            backendFilter: AppBackendFilters.channelMessages(channel.id!),
          ),
        )
        .dwBuildListAsync(
          loadingItemsCount: 5,
          childBuilder: (messages) {
            if (messages.isEmpty) {
              return Center(child: AppText.body(context.l10n.sayHiToTeam));
            }

            final sorted = [...messages]
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

            return ListView.builder(
              reverse: true,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: sorted.length,
              itemBuilder: (context, index) =>
                  ChatMessageBubble(message: sorted[index]),
            );
          },
        );
  }
}
