// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'auth_state_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$AuthStateModel {

 AuthStep get currentStep;// Input fields
 String get firstName; String get phoneRaw; String get otpRaw;// Agreements
 bool get allDocumentsAccepted; bool get marketingAgreed;
/// Create a copy of AuthStateModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AuthStateModelCopyWith<AuthStateModel> get copyWith => _$AuthStateModelCopyWithImpl<AuthStateModel>(this as AuthStateModel, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AuthStateModel&&(identical(other.currentStep, currentStep) || other.currentStep == currentStep)&&(identical(other.firstName, firstName) || other.firstName == firstName)&&(identical(other.phoneRaw, phoneRaw) || other.phoneRaw == phoneRaw)&&(identical(other.otpRaw, otpRaw) || other.otpRaw == otpRaw)&&(identical(other.allDocumentsAccepted, allDocumentsAccepted) || other.allDocumentsAccepted == allDocumentsAccepted)&&(identical(other.marketingAgreed, marketingAgreed) || other.marketingAgreed == marketingAgreed));
}


@override
int get hashCode => Object.hash(runtimeType,currentStep,firstName,phoneRaw,otpRaw,allDocumentsAccepted,marketingAgreed);

@override
String toString() {
  return 'AuthStateModel(currentStep: $currentStep, firstName: $firstName, phoneRaw: $phoneRaw, otpRaw: $otpRaw, allDocumentsAccepted: $allDocumentsAccepted, marketingAgreed: $marketingAgreed)';
}


}

