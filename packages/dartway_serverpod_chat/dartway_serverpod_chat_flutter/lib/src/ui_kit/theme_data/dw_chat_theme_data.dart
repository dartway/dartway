import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'dw_chat_bubble_theme_data.dart';
import 'dw_chat_general_theme_data.dart';
import 'dw_chat_input_theme_data.dart';
import 'dw_chat_settings.dart';
import 'dw_group_message_theme_data.dart';

part 'dw_chat_theme_data.freezed.dart';

// Функция по умолчанию для получения имени отправителя

Future<String?> _defaultGetSenderName(int id) => Future.value('User $id');

@freezed
class DwChatThemeData with _$DwChatThemeData {
  const factory DwChatThemeData({
    @Default(DwChatSettings()) DwChatSettings settings,
    @Default(DwChatGeneralThemeData()) DwChatGeneralThemeData mainTheme,
    @Default(DwChatBubbleThemeData(
      backgroundColor: Colors.white,
      textColor: Colors.black87,
      borderRadius: 12.0,
    ))
    DwChatBubbleThemeData incomingBubble,
    @Default(DwChatBubbleThemeData(
      backgroundColor: Colors.blue,
      textColor: Colors.white,
      borderRadius: 12.0,
    ))
    DwChatBubbleThemeData outgoingBubble,
    @Default(DwChatInputThemeData()) DwChatInputThemeData inputTheme,
    @Default(DwGroupMessageThemeData(
      getSenderName: _defaultGetSenderName,
    ))
    DwGroupMessageThemeData groupMessageTheme,
  }) = _DwChatThemeData;
}
