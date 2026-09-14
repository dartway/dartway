import 'dart:async';

import 'package:dartway_example_flutter/app/chat/logic/chat_labels.dart';
import 'package:dartway_example_flutter/app/chat/logic/chat_session.dart';
import 'package:dartway_example_flutter/app/chat/widgets/chat_composer.dart';
import 'package:dartway_example_flutter/app/chat/widgets/chat_message_row.dart';
import 'package:dartway_example_flutter/app/chat/widgets/chat_pinned_section.dart';
import 'package:dartway_example_flutter/core/app_l10n.dart';
import 'package:dartway_example_flutter/core/dw_core.dart';
import 'package:dartway_example_flutter/shared/widgets/load_failed_message.dart';
import 'package:dartway_example_flutter/ui_kit/ui_kit.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// One channel of the staff chat: its history, the pinned bar, the floating
/// date, the "↓" button, and the composer — or, while searching, the way
/// through the matches.
class ChatChannelView extends HookConsumerWidget implements DwFeature {
  const ChatChannelView({
    required this.channel,
    required this.searchQuery,
    super.key,
  });

  final ChatChannel channel;

  /// `null` while not searching.
  final String? searchQuery;

  @override
  DwFeatureSpec get dwFeature => const DwFeatureSpec(
    id: 'chat/channel',
    title: 'Staff chat channel',
    purpose:
        'Coaches and admins keep one running conversation per topic, and pick '
        'it up where they left it.',
    behaviors: [
      'Opens where the member stopped reading, the first unread message '
          'under an "Unread messages" divider; a read channel opens at its '
          'newest message.',
      'The list is not reversed: newest at the bottom, older messages load '
          'above as it is scrolled up and newer ones below, and neither moves '
          'what is on screen.',
      'At the bottom, new messages come into view; scrolled up, nothing '
          'moves and the "↓" button counts them. The button goes to the '
          'newest message, loading it when it is far away.',
      'What comes on screen is marked read on the server, only forward, a '
          'moment after the list stops.',
      'While scrolling, the date of the topmost message floats over the list '
          'and fades out soon after it stops.',
      'Each day starts with its date; one author\'s messages in a row form a '
          'run with their name on the first and their avatar on the last.',
    ],
    requirements: [
      'Clients never receive staff messages or their files — the server '
          'refuses them the reads, the channels and the file links.',
    ],
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final readStates = ref.watch(dw.request(const ListMyChatReadStates()));
    return readStates.section(
      // Not a skeleton: the list opens at the read position, so it waits for
      // it rather than opening elsewhere and moving.
      loadingWidget: const Center(child: CircularProgressIndicator()),
      onRetry: () =>
          ref.read(dw.request(const ListMyChatReadStates()).notifier).refetch(),
      builder: (states) => _ChannelBody(
        channel: channel,
        // Read once: the list opens here, and a later position is where the
        // member has scrolled to since, not where to go.
        readState: states.where((s) => s.id == channel.id).firstOrNull,
        searchQuery: searchQuery,
      ),
    );
  }
}

class _ChannelBody extends HookConsumerWidget {
  const _ChannelBody({
    required this.channel,
    required this.readState,
    required this.searchQuery,
  });

  final ChatChannel channel;
  final ChatReadState? readState;
  final String? searchQuery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final session = useMemoized(
      () => ChatSession(channel: channel, readState: readState),
    );
    final tracker = useMemoized(
      () => ChatReadTracker(
        channelId: channel.id,
        request: session.request,
        readPosition: switch (readState?.lastReadCursor) {
          final cursor? => DwWindowCursor.decode(cursor).position,
          null => null,
        },
      ),
    );
    useEffect(
      () => () {
        tracker.dispose();
        session.dispose();
      },
      const [],
    );
    final hasPinned =
        ref
            .watch(dw.request(ListPinnedChatMessages(channelId: channel.id)))
            .value
            ?.isNotEmpty ??
        false;
    final query = searchQuery?.trim();
    final searching = query != null;

    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: DwWindowListView<ChatMessage>(
                  key: const ValueKey('chat-message-list'),
                  request: session.request,
                  controller: session.list,
                  initialAnchor: session.openAnchor,
                  anchorAlignment: 0.3,
                  padding: EdgeInsets.fromLTRB(
                    10,
                    hasPinned ? ChatPinnedBar.height + 8 : 8,
                    10,
                    12,
                  ),
                  onVisibleItemsChanged: tracker.seen,
                  emptyBuilder: (context) =>
                      Center(child: AppText.body(l10n.sayHiToTeam)),
                  itemBuilder: (context, row) => ChatMessageRow(
                    row: row,
                    session: session,
                    searchQuery: searching && query.length >= 2 ? query : null,
                  ),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: ChatPinnedSection(session: session),
              ),
              Positioned(
                top: (hasPinned ? ChatPinnedBar.height : 0) + 8,
                left: 0,
                right: 0,
                child: _FloatingDate(session: session),
              ),
              if (!searching)
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: _JumpToNewest(session: session),
                ),
            ],
          ),
        ),
        if (searching)
          _SearchControls(session: session, query: query)
        else
          ChatComposer(session: session),
      ],
    );
  }
}

