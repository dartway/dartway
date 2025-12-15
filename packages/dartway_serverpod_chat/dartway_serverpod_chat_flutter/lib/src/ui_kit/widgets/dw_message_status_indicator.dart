part of '../dw_chat_ui_kit.dart';

class DwMessageStatusIndicator extends StatelessWidget {
  const DwMessageStatusIndicator({
    super.key,
    required this.isReadStatus,
  });

  final bool isReadStatus;

  @override
  Widget build(BuildContext context) {
    final theme = DwChatTheme.of(context);

    Color color;
    if (isReadStatus) {
      color = theme.mainTheme.readStatusColor;
    } else {
      color = theme.mainTheme.sentStatusColor;
    }

    return Icon(
      Icons.done_all,
      size: 12,
      color: color,
    );
  }
}
