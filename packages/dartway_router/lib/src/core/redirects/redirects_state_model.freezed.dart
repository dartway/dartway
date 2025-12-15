// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'redirects_state_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$RedirectsStateModel {
  Map<NavigationZoneRoute, NavigationZoneRoute> get redirects =>
      throw _privateConstructorUsedError;

  /// Create a copy of RedirectsStateModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $RedirectsStateModelCopyWith<RedirectsStateModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RedirectsStateModelCopyWith<$Res> {
  factory $RedirectsStateModelCopyWith(
          RedirectsStateModel value, $Res Function(RedirectsStateModel) then) =
      _$RedirectsStateModelCopyWithImpl<$Res, RedirectsStateModel>;
  @useResult
  $Res call({Map<NavigationZoneRoute, NavigationZoneRoute> redirects});
}

/// @nodoc
class _$RedirectsStateModelCopyWithImpl<$Res, $Val extends RedirectsStateModel>
    implements $RedirectsStateModelCopyWith<$Res> {
  _$RedirectsStateModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of RedirectsStateModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? redirects = null,
  }) {
    return _then(_value.copyWith(
      redirects: null == redirects
          ? _value.redirects
          : redirects // ignore: cast_nullable_to_non_nullable
              as Map<NavigationZoneRoute, NavigationZoneRoute>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$RedirectsStateModelImplCopyWith<$Res>
    implements $RedirectsStateModelCopyWith<$Res> {
  factory _$$RedirectsStateModelImplCopyWith(_$RedirectsStateModelImpl value,
          $Res Function(_$RedirectsStateModelImpl) then) =
      __$$RedirectsStateModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({Map<NavigationZoneRoute, NavigationZoneRoute> redirects});
}

/// @nodoc
class __$$RedirectsStateModelImplCopyWithImpl<$Res>
    extends _$RedirectsStateModelCopyWithImpl<$Res, _$RedirectsStateModelImpl>
    implements _$$RedirectsStateModelImplCopyWith<$Res> {
  __$$RedirectsStateModelImplCopyWithImpl(_$RedirectsStateModelImpl _value,
      $Res Function(_$RedirectsStateModelImpl) _then)
      : super(_value, _then);

  /// Create a copy of RedirectsStateModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? redirects = null,
  }) {
    return _then(_$RedirectsStateModelImpl(
      redirects: null == redirects
          ? _value._redirects
          : redirects // ignore: cast_nullable_to_non_nullable
              as Map<NavigationZoneRoute, NavigationZoneRoute>,
    ));
  }
}

/// @nodoc

class _$RedirectsStateModelImpl implements _RedirectsStateModel {
  const _$RedirectsStateModelImpl(
      {required final Map<NavigationZoneRoute, NavigationZoneRoute> redirects})
      : _redirects = redirects;

  final Map<NavigationZoneRoute, NavigationZoneRoute> _redirects;
  @override
  Map<NavigationZoneRoute, NavigationZoneRoute> get redirects {
    if (_redirects is EqualUnmodifiableMapView) return _redirects;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_redirects);
  }

  @override
  String toString() {
    return 'RedirectsStateModel(redirects: $redirects)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RedirectsStateModelImpl &&
            const DeepCollectionEquality()
                .equals(other._redirects, _redirects));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, const DeepCollectionEquality().hash(_redirects));

  /// Create a copy of RedirectsStateModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RedirectsStateModelImplCopyWith<_$RedirectsStateModelImpl> get copyWith =>
      __$$RedirectsStateModelImplCopyWithImpl<_$RedirectsStateModelImpl>(
          this, _$identity);
}

abstract class _RedirectsStateModel implements RedirectsStateModel {
  const factory _RedirectsStateModel(
      {required final Map<NavigationZoneRoute, NavigationZoneRoute>
          redirects}) = _$RedirectsStateModelImpl;

  @override
  Map<NavigationZoneRoute, NavigationZoneRoute> get redirects;

  /// Create a copy of RedirectsStateModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RedirectsStateModelImplCopyWith<_$RedirectsStateModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
