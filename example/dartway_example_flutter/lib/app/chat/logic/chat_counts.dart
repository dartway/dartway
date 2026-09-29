import 'package:dartway_example_flutter/core/dw_core.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Whether the member has a channel at all: searching needs one. `false`
/// until the channels are known.
final chatHasChannelsProvider = Provider.autoDispose<bool>(
  (ref) => ref.watch(
    dw
        .request(const ListChatChannels())
        .select((channels) => channels.value?.isNotEmpty ?? false),
  ),
);

/// Whether a channel has pinned messages: the message list leaves room at its
/// top for the pinned bar. `false` until the pins are known.
///
/// Derived here, in `logic/`, rather than taken apart in a widget: a widget
/// shows a read through `DwReadBuilder`, and this is a number the layout needs
/// whatever the read answers.
final chatHasPinnedProvider = Provider.autoDispose.family<bool, int>(
  (ref, channelId) =>
      ref
          .watch(dw.request(ListPinnedChatMessages(channelId: channelId)))
          .value
          ?.isNotEmpty ??
      false,
);

/// Unread messages of a channel as the server counts them; `0` until known.
final chatUnreadCountProvider = Provider.autoDispose.family<int, int>(
  (ref, channelId) =>
      ref
          .watch(dw.request(const ListMyChatReadStates()))
          .value
          ?.where((state) => state.id == channelId)
          .firstOrNull
          ?.unreadCount ??
      0,
);
