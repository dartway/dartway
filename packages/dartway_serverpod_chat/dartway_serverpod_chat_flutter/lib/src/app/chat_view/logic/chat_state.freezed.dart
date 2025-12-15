// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'chat_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$DwChatStateModel {
  DwChatViewState get viewState => throw _privateConstructorUsedError;
  List<DwChatMessage> get messages => throw _privateConstructorUsedError;
  int? get lastReadMessageId => throw _privateConstructorUsedError;
  bool get isTyping => throw _privateConstructorUsedError;
  ScrollController get scrollController => throw _privateConstructorUsedError;
  ListObserverController get observerController =>
      throw _privateConstructorUsedError;
  ChatScrollObserver get chatObserver => throw _privateConstructorUsedError;
  DwChatMessage? get repliedMessage => throw _privateConstructorUsedError;
  DwChatMessage? get editedMessage => throw _privateConstructorUsedError;

  /// Create a copy of DwChatStateModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DwChatStateModelCopyWith<DwChatStateModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DwChatStateModelCopyWith<$Res> {
  factory $DwChatStateModelCopyWith(
          DwChatStateModel value, $Res Function(DwChatStateModel) then) =
      _$DwChatStateModelCopyWithImpl<$Res, DwChatStateModel>;
  @useResult
  $Res call(
      {DwChatViewState viewState,
      List<DwChatMessage> messages,
      int? lastReadMessageId,
      bool isTyping,
      ScrollController scrollController,
      ListObserverController observerController,
      ChatScrollObserver chatObserver,
      DwChatMessage? repliedMessage,
      DwChatMessage? editedMessage});
}

/// @nodoc
class _$DwChatStateModelCopyWithImpl<$Res, $Val extends DwChatStateModel>
    implements $DwChatStateModelCopyWith<$Res> {
  _$DwChatStateModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of DwChatStateModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? viewState = null,
    Object? messages = null,
    Object? lastReadMessageId = freezed,
    Object? isTyping = null,
    Object? scrollController = null,
    Object? observerController = null,
    Object? chatObserver = null,
    Object? repliedMessage = freezed,
    Object? editedMessage = freezed,
  }) {
    return _then(_value.copyWith(
      viewState: null == viewState
          ? _value.viewState
          : viewState // ignore: cast_nullable_to_non_nullable
              as DwChatViewState,
      messages: null == messages
          ? _value.messages
          : messages // ignore: cast_nullable_to_non_nullable
              as List<DwChatMessage>,
      lastReadMessageId: freezed == lastReadMessageId
          ? _value.lastReadMessageId
          : lastReadMessageId // ignore: cast_nullable_to_non_nullable
              as int?,
      isTyping: null == isTyping
          ? _value.isTyping
          : isTyping // ignore: cast_nullable_to_non_nullable
              as bool,
      scrollController: null == scrollController
          ? _value.scrollController
          : scrollController // ignore: cast_nullable_to_non_nullable
              as ScrollController,
      observerController: null == observerController
          ? _value.observerController
          : observerController // ignore: cast_nullable_to_non_nullable
              as ListObserverController,
      chatObserver: null == chatObserver
          ? _value.chatObserver
          : chatObserver // ignore: cast_nullable_to_non_nullable
              as ChatScrollObserver,
      repliedMessage: freezed == repliedMessage
          ? _value.repliedMessage
          : repliedMessage // ignore: cast_nullable_to_non_nullable
              as DwChatMessage?,
      editedMessage: freezed == editedMessage
          ? _value.editedMessage
          : editedMessage // ignore: cast_nullable_to_non_nullable
              as DwChatMessage?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$DwChatStateModelImplCopyWith<$Res>
    implements $DwChatStateModelCopyWith<$Res> {
  factory _$$DwChatStateModelImplCopyWith(_$DwChatStateModelImpl value,
          $Res Function(_$DwChatStateModelImpl) then) =
      __$$DwChatStateModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {DwChatViewState viewState,
      List<DwChatMessage> messages,
      int? lastReadMessageId,
      bool isTyping,
      ScrollController scrollController,
      ListObserverController observerController,
      ChatScrollObserver chatObserver,
      DwChatMessage? repliedMessage,
      DwChatMessage? editedMessage});
}

/// @nodoc
class __$$DwChatStateModelImplCopyWithImpl<$Res>
    extends _$DwChatStateModelCopyWithImpl<$Res, _$DwChatStateModelImpl>
    implements _$$DwChatStateModelImplCopyWith<$Res> {
  __$$DwChatStateModelImplCopyWithImpl(_$DwChatStateModelImpl _value,
      $Res Function(_$DwChatStateModelImpl) _then)
      : super(_value, _then);

  /// Create a copy of DwChatStateModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? viewState = null,
    Object? messages = null,
    Object? lastReadMessageId = freezed,
    Object? isTyping = null,
    Object? scrollController = null,
    Object? observerController = null,
    Object? chatObserver = null,
    Object? repliedMessage = freezed,
    Object? editedMessage = freezed,
  }) {
    return _then(_$DwChatStateModelImpl(
      viewState: null == viewState
          ? _value.viewState
          : viewState // ignore: cast_nullable_to_non_nullable
              as DwChatViewState,
      messages: null == messages
          ? _value._messages
          : messages // ignore: cast_nullable_to_non_nullable
              as List<DwChatMessage>,
      lastReadMessageId: freezed == lastReadMessageId
          ? _value.lastReadMessageId
          : lastReadMessageId // ignore: cast_nullable_to_non_nullable
              as int?,
      isTyping: null == isTyping
          ? _value.isTyping
          : isTyping // ignore: cast_nullable_to_non_nullable
              as bool,
      scrollController: null == scrollController
          ? _value.scrollController
          : scrollController // ignore: cast_nullable_to_non_nullable
              as ScrollController,
      observerController: null == observerController
          ? _value.observerController
          : observerController // ignore: cast_nullable_to_non_nullable
              as ListObserverController,
      chatObserver: null == chatObserver
          ? _value.chatObserver
          : chatObserver // ignore: cast_nullable_to_non_nullable
              as ChatScrollObserver,
      repliedMessage: freezed == repliedMessage
          ? _value.repliedMessage
          : repliedMessage // ignore: cast_nullable_to_non_nullable
              as DwChatMessage?,
      editedMessage: freezed == editedMessage
          ? _value.editedMessage
          : editedMessage // ignore: cast_nullable_to_non_nullable
              as DwChatMessage?,
    ));
  }
}

