part of '../dw_chat_ui_kit.dart';

class DwChatTheme extends InheritedWidget {
  final DwChatThemeData data;

  const DwChatTheme({
    super.key,
    required this.data,
    required super.child,
  });

  static DwChatThemeData of(BuildContext context) {
    final DwChatTheme? result =
        context.dependOnInheritedWidgetOfExactType<DwChatTheme>();
    return result?.data ?? const DwChatThemeData();
  }

  @override
  bool updateShouldNotify(DwChatTheme oldWidget) => data != oldWidget.data;
}
