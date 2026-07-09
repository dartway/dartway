import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
import 'package:dartway_studio_bridge/dartway_studio_bridge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:dartway_example_client/dartway_example_client.dart';
import 'package:dartway_example_flutter/core/app_l10n.dart';
import 'package:dartway_example_flutter/core/user_profile_provider.dart';
import 'package:dartway_example_flutter/ui_kit/ui_kit.dart';

class ChatMessageComposer extends HookConsumerWidget implements DwFeature {
  const ChatMessageComposer({required this.channel, super.key});

  final ChatChannel channel;

  @override
  DwFeatureSpec get dwFeature => const DwFeatureSpec(
        id: 'chat-message-composer',
        title: 'Message composer',
        description:
            'Sending is a single DwRepository.saveModel(ChatMessage) — the '
            'list above updates in realtime, no extra wiring.',
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draftText = useState('');

    Future<void> sendMessage() async {
      final text = draftText.value.trim();
      if (text.isEmpty) return;

      await DwRepository.saveModel(
        ChatMessage(
          channelId: channel.id!,
          authorProfileId: ref.readUserProfile.id!,
          messageText: text,
          createdAt: DateTime.now(),
        ),
      );
      draftText.value = '';
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: AppTextFormField(
            value: draftText.value,
            onChanged: (value) => draftText.value = value,
            hintText: context.l10n.messageTheTeam,
            maxLines: 3,
            minLines: 1,
          ),
        ),
        const Gap(8),
        IconButton.filled(
          onPressed: draftText.value.trim().isEmpty ? null : sendMessage,
          icon: const Icon(Icons.send),
        ),
      ],
    );
  }
}
