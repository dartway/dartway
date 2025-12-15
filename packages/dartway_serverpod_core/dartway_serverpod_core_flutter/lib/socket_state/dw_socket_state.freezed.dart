// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'dw_socket_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$DwSocketStateModel {
  StreamingConnectionStatus get websocketStatus =>
      throw _privateConstructorUsedError;

  /// Create a copy of DwSocketStateModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DwSocketStateModelCopyWith<DwSocketStateModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DwSocketStateModelCopyWith<$Res> {
  factory $DwSocketStateModelCopyWith(
    DwSocketStateModel value,
    $Res Function(DwSocketStateModel) then,
  ) = _$DwSocketStateModelCopyWithImpl<$Res, DwSocketStateModel>;
  @useResult
  $Res call({StreamingConnectionStatus websocketStatus});
}

/// @nodoc
class _$DwSocketStateModelCopyWithImpl<$Res, $Val extends DwSocketStateModel>
    implements $DwSocketStateModelCopyWith<$Res> {
  _$DwSocketStateModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of DwSocketStateModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? websocketStatus = null}) {
    return _then(
      _value.copyWith(
            websocketStatus:
                null == websocketStatus
                    ? _value.websocketStatus
                    : websocketStatus // ignore: cast_nullable_to_non_nullable
                        as StreamingConnectionStatus,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$DwSocketStateModelImplCopyWith<$Res>
    implements $DwSocketStateModelCopyWith<$Res> {
  factory _$$DwSocketStateModelImplCopyWith(
    _$DwSocketStateModelImpl value,
    $Res Function(_$DwSocketStateModelImpl) then,
  ) = __$$DwSocketStateModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({StreamingConnectionStatus websocketStatus});
}

/// @nodoc
class __$$DwSocketStateModelImplCopyWithImpl<$Res>
    extends _$DwSocketStateModelCopyWithImpl<$Res, _$DwSocketStateModelImpl>
    implements _$$DwSocketStateModelImplCopyWith<$Res> {
  __$$DwSocketStateModelImplCopyWithImpl(
    _$DwSocketStateModelImpl _value,
    $Res Function(_$DwSocketStateModelImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of DwSocketStateModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? websocketStatus = null}) {
    return _then(
      _$DwSocketStateModelImpl(
        websocketStatus:
            null == websocketStatus
                ? _value.websocketStatus
                : websocketStatus // ignore: cast_nullable_to_non_nullable
                    as StreamingConnectionStatus,
      ),
    );
  }
}

/// @nodoc

class _$DwSocketStateModelImpl implements _DwSocketStateModel {
  const _$DwSocketStateModelImpl({required this.websocketStatus});

  @override
  final StreamingConnectionStatus websocketStatus;

  @override
  String toString() {
    return 'DwSocketStateModel(websocketStatus: $websocketStatus)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DwSocketStateModelImpl &&
            (identical(other.websocketStatus, websocketStatus) ||
                other.websocketStatus == websocketStatus));
  }

  @override
  int get hashCode => Object.hash(runtimeType, websocketStatus);

  /// Create a copy of DwSocketStateModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DwSocketStateModelImplCopyWith<_$DwSocketStateModelImpl> get copyWith =>
      __$$DwSocketStateModelImplCopyWithImpl<_$DwSocketStateModelImpl>(
        this,
        _$identity,
      );
}

abstract class _DwSocketStateModel implements DwSocketStateModel {
  const factory _DwSocketStateModel({
    required final StreamingConnectionStatus websocketStatus,
  }) = _$DwSocketStateModelImpl;

  @override
  StreamingConnectionStatus get websocketStatus;

  /// Create a copy of DwSocketStateModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DwSocketStateModelImplCopyWith<_$DwSocketStateModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
