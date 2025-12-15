// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'auth_state_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$AuthStateModel {
  AuthStep get currentStep =>
      throw _privateConstructorUsedError; // Input fields
  String get firstName => throw _privateConstructorUsedError;
  String get phoneRaw => throw _privateConstructorUsedError;
  String get otpRaw => throw _privateConstructorUsedError; // Agreements
  bool get allDocumentsAccepted => throw _privateConstructorUsedError;
  bool get marketingAgreed => throw _privateConstructorUsedError;

  /// Create a copy of AuthStateModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AuthStateModelCopyWith<AuthStateModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AuthStateModelCopyWith<$Res> {
  factory $AuthStateModelCopyWith(
          AuthStateModel value, $Res Function(AuthStateModel) then) =
      _$AuthStateModelCopyWithImpl<$Res, AuthStateModel>;
  @useResult
  $Res call(
      {AuthStep currentStep,
      String firstName,
      String phoneRaw,
      String otpRaw,
      bool allDocumentsAccepted,
      bool marketingAgreed});
}

/// @nodoc
class _$AuthStateModelCopyWithImpl<$Res, $Val extends AuthStateModel>
    implements $AuthStateModelCopyWith<$Res> {
  _$AuthStateModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AuthStateModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? currentStep = null,
    Object? firstName = null,
    Object? phoneRaw = null,
    Object? otpRaw = null,
    Object? allDocumentsAccepted = null,
    Object? marketingAgreed = null,
  }) {
    return _then(_value.copyWith(
      currentStep: null == currentStep
          ? _value.currentStep
          : currentStep // ignore: cast_nullable_to_non_nullable
              as AuthStep,
      firstName: null == firstName
          ? _value.firstName
          : firstName // ignore: cast_nullable_to_non_nullable
              as String,
      phoneRaw: null == phoneRaw
          ? _value.phoneRaw
          : phoneRaw // ignore: cast_nullable_to_non_nullable
              as String,
      otpRaw: null == otpRaw
          ? _value.otpRaw
          : otpRaw // ignore: cast_nullable_to_non_nullable
              as String,
      allDocumentsAccepted: null == allDocumentsAccepted
          ? _value.allDocumentsAccepted
          : allDocumentsAccepted // ignore: cast_nullable_to_non_nullable
              as bool,
      marketingAgreed: null == marketingAgreed
          ? _value.marketingAgreed
          : marketingAgreed // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$AuthStateModelImplCopyWith<$Res>
    implements $AuthStateModelCopyWith<$Res> {
  factory _$$AuthStateModelImplCopyWith(_$AuthStateModelImpl value,
          $Res Function(_$AuthStateModelImpl) then) =
      __$$AuthStateModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {AuthStep currentStep,
      String firstName,
      String phoneRaw,
      String otpRaw,
      bool allDocumentsAccepted,
      bool marketingAgreed});
}

/// @nodoc
class __$$AuthStateModelImplCopyWithImpl<$Res>
    extends _$AuthStateModelCopyWithImpl<$Res, _$AuthStateModelImpl>
    implements _$$AuthStateModelImplCopyWith<$Res> {
  __$$AuthStateModelImplCopyWithImpl(
      _$AuthStateModelImpl _value, $Res Function(_$AuthStateModelImpl) _then)
      : super(_value, _then);

  /// Create a copy of AuthStateModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? currentStep = null,
    Object? firstName = null,
    Object? phoneRaw = null,
    Object? otpRaw = null,
    Object? allDocumentsAccepted = null,
    Object? marketingAgreed = null,
  }) {
    return _then(_$AuthStateModelImpl(
      currentStep: null == currentStep
          ? _value.currentStep
          : currentStep // ignore: cast_nullable_to_non_nullable
              as AuthStep,
      firstName: null == firstName
          ? _value.firstName
          : firstName // ignore: cast_nullable_to_non_nullable
              as String,
      phoneRaw: null == phoneRaw
          ? _value.phoneRaw
          : phoneRaw // ignore: cast_nullable_to_non_nullable
              as String,
      otpRaw: null == otpRaw
          ? _value.otpRaw
          : otpRaw // ignore: cast_nullable_to_non_nullable
              as String,
      allDocumentsAccepted: null == allDocumentsAccepted
          ? _value.allDocumentsAccepted
          : allDocumentsAccepted // ignore: cast_nullable_to_non_nullable
              as bool,
      marketingAgreed: null == marketingAgreed
          ? _value.marketingAgreed
          : marketingAgreed // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc

class _$AuthStateModelImpl extends _AuthStateModel {
  const _$AuthStateModelImpl(
      {required this.currentStep,
      required this.firstName,
      required this.phoneRaw,
      required this.otpRaw,
      required this.allDocumentsAccepted,
      required this.marketingAgreed})
      : super._();

  @override
  final AuthStep currentStep;
// Input fields
  @override
  final String firstName;
  @override
  final String phoneRaw;
  @override
  final String otpRaw;
// Agreements
  @override
  final bool allDocumentsAccepted;
  @override
  final bool marketingAgreed;

  @override
  String toString() {
    return 'AuthStateModel(currentStep: $currentStep, firstName: $firstName, phoneRaw: $phoneRaw, otpRaw: $otpRaw, allDocumentsAccepted: $allDocumentsAccepted, marketingAgreed: $marketingAgreed)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AuthStateModelImpl &&
            (identical(other.currentStep, currentStep) ||
                other.currentStep == currentStep) &&
            (identical(other.firstName, firstName) ||
                other.firstName == firstName) &&
            (identical(other.phoneRaw, phoneRaw) ||
                other.phoneRaw == phoneRaw) &&
            (identical(other.otpRaw, otpRaw) || other.otpRaw == otpRaw) &&
            (identical(other.allDocumentsAccepted, allDocumentsAccepted) ||
                other.allDocumentsAccepted == allDocumentsAccepted) &&
            (identical(other.marketingAgreed, marketingAgreed) ||
                other.marketingAgreed == marketingAgreed));
  }

  @override
  int get hashCode => Object.hash(runtimeType, currentStep, firstName, phoneRaw,
      otpRaw, allDocumentsAccepted, marketingAgreed);

  /// Create a copy of AuthStateModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AuthStateModelImplCopyWith<_$AuthStateModelImpl> get copyWith =>
      __$$AuthStateModelImplCopyWithImpl<_$AuthStateModelImpl>(
          this, _$identity);
}

abstract class _AuthStateModel extends AuthStateModel {
  const factory _AuthStateModel(
      {required final AuthStep currentStep,
      required final String firstName,
      required final String phoneRaw,
      required final String otpRaw,
      required final bool allDocumentsAccepted,
      required final bool marketingAgreed}) = _$AuthStateModelImpl;
  const _AuthStateModel._() : super._();

  @override
  AuthStep get currentStep; // Input fields
  @override
  String get firstName;
  @override
  String get phoneRaw;
  @override
  String get otpRaw; // Agreements
  @override
  bool get allDocumentsAccepted;
  @override
  bool get marketingAgreed;

  /// Create a copy of AuthStateModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AuthStateModelImplCopyWith<_$AuthStateModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
