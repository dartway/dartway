part of '../dw_chat_ui_kit.dart';

class DwMessageTime extends StatelessWidget {
  const DwMessageTime({super.key, required this.messageSentAt});

  final DateTime messageSentAt;

  @override
  Widget build(BuildContext context) {
    final theme = DwChatTheme.of(context);
    return Text(
      '${messageSentAt.toLocal().hour}:${messageSentAt.toLocal().minute.toString().padLeft(2, '0')}',
      style: theme.mainTheme.timeTextStyle,
    );
  }
}
