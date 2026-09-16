import 'package:dartway_example_flutter/app/chat/widgets/chat_channel_view.dart';
import 'package:dartway_example_flutter/core/app_l10n.dart';
import 'package:dartway_example_flutter/core/dw_core.dart';
import 'package:dartway_example_flutter/core/profile/my_profile.dart';
import 'package:dartway_example_flutter/core/profile/profile_roles.dart';
import 'package:dartway_example_flutter/shared/widgets/app_scaffold.dart';
import 'package:dartway_example_flutter/shared/widgets/load_failed_message.dart';
import 'package:dartway_example_flutter/ui_kit/ui_kit.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Staff-only chat. The UI hides the tab for clients; the real protection is
/// the server: the requests refuse a client, and so do the channels and the
/// file links.
class StaffChatPage extends HookConsumerWidget implements DwFeatureWidget {
  const StaffChatPage({super.key});

  @override
  DwFeatureSpec get dwFeature => const DwFeatureSpec(
    id: 'chat/staff-chat',
    title: 'Staff chat screen',
    purpose:
        'Coaches and admins have one place to sort out the club day between '
        'themselves.',
    behaviors: [
      'A client who reaches the route sees a staff-only notice, not the chat.',
      'The channels stand in a row over the chat, each with how many messages '
          'the member has not read; the counts move live.',
      'The search button turns the title into a search field over the open '
          'channel; closing it brings the composer back.',
      'The app bar shows the live connection status.',
      'With no channels at all the screen says so instead of failing.',
    ],
    requirements: [
      'Clients never receive staff messages. The hidden tab and the notice '
          'above are convenience; the server refuses the reads and the '
          'channel subscriptions to anyone but staff.',
    ],
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    if (!context.profile.isStaffMember) {
      return AppScaffold.main(
        body: Center(child: AppText.body(l10n.staffOnlyArea)),
      );
    }

    final channels = ref.watch(dw.request(const ListChatChannels()));
    final unread = {
      for (final state
          in ref.watch(dw.request(const ListMyChatReadStates())).value ??
              const <ChatReadState>[])
        state.id: state.unreadCount,
    };
    // A right click opens a message's menu; on the web the browser's own
    // menu would open over it.
    useEffect(() {
      if (!kIsWeb) return null;
      unawaited(BrowserContextMenu.disableContextMenu());
      return () => unawaited(BrowserContextMenu.enableContextMenu());
    }, const []);
    final selectedId = useState<int?>(null);
    final search = useState<String?>(null);
    final searchText = useTextEditingController();
    useEffect(() {
      void listen() {
        if (search.value != null) search.value = searchText.text;
      }

      searchText.addListener(listen);
      return () => searchText.removeListener(listen);
    }, [searchText]);

    final list = channels.value ?? const <ChatChannel>[];
    final channel =
        list.where((c) => c.id == selectedId.value).firstOrNull ??
        list.firstOrNull;

    return AppScaffold.main(
      appBar: AppBar(
        title: search.value != null
            ? ChatSearchField(
                controller: searchText,
                hintText: l10n.chatSearchHint,
              )
            : AppText.title(l10n.tabChat),
        actions: [
          IconButton(
            key: const ValueKey('chat-search-toggle'),
            tooltip: search.value == null
                ? l10n.chatSearch
                : l10n.chatCloseSearch,
            onPressed: channel == null
                ? null
                : () {
                    if (search.value == null) {
                      searchText.clear();
                      search.value = '';
                    } else {
                      search.value = null;
                    }
                  },
            icon: Icon(search.value == null ? Icons.search : Icons.close),
          ),
          const ConnectionStatusIndicator(),
        ],
      ),
      bodyInsets: EdgeInsets.zero,
      body: channels.section(
        loadingWidget: const Center(child: CircularProgressIndicator()),
        onRetry: () =>
            ref.read(dw.request(const ListChatChannels()).notifier).refetch(),
        builder: (channels) => channels.isEmpty || channel == null
            ? Center(child: AppText.body(l10n.noChatChannels))
            : Column(
                children: [
                  SizedBox(
                    height: 52,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      children: [
                        for (final item in channels)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChatChannelChip(
                              key: ValueKey('chat-channel-${item.id}'),
                              title: item.title,
                              selected: item.id == channel.id,
                              unread: item.id == channel.id
                                  ? 0
                                  : unread[item.id] ?? 0,
                              onTap: () {
                                search.value = null;
                                selectedId.value = item.id;
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ChatChannelView(
                      key: ValueKey(channel.id),
                      channel: channel,
                      searchQuery: search.value,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
