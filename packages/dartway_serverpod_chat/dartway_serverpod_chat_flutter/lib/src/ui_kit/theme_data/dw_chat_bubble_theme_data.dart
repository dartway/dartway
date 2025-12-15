import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'dw_chat_bubble_theme_data.freezed.dart';

@freezed
class DwChatBubbleThemeData with _$DwChatBubbleThemeData {
  const factory DwChatBubbleThemeData({
    required Color backgroundColor,
    required Color textColor,
    @Default(12.0) double borderRadius,
    @Default(EdgeInsets.symmetric(horizontal: 16, vertical: 10))
    EdgeInsets padding,
    @Default(EdgeInsets.symmetric(vertical: 4, horizontal: 8))
    EdgeInsets margin,
    BoxBorder? border,
    List<BoxShadow>? boxShadow,
    @Default(TextStyle(
      color: Colors.black87,
      fontSize: 16,
      height: 1.3,
    ))
    TextStyle? incomingTextStyle,
    @Default(TextStyle(
      color: Colors.white,
      fontSize: 16,
      height: 1.3,
    ))
    TextStyle? outgoingTextStyle,
  }) = _DwChatBubbleThemeData;
}