/// @nodoc

class _$DwChatStateModelImpl implements _DwChatStateModel {
  const _$DwChatStateModelImpl(
      {required this.viewState,
      final List<DwChatMessage> messages = const [],
      this.lastReadMessageId,
      this.isTyping = false,
      required this.scrollController,
      required this.observerController,
      required this.chatObserver,
      this.repliedMessage,
      this.editedMessage})
      : _messages = messages;

  @override
  final DwChatViewState viewState;
  final List<DwChatMessage> _messages;
  @override
  @JsonKey()
  List<DwChatMessage> get messages {
    if (_messages is EqualUnmodifiableListView) return _messages;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_messages);
  }

  @override
  final int? lastReadMessageId;
  @override
  @JsonKey()
  final bool isTyping;
  @override
  final ScrollController scrollController;
  @override
  final ListObserverController observerController;
  @override
  final ChatScrollObserver chatObserver;
  @override
  final DwChatMessage? repliedMessage;
  @override
  final DwChatMessage? editedMessage;

  @override
  String toString() {
    return 'DwChatStateModel(viewState: $viewState, messages: $messages, lastReadMessageId: $lastReadMessageId, isTyping: $isTyping, scrollController: $scrollController, observerController: $observerController, chatObserver: $chatObserver, repliedMessage: $repliedMessage, editedMessage: $editedMessage)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DwChatStateModelImpl &&
            (identical(other.viewState, viewState) ||
                other.viewState == viewState) &&
            const DeepCollectionEquality().equals(other._messages, _messages) &&
            (identical(other.lastReadMessageId, lastReadMessageId) ||
                other.lastReadMessageId == lastReadMessageId) &&
            (identical(other.isTyping, isTyping) ||
                other.isTyping == isTyping) &&
            (identical(other.scrollController, scrollController) ||
                other.scrollController == scrollController) &&
            (identical(other.observerController, observerController) ||
                other.observerController == observerController) &&
            (identical(other.chatObserver, chatObserver) ||
                other.chatObserver == chatObserver) &&
            (identical(other.repliedMessage, repliedMessage) ||
                other.repliedMessage == repliedMessage) &&
            (identical(other.editedMessage, editedMessage) ||
                other.editedMessage == editedMessage));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      viewState,
      const DeepCollectionEquality().hash(_messages),
      lastReadMessageId,
      isTyping,
      scrollController,
      observerController,
      chatObserver,
      repliedMessage,
      editedMessage);

  /// Create a copy of DwChatStateModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DwChatStateModelImplCopyWith<_$DwChatStateModelImpl> get copyWith =>
      __$$DwChatStateModelImplCopyWithImpl<_$DwChatStateModelImpl>(
          this, _$identity);
}

abstract class _DwChatStateModel implements DwChatStateModel {
  const factory _DwChatStateModel(
      {required final DwChatViewState viewState,
      final List<DwChatMessage> messages,
      final int? lastReadMessageId,
      final bool isTyping,
      required final ScrollController scrollController,
      required final ListObserverController observerController,
      required final ChatScrollObserver chatObserver,
      final DwChatMessage? repliedMessage,
      final DwChatMessage? editedMessage}) = _$DwChatStateModelImpl;

  @override
  DwChatViewState get viewState;
  @override
  List<DwChatMessage> get messages;
  @override
  int? get lastReadMessageId;
  @override
  bool get isTyping;
  @override
  ScrollController get scrollController;
  @override
  ListObserverController get observerController;
  @override
  ChatScrollObserver get chatObserver;
  @override
  DwChatMessage? get repliedMessage;
  @override
  DwChatMessage? get editedMessage;

  /// Create a copy of DwChatStateModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DwChatStateModelImplCopyWith<_$DwChatStateModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
