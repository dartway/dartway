import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'dw_chat_general_theme_data.freezed.dart';

@freezed
class DwChatGeneralThemeData with _$DwChatGeneralThemeData {
  const factory DwChatGeneralThemeData({
    @Default(Color(0xFFF5F5F5)) Color backgroundColor,
    @Default(Colors.blue) Color primaryColor,
    @Default(Colors.grey) Color secondaryColor,
    @Default(Colors.red) Color errorColor,
    @Default(Color(0xFFE0E0E0)) Color dividerColor,
    @Default(Colors.grey) Color timeTextColor,
    @Default(Colors.grey) Color sentStatusColor,
    @Default(Colors.grey) Color deliveredStatusColor,
    @Default(Colors.blue) Color readStatusColor,
    @Default(Colors.blue) Color typingIndicatorColor,
    @Default(TextStyle(fontSize: 10.0, color: Colors.grey))
    TextStyle timeTextStyle,
    @Default(12.0) double typingIndicatorSize,
  }) = _DwChatGeneralThemeData;
}