/// The "↓" with a count: what the list knows arrived below, or — when the
/// window has not loaded that far — what the server counts unread.
class _JumpToNewest extends HookConsumerWidget {
  const _JumpToNewest({required this.session});

  final ChatSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final atNewest = useValueListenable(session.list.isAtNewest);
    final below = useValueListenable(session.list.newerCount);
    final unread =
        ref
            .watch(dw.request(const ListMyChatReadStates()))
            .value
            ?.where((state) => state.id == session.channel.id)
            .firstOrNull
            ?.unreadCount ??
        0;
    return ChatJumpButton(
      visible: !atNewest,
      count: below > unread ? below : unread,
      tooltip: context.l10n.chatJumpToNewest,
      onTap: () => unawaited(session.list.jumpToNewest()),
    );
  }
}

/// The day of the topmost message while the list moves, gone a moment after
/// it stops — and never at the newest message, where the day is plain.
class _FloatingDate extends HookWidget {
  const _FloatingDate({required this.session});

  final ChatSession session;

  @override
  Widget build(BuildContext context) {
    final scrolling = useValueListenable(session.list.isScrolling);
    final top = useValueListenable(session.list.topVisibleItem);
    final atNewest = useValueListenable(session.list.isAtNewest);
    final lingering = useState(false);
    useEffect(() {
      if (scrolling) {
        lingering.value = true;
        return null;
      }
      final timer = Timer(const Duration(milliseconds: 1500), () {
        lingering.value = false;
      });
      return timer.cancel;
    }, [scrolling]);
    return ChatFloatingDate(
      label: top?.sentAt.chatDayLabel(context.l10n),
      visible: (scrolling || lingering.value) && !atNewest,
    );
  }
}

/// While searching: how many messages match, which one is shown, and the way
/// to the next older and newer one. The first result is shown as soon as the
/// matches arrive.
class _SearchControls extends HookConsumerWidget {
  const _SearchControls({required this.session, required this.query});

  final ChatSession session;
  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final debounced = useState(query);
    useEffect(() {
      final timer = Timer(
        const Duration(milliseconds: 300),
        () => debounced.value = query,
      );
      return timer.cancel;
    }, [query]);
    final active = debounced.value.length >= SearchChatMessages.minQueryLength;
    final results = active
        ? ref.watch(
            dw.request(
              SearchChatMessages(
                channelId: session.channel.id,
                query: debounced.value,
              ),
            ),
          )
        : null;
    final matches = results?.value ?? const <ChatMessage>[];
    final index = useState(0);
    useEffect(() {
      index.value = 0;
      if (matches.isNotEmpty) {
        unawaited(session.list.scrollToItem(matches.first));
      }
      return null;
    }, [matches]);

    void go(int to) {
      index.value = to;
      unawaited(session.list.scrollToItem(matches[to]));
    }

    final label = !active
        ? l10n.chatSearchHint
        : results?.isLoading ?? false
        ? '…'
        : matches.isEmpty
        ? l10n.chatSearchNothing
        : l10n.chatSearchPosition(index.value + 1, matches.length);
    return ChatBottomBar(
      child: ChatSearchControls(
        label: label,
        olderTooltip: l10n.chatSearchOlder,
        newerTooltip: l10n.chatSearchNewer,
        // Results are newest first: older is further down the list.
        onOlder: index.value + 1 < matches.length
            ? () => go(index.value + 1)
            : null,
        onNewer: index.value > 0 ? () => go(index.value - 1) : null,
      ),
    );
  }
}
