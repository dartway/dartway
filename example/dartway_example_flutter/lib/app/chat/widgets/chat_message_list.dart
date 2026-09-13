import 'package:dartway_example_flutter/app/chat/widgets/chat_message_bubble.dart';
import 'package:dartway_example_flutter/core/app_l10n.dart';
import 'package:dartway_example_flutter/core/dw_core.dart';
import 'package:dartway_example_flutter/shared/placeholder_views.dart';
import 'package:dartway_example_flutter/shared/widgets/load_failed_message.dart';
import 'package:dartway_example_flutter/ui_kit/ui_kit.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// The messages of one channel, newest at the bottom, older pages loaded as
/// the list is scrolled up to them. New messages arrive through the channel —
/// no polling, no socket code.
class ChatMessageList extends ConsumerWidget implements DwFeature {
  const ChatMessageList({required this.channel, super.key});

  final ChatChannelView channel;

  @override
  DwFeatureSpec get dwFeature => const DwFeatureSpec(
    id: 'chat/message-list',
    title: 'Realtime staff chat',
    purpose:
        'Coaches and admins keep one running conversation about the club day.',
    behaviors: [
      'Messages appear for every staff member without a refresh.',
      'Each message shows its author and time.',
      'Scrolling up to the oldest loaded message loads the page before it; a '
          'page that fails to load offers a retry in its place.',
    ],
    requirements: [
      'Clients never receive staff messages — the server refuses them the '
          'read and the channel, whatever the UI shows.',
    ],
    implementationNotes: [
      'Pages go backwards by id (a cursor request), so a message arriving '
          'while older pages load neither shifts nor repeats them.',
    ],
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = dw.pages(ListChatMessages(channelId: channel.id));

    return ref
        .watch(messages)
        .section(
          loadingValue: DwPagedData(
            PlaceholderViews.listOf(PlaceholderViews.chatMessage, 5),
            hasMore: false,
          ),
          onRetry: () => ref.read(messages.notifier).refetch(),
          builder: (page) {
            if (page.items.isEmpty) {
              return Center(child: AppText.body(context.l10n.sayHiToTeam));
            }

            final hasOlderRow =
                page.hasMore || page.loadingMore || page.loadMoreError != null;

            return ListView.builder(
              reverse: true,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: page.items.length + (hasOlderRow ? 1 : 0),
              itemBuilder: (context, index) {
                if (index < page.items.length) {
                  return ChatMessageBubble(message: page.items[index]);
                }
                final loadOlder = ref.read(messages.notifier).loadMore;
                return page.loadMoreError == null
                    ? _OlderMessagesLoader(onShown: loadOlder)
                    : AppButton.text(
                        context.l10n.retry,
                        onTap: dw.action((_) => loadOlder()),
                      );
              },
            );
          },
        );
  }
}

/// The row past the oldest loaded message. A list builds it only once it is
/// scrolled near, which is exactly when the page before is wanted — and
/// asking on every build keeps a short page loading until the screen is full.
/// `loadMore` sends one request at a time and none once there is no more.
class _OlderMessagesLoader extends StatelessWidget {
  const _OlderMessagesLoader({required this.onShown});

  final Future<void> Function() onShown;

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) onShown();
    });
    return const Padding(
      padding: EdgeInsets.all(8),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}
