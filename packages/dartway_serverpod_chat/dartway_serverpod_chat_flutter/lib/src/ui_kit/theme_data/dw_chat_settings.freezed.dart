// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'dw_chat_settings.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$DwChatSettings {
  ChatBubbleType get chatBubbleType => throw _privateConstructorUsedError;
  bool get showScrollToBottomButton => throw _privateConstructorUsedError;
  bool get enableVoiceMessages => throw _privateConstructorUsedError;
  bool get enableMessageOverlay => throw _privateConstructorUsedError;

  /// Create a copy of DwChatSettings
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DwChatSettingsCopyWith<DwChatSettings> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DwChatSettingsCopyWith<$Res> {
  factory $DwChatSettingsCopyWith(
          DwChatSettings value, $Res Function(DwChatSettings) then) =
      _$DwChatSettingsCopyWithImpl<$Res, DwChatSettings>;
  @useResult
  $Res call(
      {ChatBubbleType chatBubbleType,
      bool showScrollToBottomButton,
      bool enableVoiceMessages,
      bool enableMessageOverlay});
}

/// @nodoc
class _$DwChatSettingsCopyWithImpl<$Res, $Val extends DwChatSettings>
    implements $DwChatSettingsCopyWith<$Res> {
  _$DwChatSettingsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of DwChatSettings
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? chatBubbleType = null,
    Object? showScrollToBottomButton = null,
    Object? enableVoiceMessages = null,
    Object? enableMessageOverlay = null,
  }) {
    return _then(_value.copyWith(
      chatBubbleType: null == chatBubbleType
          ? _value.chatBubbleType
          : chatBubbleType // ignore: cast_nullable_to_non_nullable
              as ChatBubbleType,
      showScrollToBottomButton: null == showScrollToBottomButton
          ? _value.showScrollToBottomButton
          : showScrollToBottomButton // ignore: cast_nullable_to_non_nullable
              as bool,
      enableVoiceMessages: null == enableVoiceMessages
          ? _value.enableVoiceMessages
          : enableVoiceMessages // ignore: cast_nullable_to_non_nullable
              as bool,
      enableMessageOverlay: null == enableMessageOverlay
          ? _value.enableMessageOverlay
          : enableMessageOverlay // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$DwChatSettingsImplCopyWith<$Res>
    implements $DwChatSettingsCopyWith<$Res> {
  factory _$$DwChatSettingsImplCopyWith(_$DwChatSettingsImpl value,
          $Res Function(_$DwChatSettingsImpl) then) =
      __$$DwChatSettingsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {ChatBubbleType chatBubbleType,
      bool showScrollToBottomButton,
      bool enableVoiceMessages,
      bool enableMessageOverlay});
}

/// @nodoc
class __$$DwChatSettingsImplCopyWithImpl<$Res>
    extends _$DwChatSettingsCopyWithImpl<$Res, _$DwChatSettingsImpl>
    implements _$$DwChatSettingsImplCopyWith<$Res> {
  __$$DwChatSettingsImplCopyWithImpl(
      _$DwChatSettingsImpl _value, $Res Function(_$DwChatSettingsImpl) _then)
      : super(_value, _then);

  /// Create a copy of DwChatSettings
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? chatBubbleType = null,
    Object? showScrollToBottomButton = null,
    Object? enableVoiceMessages = null,
    Object? enableMessageOverlay = null,
  }) {
    return _then(_$DwChatSettingsImpl(
      chatBubbleType: null == chatBubbleType
          ? _value.chatBubbleType
          : chatBubbleType // ignore: cast_nullable_to_non_nullable
              as ChatBubbleType,
      showScrollToBottomButton: null == showScrollToBottomButton
          ? _value.showScrollToBottomButton
          : showScrollToBottomButton // ignore: cast_nullable_to_non_nullable
              as bool,
      enableVoiceMessages: null == enableVoiceMessages
          ? _value.enableVoiceMessages
          : enableVoiceMessages // ignore: cast_nullable_to_non_nullable
              as bool,
      enableMessageOverlay: null == enableMessageOverlay
          ? _value.enableMessageOverlay
          : enableMessageOverlay // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc

class _$DwChatSettingsImpl implements _DwChatSettings {
  const _$DwChatSettingsImpl(
      {this.chatBubbleType = ChatBubbleType.personal,
      this.showScrollToBottomButton = true,
      this.enableVoiceMessages = false,
      this.enableMessageOverlay = false});

  @override
  @JsonKey()
  final ChatBubbleType chatBubbleType;
  @override
  @JsonKey()
  final bool showScrollToBottomButton;
  @override
  @JsonKey()
  final bool enableVoiceMessages;
  @override
  @JsonKey()
  final bool enableMessageOverlay;

  @override
  String toString() {
    return 'DwChatSettings(chatBubbleType: $chatBubbleType, showScrollToBottomButton: $showScrollToBottomButton, enableVoiceMessages: $enableVoiceMessages, enableMessageOverlay: $enableMessageOverlay)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DwChatSettingsImpl &&
            (identical(other.chatBubbleType, chatBubbleType) ||
                other.chatBubbleType == chatBubbleType) &&
            (identical(
                    other.showScrollToBottomButton, showScrollToBottomButton) ||
                other.showScrollToBottomButton == showScrollToBottomButton) &&
            (identical(other.enableVoiceMessages, enableVoiceMessages) ||
                other.enableVoiceMessages == enableVoiceMessages) &&
            (identical(other.enableMessageOverlay, enableMessageOverlay) ||
                other.enableMessageOverlay == enableMessageOverlay));
  }

  @override
  int get hashCode => Object.hash(runtimeType, chatBubbleType,
      showScrollToBottomButton, enableVoiceMessages, enableMessageOverlay);

  /// Create a copy of DwChatSettings
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DwChatSettingsImplCopyWith<_$DwChatSettingsImpl> get copyWith =>
      __$$DwChatSettingsImplCopyWithImpl<_$DwChatSettingsImpl>(
          this, _$identity);
}

abstract class _DwChatSettings implements DwChatSettings {
  const factory _DwChatSettings(
      {final ChatBubbleType chatBubbleType,
      final bool showScrollToBottomButton,
      final bool enableVoiceMessages,
      final bool enableMessageOverlay}) = _$DwChatSettingsImpl;

  @override
  ChatBubbleType get chatBubbleType;
  @override
  bool get showScrollToBottomButton;
  @override
  bool get enableVoiceMessages;
  @override
  bool get enableMessageOverlay;

  /// Create a copy of DwChatSettings
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DwChatSettingsImplCopyWith<_$DwChatSettingsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
