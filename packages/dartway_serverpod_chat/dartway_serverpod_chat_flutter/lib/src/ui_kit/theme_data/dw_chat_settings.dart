import 'package:freezed_annotation/freezed_annotation.dart';

part 'dw_chat_settings.freezed.dart';

enum ChatBubbleType { personal, group }

@freezed
class DwChatSettings with _$DwChatSettings {
  const factory DwChatSettings({
    @Default(ChatBubbleType.personal) ChatBubbleType chatBubbleType,
    @Default(true) bool showScrollToBottomButton,
    @Default(false) bool enableVoiceMessages,
    @Default(false) bool enableMessageOverlay,
  }) = _DwChatSettings;
}
