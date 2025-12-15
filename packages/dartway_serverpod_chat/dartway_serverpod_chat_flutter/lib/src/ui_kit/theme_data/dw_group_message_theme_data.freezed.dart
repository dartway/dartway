// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'dw_group_message_theme_data.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$DwGroupMessageThemeData {
  Future<String?> Function(int) get getSenderName =>
      throw _privateConstructorUsedError;
  TextStyle get senderNameTextStyle => throw _privateConstructorUsedError;

  /// Create a copy of DwGroupMessageThemeData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DwGroupMessageThemeDataCopyWith<DwGroupMessageThemeData> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DwGroupMessageThemeDataCopyWith<$Res> {
  factory $DwGroupMessageThemeDataCopyWith(DwGroupMessageThemeData value,
          $Res Function(DwGroupMessageThemeData) then) =
      _$DwGroupMessageThemeDataCopyWithImpl<$Res, DwGroupMessageThemeData>;
  @useResult
  $Res call(
      {Future<String?> Function(int) getSenderName,
      TextStyle senderNameTextStyle});
}

/// @nodoc
class _$DwGroupMessageThemeDataCopyWithImpl<$Res,
        $Val extends DwGroupMessageThemeData>
    implements $DwGroupMessageThemeDataCopyWith<$Res> {
  _$DwGroupMessageThemeDataCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of DwGroupMessageThemeData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? getSenderName = null,
    Object? senderNameTextStyle = null,
  }) {
    return _then(_value.copyWith(
      getSenderName: null == getSenderName
          ? _value.getSenderName
          : getSenderName // ignore: cast_nullable_to_non_nullable
              as Future<String?> Function(int),
      senderNameTextStyle: null == senderNameTextStyle
          ? _value.senderNameTextStyle
          : senderNameTextStyle // ignore: cast_nullable_to_non_nullable
              as TextStyle,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$GroupMessageThemeImplCopyWith<$Res>
    implements $DwGroupMessageThemeDataCopyWith<$Res> {
  factory _$$GroupMessageThemeImplCopyWith(_$GroupMessageThemeImpl value,
          $Res Function(_$GroupMessageThemeImpl) then) =
      __$$GroupMessageThemeImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {Future<String?> Function(int) getSenderName,
      TextStyle senderNameTextStyle});
}

/// @nodoc
class __$$GroupMessageThemeImplCopyWithImpl<$Res>
    extends _$DwGroupMessageThemeDataCopyWithImpl<$Res, _$GroupMessageThemeImpl>
    implements _$$GroupMessageThemeImplCopyWith<$Res> {
  __$$GroupMessageThemeImplCopyWithImpl(_$GroupMessageThemeImpl _value,
      $Res Function(_$GroupMessageThemeImpl) _then)
      : super(_value, _then);

  /// Create a copy of DwGroupMessageThemeData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? getSenderName = null,
    Object? senderNameTextStyle = null,
  }) {
    return _then(_$GroupMessageThemeImpl(
      getSenderName: null == getSenderName
          ? _value.getSenderName
          : getSenderName // ignore: cast_nullable_to_non_nullable
              as Future<String?> Function(int),
      senderNameTextStyle: null == senderNameTextStyle
          ? _value.senderNameTextStyle
          : senderNameTextStyle // ignore: cast_nullable_to_non_nullable
              as TextStyle,
    ));
  }
}

/// @nodoc

class _$GroupMessageThemeImpl implements _GroupMessageTheme {
  const _$GroupMessageThemeImpl(
      {required this.getSenderName,
      this.senderNameTextStyle = const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 15,
          color: Color(0xFF222222))});

  @override
  final Future<String?> Function(int) getSenderName;
  @override
  @JsonKey()
  final TextStyle senderNameTextStyle;

  @override
  String toString() {
    return 'DwGroupMessageThemeData(getSenderName: $getSenderName, senderNameTextStyle: $senderNameTextStyle)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$GroupMessageThemeImpl &&
            (identical(other.getSenderName, getSenderName) ||
                other.getSenderName == getSenderName) &&
            (identical(other.senderNameTextStyle, senderNameTextStyle) ||
                other.senderNameTextStyle == senderNameTextStyle));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, getSenderName, senderNameTextStyle);

  /// Create a copy of DwGroupMessageThemeData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$GroupMessageThemeImplCopyWith<_$GroupMessageThemeImpl> get copyWith =>
      __$$GroupMessageThemeImplCopyWithImpl<_$GroupMessageThemeImpl>(
          this, _$identity);
}

abstract class _GroupMessageTheme implements DwGroupMessageThemeData {
  const factory _GroupMessageTheme(
      {required final Future<String?> Function(int) getSenderName,
      final TextStyle senderNameTextStyle}) = _$GroupMessageThemeImpl;

  @override
  Future<String?> Function(int) get getSenderName;
  @override
  TextStyle get senderNameTextStyle;

  /// Create a copy of DwGroupMessageThemeData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$GroupMessageThemeImplCopyWith<_$GroupMessageThemeImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
