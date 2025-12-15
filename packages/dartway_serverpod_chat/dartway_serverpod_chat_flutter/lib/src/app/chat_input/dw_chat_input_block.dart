import 'package:dartway_serverpod_chat_flutter/dartway_serverpod_chat_flutter.dart';
import 'package:flutter/widgets.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class DwChatInputBlock extends ConsumerWidget {
  const DwChatInputBlock({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // TODO: implement build
    return Column(
      children: [
        DwEditMessagePanel(
          editedMessageText: '',
          closeAction: () {},
        ),
        DwReplyPanel(
          replyToMessageText: '',
          closeAction: () {},
        ),
        ChatInputWidget(chatId: chatId),
      ],
    );
  }
}