/// @nodoc
abstract mixin class $AuthStateModelCopyWith<$Res>  {
  factory $AuthStateModelCopyWith(AuthStateModel value, $Res Function(AuthStateModel) _then) = _$AuthStateModelCopyWithImpl;
@useResult
$Res call({
 AuthStep currentStep, String firstName, String phoneRaw, String otpRaw, bool allDocumentsAccepted, bool marketingAgreed
});




}
/// @nodoc
class _$AuthStateModelCopyWithImpl<$Res>
    implements $AuthStateModelCopyWith<$Res> {
  _$AuthStateModelCopyWithImpl(this._self, this._then);

  final AuthStateModel _self;
  final $Res Function(AuthStateModel) _then;

/// Create a copy of AuthStateModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? currentStep = null,Object? firstName = null,Object? phoneRaw = null,Object? otpRaw = null,Object? allDocumentsAccepted = null,Object? marketingAgreed = null,}) {
  return _then(_self.copyWith(
currentStep: null == currentStep ? _self.currentStep : currentStep // ignore: cast_nullable_to_non_nullable
as AuthStep,firstName: null == firstName ? _self.firstName : firstName // ignore: cast_nullable_to_non_nullable
as String,phoneRaw: null == phoneRaw ? _self.phoneRaw : phoneRaw // ignore: cast_nullable_to_non_nullable
as String,otpRaw: null == otpRaw ? _self.otpRaw : otpRaw // ignore: cast_nullable_to_non_nullable
as String,allDocumentsAccepted: null == allDocumentsAccepted ? _self.allDocumentsAccepted : allDocumentsAccepted // ignore: cast_nullable_to_non_nullable
as bool,marketingAgreed: null == marketingAgreed ? _self.marketingAgreed : marketingAgreed // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [AuthStateModel].
extension AuthStateModelPatterns on AuthStateModel {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AuthStateModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AuthStateModel() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AuthStateModel value)  $default,){
final _that = this;
switch (_that) {
case _AuthStateModel():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AuthStateModel value)?  $default,){
final _that = this;
switch (_that) {
case _AuthStateModel() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( AuthStep currentStep,  String firstName,  String phoneRaw,  String otpRaw,  bool allDocumentsAccepted,  bool marketingAgreed)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AuthStateModel() when $default != null:
return $default(_that.currentStep,_that.firstName,_that.phoneRaw,_that.otpRaw,_that.allDocumentsAccepted,_that.marketingAgreed);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( AuthStep currentStep,  String firstName,  String phoneRaw,  String otpRaw,  bool allDocumentsAccepted,  bool marketingAgreed)  $default,) {final _that = this;
switch (_that) {
case _AuthStateModel():
return $default(_that.currentStep,_that.firstName,_that.phoneRaw,_that.otpRaw,_that.allDocumentsAccepted,_that.marketingAgreed);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( AuthStep currentStep,  String firstName,  String phoneRaw,  String otpRaw,  bool allDocumentsAccepted,  bool marketingAgreed)?  $default,) {final _that = this;
switch (_that) {
case _AuthStateModel() when $default != null:
return $default(_that.currentStep,_that.firstName,_that.phoneRaw,_that.otpRaw,_that.allDocumentsAccepted,_that.marketingAgreed);case _:
  return null;

}
}

}

/// @nodoc


class _AuthStateModel extends AuthStateModel {
  const _AuthStateModel({required this.currentStep, required this.firstName, required this.phoneRaw, required this.otpRaw, required this.allDocumentsAccepted, required this.marketingAgreed}): super._();
  

@override final  AuthStep currentStep;
// Input fields
@override final  String firstName;
@override final  String phoneRaw;
@override final  String otpRaw;
// Agreements
@override final  bool allDocumentsAccepted;
@override final  bool marketingAgreed;

/// Create a copy of AuthStateModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AuthStateModelCopyWith<_AuthStateModel> get copyWith => __$AuthStateModelCopyWithImpl<_AuthStateModel>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AuthStateModel&&(identical(other.currentStep, currentStep) || other.currentStep == currentStep)&&(identical(other.firstName, firstName) || other.firstName == firstName)&&(identical(other.phoneRaw, phoneRaw) || other.phoneRaw == phoneRaw)&&(identical(other.otpRaw, otpRaw) || other.otpRaw == otpRaw)&&(identical(other.allDocumentsAccepted, allDocumentsAccepted) || other.allDocumentsAccepted == allDocumentsAccepted)&&(identical(other.marketingAgreed, marketingAgreed) || other.marketingAgreed == marketingAgreed));
}


@override
int get hashCode => Object.hash(runtimeType,currentStep,firstName,phoneRaw,otpRaw,allDocumentsAccepted,marketingAgreed);

@override
String toString() {
  return 'AuthStateModel(currentStep: $currentStep, firstName: $firstName, phoneRaw: $phoneRaw, otpRaw: $otpRaw, allDocumentsAccepted: $allDocumentsAccepted, marketingAgreed: $marketingAgreed)';
}


}

/// @nodoc
abstract mixin class _$AuthStateModelCopyWith<$Res> implements $AuthStateModelCopyWith<$Res> {
  factory _$AuthStateModelCopyWith(_AuthStateModel value, $Res Function(_AuthStateModel) _then) = __$AuthStateModelCopyWithImpl;
@override @useResult
$Res call({
 AuthStep currentStep, String firstName, String phoneRaw, String otpRaw, bool allDocumentsAccepted, bool marketingAgreed
});




}
/// @nodoc
class __$AuthStateModelCopyWithImpl<$Res>
    implements _$AuthStateModelCopyWith<$Res> {
  __$AuthStateModelCopyWithImpl(this._self, this._then);

  final _AuthStateModel _self;
  final $Res Function(_AuthStateModel) _then;

/// Create a copy of AuthStateModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? currentStep = null,Object? firstName = null,Object? phoneRaw = null,Object? otpRaw = null,Object? allDocumentsAccepted = null,Object? marketingAgreed = null,}) {
  return _then(_AuthStateModel(
currentStep: null == currentStep ? _self.currentStep : currentStep // ignore: cast_nullable_to_non_nullable
as AuthStep,firstName: null == firstName ? _self.firstName : firstName // ignore: cast_nullable_to_non_nullable
as String,phoneRaw: null == phoneRaw ? _self.phoneRaw : phoneRaw // ignore: cast_nullable_to_non_nullable
as String,otpRaw: null == otpRaw ? _self.otpRaw : otpRaw // ignore: cast_nullable_to_non_nullable
as String,allDocumentsAccepted: null == allDocumentsAccepted ? _self.allDocumentsAccepted : allDocumentsAccepted // ignore: cast_nullable_to_non_nullable
as bool,marketingAgreed: null == marketingAgreed ? _self.marketingAgreed : marketingAgreed // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
