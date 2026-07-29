import 'package:dartway_example_flutter/core/dw_core.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:dartway_example_client/dartway_example_client.dart';
import 'package:dartway_example_flutter/app/chat/widgets/chat_message_composer.dart';
import 'package:dartway_example_flutter/app/chat/widgets/chat_message_list.dart';
import 'package:dartway_example_flutter/common/app_scaffold.dart';
import 'package:dartway_example_flutter/core/app_l10n.dart';
import 'package:dartway_example_flutter/core/user_profile_provider.dart';
import 'package:dartway_example_flutter/core/user_profile_roles.dart';
import 'package:dartway_example_flutter/ui_kit/ui_kit.dart';

/// Staff-only chat. The UI hides the tab for clients, but the real protection
/// is the staff-only access filter in the server CRUD configs.
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
          'above are convenience; the staff-only access filter on the server '
          'is the enforcement.',
    ],
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watchUserProfile.isStaffMember) {
      return AppScaffold.main(
        body: Center(child: AppText.body(context.l10n.staffOnlyArea)),
      );
    }

    return ref
        .watch(dw.repo.modelList<ChatChannel>())
        .dwBuildListAsync(
          loadingItemsCount: 1,
          childBuilder: (channels) {
            if (channels.isEmpty) {
              return AppScaffold.main(
                body: Center(child: AppText.body(context.l10n.noChatChannels)),
              );
            }

            final channel = channels.first;
            return AppScaffold.main(
              appBar: AppBar(
                title: AppText.title(channel.title),
                actions: const [ConnectionStatusIndicator()],
              ),
              bodyInsets: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              body: Column(
                children: [
                  Expanded(child: ChatMessageList(channel: channel)),
                  ChatMessageComposer(channel: channel),
                ],
              ),
            );
          },
        );
  }
}
