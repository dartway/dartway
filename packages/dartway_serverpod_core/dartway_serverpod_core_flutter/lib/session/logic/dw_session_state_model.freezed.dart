// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'dw_session_state_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$DwSessionStateModel<UserProfileClass extends SerializableModel> {
  UserProfileClass? get signedInUserProfile =>
      throw _privateConstructorUsedError;
  int? get signedInUserId => throw _privateConstructorUsedError;

  /// Create a copy of DwSessionStateModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DwSessionStateModelCopyWith<
    UserProfileClass,
    DwSessionStateModel<UserProfileClass>
  >
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DwSessionStateModelCopyWith<
  UserProfileClass extends SerializableModel,
  $Res
> {
  factory $DwSessionStateModelCopyWith(
    DwSessionStateModel<UserProfileClass> value,
    $Res Function(DwSessionStateModel<UserProfileClass>) then,
  ) =
      _$DwSessionStateModelCopyWithImpl<
        UserProfileClass,
        $Res,
        DwSessionStateModel<UserProfileClass>
      >;
  @useResult
  $Res call({UserProfileClass? signedInUserProfile, int? signedInUserId});
}

/// @nodoc
class _$DwSessionStateModelCopyWithImpl<
  UserProfileClass extends SerializableModel,
  $Res,
  $Val extends DwSessionStateModel<UserProfileClass>
>
    implements $DwSessionStateModelCopyWith<UserProfileClass, $Res> {
  _$DwSessionStateModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of DwSessionStateModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? signedInUserProfile = freezed,
    Object? signedInUserId = freezed,
  }) {
    return _then(
      _value.copyWith(
            signedInUserProfile:
                freezed == signedInUserProfile
                    ? _value.signedInUserProfile
                    : signedInUserProfile // ignore: cast_nullable_to_non_nullable
                        as UserProfileClass?,
            signedInUserId:
                freezed == signedInUserId
                    ? _value.signedInUserId
                    : signedInUserId // ignore: cast_nullable_to_non_nullable
                        as int?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$DwSessionStateModelImplCopyWith<
  UserProfileClass extends SerializableModel,
  $Res
>
    implements $DwSessionStateModelCopyWith<UserProfileClass, $Res> {
  factory _$$DwSessionStateModelImplCopyWith(
    _$DwSessionStateModelImpl<UserProfileClass> value,
    $Res Function(_$DwSessionStateModelImpl<UserProfileClass>) then,
  ) = __$$DwSessionStateModelImplCopyWithImpl<UserProfileClass, $Res>;
  @override
  @useResult
  $Res call({UserProfileClass? signedInUserProfile, int? signedInUserId});
}

/// @nodoc
class __$$DwSessionStateModelImplCopyWithImpl<
  UserProfileClass extends SerializableModel,
  $Res
>
    extends
        _$DwSessionStateModelCopyWithImpl<
          UserProfileClass,
          $Res,
          _$DwSessionStateModelImpl<UserProfileClass>
        >
    implements _$$DwSessionStateModelImplCopyWith<UserProfileClass, $Res> {
  __$$DwSessionStateModelImplCopyWithImpl(
    _$DwSessionStateModelImpl<UserProfileClass> _value,
    $Res Function(_$DwSessionStateModelImpl<UserProfileClass>) _then,
  ) : super(_value, _then);

  /// Create a copy of DwSessionStateModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? signedInUserProfile = freezed,
    Object? signedInUserId = freezed,
  }) {
    return _then(
      _$DwSessionStateModelImpl<UserProfileClass>(
        signedInUserProfile:
            freezed == signedInUserProfile
                ? _value.signedInUserProfile
                : signedInUserProfile // ignore: cast_nullable_to_non_nullable
                    as UserProfileClass?,
        signedInUserId:
            freezed == signedInUserId
                ? _value.signedInUserId
                : signedInUserId // ignore: cast_nullable_to_non_nullable
                    as int?,
      ),
    );
  }
}

/// @nodoc

class _$DwSessionStateModelImpl<UserProfileClass extends SerializableModel>
    implements _DwSessionStateModel<UserProfileClass> {
  const _$DwSessionStateModelImpl({
    this.signedInUserProfile,
    this.signedInUserId,
  });

  @override
  final UserProfileClass? signedInUserProfile;
  @override
  final int? signedInUserId;

  @override
  String toString() {
    return 'DwSessionStateModel<$UserProfileClass>(signedInUserProfile: $signedInUserProfile, signedInUserId: $signedInUserId)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DwSessionStateModelImpl<UserProfileClass> &&
            const DeepCollectionEquality().equals(
              other.signedInUserProfile,
              signedInUserProfile,
            ) &&
            (identical(other.signedInUserId, signedInUserId) ||
                other.signedInUserId == signedInUserId));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    const DeepCollectionEquality().hash(signedInUserProfile),
    signedInUserId,
  );

  /// Create a copy of DwSessionStateModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DwSessionStateModelImplCopyWith<
    UserProfileClass,
    _$DwSessionStateModelImpl<UserProfileClass>
  >
  get copyWith => __$$DwSessionStateModelImplCopyWithImpl<
    UserProfileClass,
    _$DwSessionStateModelImpl<UserProfileClass>
  >(this, _$identity);
}

abstract class _DwSessionStateModel<UserProfileClass extends SerializableModel>
    implements DwSessionStateModel<UserProfileClass> {
  const factory _DwSessionStateModel({
    final UserProfileClass? signedInUserProfile,
    final int? signedInUserId,
  }) = _$DwSessionStateModelImpl<UserProfileClass>;

  @override
  UserProfileClass? get signedInUserProfile;
  @override
  int? get signedInUserId;

  /// Create a copy of DwSessionStateModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DwSessionStateModelImplCopyWith<
    UserProfileClass,
    _$DwSessionStateModelImpl<UserProfileClass>
  >
  get copyWith => throw _privateConstructorUsedError;
}
