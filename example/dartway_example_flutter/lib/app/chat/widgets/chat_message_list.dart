import 'package:dartway_example_flutter/app/chat/widgets/chat_message_bubble.dart';
import 'package:dartway_example_flutter/core/app_l10n.dart';
import 'package:dartway_example_flutter/core/dw_core.dart';
import 'package:dartway_example_flutter/shared/placeholder_objects.dart';
import 'package:dartway_example_flutter/shared/widgets/load_failed_message.dart';
import 'package:dartway_example_flutter/ui_kit/ui_kit.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// A window over the messages of one channel, newest at the bottom: older
/// messages load as the list is scrolled up to them, newer ones — when the
/// window was opened above the newest — on request. New messages arrive
/// through the channel: no polling, no socket code.
class ChatMessageList extends HookConsumerWidget implements DwFeature {
  const ChatMessageList({
    required this.channel,
    required this.anchor,
    required this.onJumpToNewest,
    required this.onLeave,
    super.key,
  });

  final ChatChannel channel;

  /// The cursor the window opens around; `null` for the newest messages.
  final String? anchor;

  /// Reopens the window at the newest messages.
  final VoidCallback onJumpToNewest;

  /// Called when the list goes, with the cursor of the newest message it had
  /// loaded.
  final void Function(String cursor) onLeave;

  @override
  DwFeatureSpec get dwFeature => const DwFeatureSpec(
    id: 'chat/message-list',
    title: 'Realtime staff chat',
    purpose:
        'Coaches and admins keep one running conversation about the club day.',
    behaviors: [
      'Messages appear for every staff member without a refresh.',
      'Each message shows its author and time.',
      'Scrolling up to the oldest loaded message loads the ones before it; a '
          'load that fails offers a retry in its place.',
      'The chat reopens where it stood when it was left; later messages wait '
          'below behind a "show newer" button.',
      'A message that arrives while the newest ones are not shown is counted '
          'on a "new messages" chip, which jumps to the newest.',
    ],
    requirements: [
      'Clients never receive staff messages — the server refuses them the '
          'read and the channel, whatever the UI shows.',
    ],
    implementationNotes: [
      'A window request ordered by (sent at, id): loads in either direction '
          'go by cursors, so a message arriving meanwhile neither shifts nor '
          'repeats them.',
    ],
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final request = ListChatMessages(channelId: channel.id);
    final provider = dw.window(request, anchor: anchor);
    final window = ref.watch(provider);

    // Where the window stands, told once the list goes.
    final newestCursor = useRef<String?>(null);
    if (window.value?.items.firstOrNull case final newest?) {
      newestCursor.value = request.cursorOf(newest);
    }
    useEffect(
      () => () {
        if (newestCursor.value case final cursor?) onLeave(cursor);
      },
      const [],
    );

    return window.section(
      loadingValue: DwWindowData(
        PlaceholderObjects.listOf(PlaceholderObjects.chatMessage, 5),
        hasOlder: false,
        hasNewer: false,
      ),
      onRetry: () => ref.read(provider.notifier).refetch(),
      builder: (data) {
        if (data.items.isEmpty) {
          return Center(child: AppText.body(l10n.sayHiToTeam));
        }
        final messages = ref.read(provider.notifier);

        // Split where the window was opened: the anchor and everything older
        // rise from the bottom edge, what is newer lies below it. Rows loaded
        // at either end then grow away from what is on screen, and nothing
        // the member is reading moves.
        final opening = switch (anchor) {
          final cursor? => DwWindowCursor.decode(cursor).position,
          null => null,
        };
        final newerCount = opening == null
            ? 0
            : data.items.indexWhere(
                (item) =>
                    DwWindowCursor.comparePositions(
                      request.positionOf(item),
                      opening,
                    ) <=
                    0,
              );
        final newer = newerCount < 0
            ? data.items
            : data.items.sublist(0, newerCount);
        final rest = newerCount < 0
            ? const <ChatMessage>[]
            : data.items.sublist(newerCount);

        return Stack(
          children: [
            CustomScrollView(
              reverse: true,
              center: _anchorSliver,
              slivers: [
                // Below the bottom edge, nearest to the anchor first.
                SliverList.list(
                  children: [
                    for (final message in newer.reversed)
                      ChatMessageBubble(message: message),
                    if (data.hasNewer)
                      Center(
                        child: data.loadingNewer
                            ? const _RowSpinner()
                            : AppButton.text(
                                l10n.showNewerMessages,
                                onTap: dw.action((_) => messages.loadNewer()),
                              ),
                      ),
                    // Room under the last row, so the chip below never
                    // covers it.
                    if (data.hasNewer) const SizedBox(height: 56),
                  ],
                ),
                SliverPadding(
                  key: _anchorSliver,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  sliver: SliverList.builder(
                    itemCount: rest.length + (data.hasOlder ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index < rest.length) {
                        return ChatMessageBubble(message: rest[index]);
                      }
                      return data.loadError == null
                          ? _OlderMessagesLoader(onShown: messages.loadOlder)
                          : Center(
                              child: AppButton.text(
                                l10n.retry,
                                onTap: dw.action((_) => messages.loadOlder()),
                              ),
                            );
                    },
                  ),
                ),
              ],
            ),
            if (data.hasNewer || data.unseenNewerCount > 0)
              Positioned(
                bottom: 8,
                left: 0,
                right: 0,
                child: Center(
                  child: ActionChip(
                    avatar: const Icon(Icons.arrow_downward, size: 16),
                    label: Text(
                      data.unseenNewerCount > 0
                          ? l10n.newMessagesCount(data.unseenNewerCount)
                          : l10n.newerMessages,
                    ),
                    onPressed: onJumpToNewest,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  static const _anchorSliver = ValueKey('chat-anchor');
}

/// The row past the oldest loaded message. A list builds it only once it is
/// scrolled near, which is exactly when older messages are wanted — and
/// asking on every build keeps a short window loading until the screen is
/// full. `loadOlder` sends one request at a time and none once there is no
/// more.
class _OlderMessagesLoader extends StatelessWidget {
  const _OlderMessagesLoader({required this.onShown});

  final Future<void> Function() onShown;

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) onShown();
    });
    return const _RowSpinner();
  }
}

class _RowSpinner extends StatelessWidget {
  const _RowSpinner();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(8),
    child: Center(child: CircularProgressIndicator()),
  );
}
