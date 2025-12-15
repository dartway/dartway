import 'package:dartway_serverpod_chat_flutter/src/ui_kit/dw_chat_ui_kit.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class AddAttachmentButton extends ConsumerWidget {
  const AddAttachmentButton({super.key, required this.onPressed});

  final Function() onPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatTheme = DwChatTheme.of(context);

    return IconButton(
      icon: Icon(
        Icons.attach_file,
        color: chatTheme.mainTheme.primaryColor,
      ),
      onPressed: onPressed,
      // TODO: add logic to open media picker
      // ref.read(attachmentStateProvider.notifier).openMediaPicker(context);
      splashColor: chatTheme.mainTheme.secondaryColor.withValues(alpha: 0.2),
      tooltip: 'Прикрепить файл',
    );
  }
}
