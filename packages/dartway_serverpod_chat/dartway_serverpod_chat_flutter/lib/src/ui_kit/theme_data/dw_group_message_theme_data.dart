import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'dw_group_message_theme_data.freezed.dart';

@freezed
class DwGroupMessageThemeData with _$DwGroupMessageThemeData {
  const factory DwGroupMessageThemeData({
    required Future<String?> Function(int userId) getSenderName,
    @Default(TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: 15,
      color: Color(0xFF222222),
    ))
    TextStyle senderNameTextStyle,
  }) = _GroupMessageTheme;
}
