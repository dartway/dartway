part of '../dw_chat_ui_kit.dart';

class DwReplyIndicator extends StatelessWidget {
  final String? repliedMessageText;
  final VoidCallback onTap;

  const DwReplyIndicator({
    super.key,
    required this.repliedMessageText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = DwChatTheme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14.0),
          splashColor: theme.mainTheme.primaryColor.withValues(alpha: 0.08),
          highlightColor: theme.mainTheme.primaryColor.withValues(
            alpha: 0.04,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(14.0),
              border: Border(
                left: BorderSide(
                  color: theme.mainTheme.primaryColor,
                  width: 5.0,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 14.0,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 12.0,
            ),
            child: Row(
              children: [
                Icon(Icons.reply, size: 20.0, color: Colors.black),
                const SizedBox(width: 12.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Text(
                      //   'Ответ на сообщение',
                      //   style: TextStyle(
                      //     color: theme.mainTheme.primaryColor,
                      //     fontSize: 13.5,
                      //     fontWeight: FontWeight.w700,
                      //     letterSpacing: 0.1,
                      //   ),
                      // ),
                      // const SizedBox(height: 4.0),
                      Text(
                        repliedMessageText?.trim().isNotEmpty == true
                            ? repliedMessageText!
                            : 'Медиафайл',
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 13.0,
                          fontWeight: FontWeight.w400,
                          overflow: TextOverflow.ellipsis,
                        ),
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8.0),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16.0,
                  color: Colors.black.withValues(alpha: 0.8),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
