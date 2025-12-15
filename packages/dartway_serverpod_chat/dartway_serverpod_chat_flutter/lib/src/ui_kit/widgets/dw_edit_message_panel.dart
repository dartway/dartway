part of '../dw_chat_ui_kit.dart';

class DwEditMessagePanel extends StatelessWidget {
  const DwEditMessagePanel({
    super.key,
    required this.editedMessageText,
    required this.closeAction,
  });

  final String? editedMessageText;
  final Function() closeAction;

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme = DwChatTheme.of(context);

    final isVisible = editedMessageText != null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      height: isVisible ? 70.0 : 0.0,
      decoration: BoxDecoration(
        color: theme.mainTheme.backgroundColor,
        border: isVisible
            ? Border(
                top: BorderSide(
                  color: theme.mainTheme.dividerColor,
                  width: 1.0,
                ),
              )
            : Border.all(width: 0, color: Colors.transparent),
      ),
      child: isVisible
          ? Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  Icon(
                    Icons.reply,
                    color: Colors.black,
                    size: 20.0,
                  ),
                  const SizedBox(width: 8.0),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Редактирование сообщения',
                          style: theme.inputTheme.textStyle,
                        ),
                        const SizedBox(height: 4.0),
                        Text(
                          editedMessageText!,
                          //?? 'Медиафайл',
                          style: theme.inputTheme.textStyle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: Colors.black,
                      size: 20.0,
                    ),
                    onPressed: closeAction,
                    // TODO: add logic to reset edited message
                    //  () {
                    //   ref
                    //       .read(chatStateProvider(chatId).notifier)
                    //       .setEditedMessage(null);
                    // },
                  ),
                ],
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}
