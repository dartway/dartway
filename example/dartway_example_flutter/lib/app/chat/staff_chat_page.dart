import 'package:dartway_example_flutter/app/chat/widgets/chat_message_composer.dart';
import 'package:dartway_example_flutter/app/chat/widgets/chat_message_list.dart';
import 'package:dartway_example_flutter/core/app_l10n.dart';
import 'package:dartway_example_flutter/core/dw_core.dart';
import 'package:dartway_example_flutter/core/profile/my_profile.dart';
import 'package:dartway_example_flutter/core/profile/profile_roles.dart';
import 'package:dartway_example_flutter/shared/widgets/app_scaffold.dart';
import 'package:dartway_example_flutter/shared/widgets/load_failed_message.dart';
import 'package:dartway_example_flutter/ui_kit/ui_kit.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Staff-only chat. The UI hides the tab for clients; the real protection is
/// the server: the requests refuse a client, and so does the channel.
class StaffChatPage extends ConsumerWidget implements DwFeature {
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
      'The first channel opens automatically — there is no channel picker yet.',
      'The app bar shows the live connection status.',
      'With no channels at all the screen says so instead of failing.',
    ],
    requirements: [
      'Clients never receive staff messages. The hidden tab and the notice '
          'above are convenience; the server refuses the reads and the '
          'channel subscription to anyone but staff.',
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
    final channel = channels.value?.firstOrNull;

    return AppScaffold.main(
      appBar: AppBar(
        title: AppText.title(channel?.title ?? l10n.tabChat),
        actions: const [ConnectionStatusIndicator()],
      ),
      bodyInsets: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      body: channels.section(
        // A skeleton of the chat would be a message list, and that list reads
        // the messages of a channel — there is none to read yet.
        loadingWidget: const Center(child: CircularProgressIndicator()),
        onRetry: () =>
            ref.read(dw.request(const ListChatChannels()).notifier).refetch(),
        builder: (channels) {
          if (channels.isEmpty) {
            return Center(child: AppText.body(l10n.noChatChannels));
          }
          return Column(
            children: [
              Expanded(child: ChatMessageList(channel: channels.first)),
              ChatMessageComposer(channel: channels.first),
            ],
          );
        },
      ),
    );
  }
}
