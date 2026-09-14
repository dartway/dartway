import 'package:dartway_example_flutter/core/app_l10n.dart';
import 'package:dartway_example_flutter/core/dw_core.dart';
import 'package:dartway_example_flutter/ui_kit/ui_kit.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';

class ChatMessageComposer extends HookWidget implements DwFeature {
  const ChatMessageComposer({
    required this.channel,
    required this.onSent,
    super.key,
  });

  final ChatChannel channel;

  /// The server accepted the message.
  final VoidCallback onSent;

  @override
  DwFeatureSpec get dwFeature => const DwFeatureSpec(
    id: 'chat/message-composer',
    title: 'Message composer',
    behaviors: [
      'Sending clears the input once the server has accepted the message.',
      'An empty or whitespace-only message is not sent.',
      'The send button is disabled while a message is on its way.',
      'After sending, the chat shows the newest messages.',
    ],
    implementationNotes: [
      'The sent message is not added here: it arrives in the answer to the '
          'command, and on the channel for everyone else.',
    ],
  );

  @override
  Widget build(BuildContext context) {
    final draftText = useState('');
    final text = draftText.value.trim();

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
        DwActionBuilder(
          action: text.isEmpty
              ? null
              : dw.action(
                  (_) => dw.command(
                    SendChatMessage(channelId: channel.id, text: text),
                  ),
                  followUpIfMountedAction: (_, _) {
                    draftText.value = '';
                    onSent();
                  },
                ),
          builder: (context, onPressed, busy) => IconButton.filled(
            tooltip: context.l10n.sendMessage,
            onPressed: onPressed,
            icon: const Icon(Icons.send),
          ),
        ),
      ],
    );
  }
}
