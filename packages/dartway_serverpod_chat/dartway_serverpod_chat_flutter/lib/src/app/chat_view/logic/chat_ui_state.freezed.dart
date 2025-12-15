// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'chat_ui_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$ChatUIStateModel {
  bool get showScrollToBottom => throw _privateConstructorUsedError;
  int get unreadCount => throw _privateConstructorUsedError;
  bool get isAtBottom => throw _privateConstructorUsedError;

  /// Create a copy of ChatUIStateModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ChatUIStateModelCopyWith<ChatUIStateModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ChatUIStateModelCopyWith<$Res> {
  factory $ChatUIStateModelCopyWith(
          ChatUIStateModel value, $Res Function(ChatUIStateModel) then) =
      _$ChatUIStateModelCopyWithImpl<$Res, ChatUIStateModel>;
  @useResult
  $Res call({bool showScrollToBottom, int unreadCount, bool isAtBottom});
}

/// @nodoc
class _$ChatUIStateModelCopyWithImpl<$Res, $Val extends ChatUIStateModel>
    implements $ChatUIStateModelCopyWith<$Res> {
  _$ChatUIStateModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ChatUIStateModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? showScrollToBottom = null,
    Object? unreadCount = null,
    Object? isAtBottom = null,
  }) {
    return _then(_value.copyWith(
      showScrollToBottom: null == showScrollToBottom
          ? _value.showScrollToBottom
          : showScrollToBottom // ignore: cast_nullable_to_non_nullable
              as bool,
      unreadCount: null == unreadCount
          ? _value.unreadCount
          : unreadCount // ignore: cast_nullable_to_non_nullable
              as int,
      isAtBottom: null == isAtBottom
          ? _value.isAtBottom
          : isAtBottom // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ChatUIStateModelImplCopyWith<$Res>
    implements $ChatUIStateModelCopyWith<$Res> {
  factory _$$ChatUIStateModelImplCopyWith(_$ChatUIStateModelImpl value,
          $Res Function(_$ChatUIStateModelImpl) then) =
      __$$ChatUIStateModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({bool showScrollToBottom, int unreadCount, bool isAtBottom});
}

/// @nodoc
class __$$ChatUIStateModelImplCopyWithImpl<$Res>
    extends _$ChatUIStateModelCopyWithImpl<$Res, _$ChatUIStateModelImpl>
    implements _$$ChatUIStateModelImplCopyWith<$Res> {
  __$$ChatUIStateModelImplCopyWithImpl(_$ChatUIStateModelImpl _value,
      $Res Function(_$ChatUIStateModelImpl) _then)
      : super(_value, _then);

  /// Create a copy of ChatUIStateModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? showScrollToBottom = null,
    Object? unreadCount = null,
    Object? isAtBottom = null,
  }) {
    return _then(_$ChatUIStateModelImpl(
      showScrollToBottom: null == showScrollToBottom
          ? _value.showScrollToBottom
          : showScrollToBottom // ignore: cast_nullable_to_non_nullable
              as bool,
      unreadCount: null == unreadCount
          ? _value.unreadCount
          : unreadCount // ignore: cast_nullable_to_non_nullable
              as int,
      isAtBottom: null == isAtBottom
          ? _value.isAtBottom
          : isAtBottom // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc

class _$ChatUIStateModelImpl implements _ChatUIStateModel {
  const _$ChatUIStateModelImpl(
      {this.showScrollToBottom = false,
      this.unreadCount = 0,
      this.isAtBottom = true});

  @override
  @JsonKey()
  final bool showScrollToBottom;
  @override
  @JsonKey()
  final int unreadCount;
  @override
  @JsonKey()
  final bool isAtBottom;

  @override
  String toString() {
    return 'ChatUIStateModel(showScrollToBottom: $showScrollToBottom, unreadCount: $unreadCount, isAtBottom: $isAtBottom)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ChatUIStateModelImpl &&
            (identical(other.showScrollToBottom, showScrollToBottom) ||
                other.showScrollToBottom == showScrollToBottom) &&
            (identical(other.unreadCount, unreadCount) ||
                other.unreadCount == unreadCount) &&
            (identical(other.isAtBottom, isAtBottom) ||
                other.isAtBottom == isAtBottom));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, showScrollToBottom, unreadCount, isAtBottom);

  /// Create a copy of ChatUIStateModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ChatUIStateModelImplCopyWith<_$ChatUIStateModelImpl> get copyWith =>
      __$$ChatUIStateModelImplCopyWithImpl<_$ChatUIStateModelImpl>(
          this, _$identity);
}

abstract class _ChatUIStateModel implements ChatUIStateModel {
  const factory _ChatUIStateModel(
      {final bool showScrollToBottom,
      final int unreadCount,
      final bool isAtBottom}) = _$ChatUIStateModelImpl;

  @override
  bool get showScrollToBottom;
  @override
  int get unreadCount;
  @override
  bool get isAtBottom;

  /// Create a copy of ChatUIStateModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ChatUIStateModelImplCopyWith<_$ChatUIStateModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
