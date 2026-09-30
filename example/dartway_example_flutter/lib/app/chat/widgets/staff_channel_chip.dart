import 'package:dartway_example_flutter/app/chat/logic/chat_counts.dart';
import 'package:dartway_example_flutter/ui_kit/ui_kit.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';
import 'package:flutter/widgets.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// A channel's chip with its unread badge. The badge is chrome: a plain count
/// from `logic/`, watched here, so its read neither holds nor rebuilds the
/// channel list around it. The open channel shows no badge.
class StaffChannelChip extends ConsumerWidget {
  const StaffChannelChip({
    required this.channel,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final ChatChannel channel;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ChatChannelChip(
    title: channel.title,
    selected: selected,
    unread: selected ? 0 : ref.watch(chatUnreadCountProvider(channel.id)),
    onTap: onTap,
  );
}
