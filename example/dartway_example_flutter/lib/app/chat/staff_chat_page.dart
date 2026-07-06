import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:dartway_example_client/dartway_example_client.dart';
import 'package:dartway_example_flutter/app/chat/widgets/chat_message_composer.dart';
import 'package:dartway_example_flutter/app/chat/widgets/chat_message_list.dart';
import 'package:dartway_example_flutter/common/app_scaffold.dart';
import 'package:dartway_example_flutter/core/user_profile_provider.dart';
import 'package:dartway_example_flutter/core/user_profile_roles.dart';
import 'package:dartway_example_flutter/ui_kit/ui_kit.dart';

/// Staff-only chat. The UI hides the tab for clients, but the real protection
/// is the staff-only access filter in the server CRUD configs.
class StaffChatPage extends ConsumerWidget {
  const StaffChatPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watchUserProfile.isStaffMember) {
      return AppScaffold.main(
        body: Center(child: AppText.body('This area is for the club team')),
      );
    }

    return ref.watchModelList<ChatChannel>().dwBuildListAsync(
          loadingItemsCount: 1,
          childBuilder: (channels) {
            if (channels.isEmpty) {
              return AppScaffold.main(
                body: Center(child: AppText.body('No chat channels yet')),
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
