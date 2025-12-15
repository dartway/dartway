part of '../dw_chat_ui_kit.dart';

class DwReplyPanel extends StatelessWidget {
  const DwReplyPanel({
    super.key,
    required this.replyToMessageText,
    required this.closeAction,
  });

  final String? replyToMessageText;
  final Function() closeAction;

  @override
  Widget build(BuildContext context) {
    final theme = DwChatTheme.of(context);
    final isVisible = replyToMessageText != null;

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
                          'Ответ на сообщение',
                          style: theme.inputTheme.textStyle,
                        ),
                        const SizedBox(height: 4.0),
                        Text(
                          replyToMessageText!,
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
                    // TODO: add logic to reset replied message
                    //  () {
                    //   ref
                    //       .read(chatStateProvider(chatId).notifier)
                    //       .setRepliedMessage(null);
                    // },
                  ),
                ],
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}
