import 'package:dartway_serverpod_chat_client/dartway_serverpod_chat_client.dart';
import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../ui_kit/dw_chat_ui_kit.dart';
import '../logic/chat_state.dart';

class DwMessageStatusWidget extends ConsumerWidget {
  final DwChatMessage message;

  const DwMessageStatusWidget({super.key, required this.message});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserId = ref.watchSignedInUserId;
    if (message.userId != currentUserId) return const SizedBox.shrink();

    final lastReadMessageId = ref.watch(
      dwChatStateProvider(message.chatChannelId)
          .select((state) => state.lastReadMessageId),
    );

    final isReadStatus =
        lastReadMessageId != null && lastReadMessageId >= message.id!;

    return DwMessageStatusIndicator(isReadStatus: isReadStatus);
  }
}
