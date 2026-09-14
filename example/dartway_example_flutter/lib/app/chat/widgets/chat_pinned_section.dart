import 'dart:async';

import 'package:dartway_example_flutter/app/chat/logic/chat_session.dart';
import 'package:dartway_example_flutter/core/app_l10n.dart';
import 'package:dartway_example_flutter/core/dw_core.dart';
import 'package:dartway_example_flutter/ui_kit/ui_kit.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// The pinned messages of the channel over its list, newest first: a tap
/// scrolls to the one shown — reopening the history around it when it is
/// far back — and turns the bar to the next. Live: a pin anywhere joins it.
class ChatPinnedSection extends HookConsumerWidget implements DwFeature {
  const ChatPinnedSection({required this.session, super.key});

  final ChatSession session;

  @override
  DwFeatureSpec get dwFeature => const DwFeatureSpec(
    id: 'chat/pinned-bar',
    title: 'Pinned messages',
    behaviors: [
      'Shows the newest pinned message first; the strip on the left tells '
          'which of them is shown.',
      'A tap scrolls the chat to the message shown and turns the bar to the '
          'next one, round and round.',
      'The cross unpins the message shown, for the whole team.',
      'A message pinned or unpinned by anyone appears or leaves at once.',
    ],
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final pinned =
        ref
            .watch(
              dw.request(ListPinnedChatMessages(channelId: session.channel.id)),
            )
            .value ??
        const <ChatMessage>[];
    final index = useState(0);
    // A pin or an unpin: back to the newest, which is what changed.
    useEffect(() {
      index.value = 0;
      return null;
    }, [pinned.length]);
    if (pinned.isEmpty) return const SizedBox.shrink();
    final shown = index.value % pinned.length;
    final message = pinned[shown];
    return ChatPinnedBar(
      label: pinned.length > 1
          ? '${l10n.chatPinnedMessage} · ${l10n.chatPinnedPosition(shown + 1, pinned.length)}'
          : l10n.chatPinnedMessage,
      text: message.text.isEmpty ? l10n.chatPhoto : message.text,
      index: shown,
      count: pinned.length,
      unpinTooltip: l10n.chatUnpin,
      onTap: () {
        index.value = (shown + 1) % pinned.length;
        unawaited(session.showMessage(message.id, message.sentAt));
      },
      onUnpin: () =>
          dw.command(PinChatMessage(messageId: message.id, pinned: false)),
    );
  }
}
