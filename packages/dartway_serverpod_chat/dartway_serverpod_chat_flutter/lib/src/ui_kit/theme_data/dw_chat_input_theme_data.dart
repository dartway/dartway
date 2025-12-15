import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'dw_chat_input_theme_data.freezed.dart';

@freezed
class DwChatInputThemeData with _$DwChatInputThemeData {
  const factory DwChatInputThemeData({
    @Default(Colors.white) Color backgroundColor,
    @Default(Colors.blue) Color cursorColor,
    @Default(24.0) double borderRadius,
    @Default(EdgeInsets.symmetric(horizontal: 0, vertical: 12))
    EdgeInsets padding,
    InputBorder? border,
    TextStyle? textStyle,
    TextStyle? hintStyle,
  }) = _DwChatInputThemeData;
}
