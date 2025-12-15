/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod_client/serverpod_client.dart' as _i1;
import 'user_profile/user_profile.dart' as _i2;

abstract class WaterIntake implements _i1.SerializableModel {
  WaterIntake._({
    this.id,
    required this.userProfileId,
    this.userProfile,
    required this.intakeAmount,
    required this.intakeTime,
  });

  factory WaterIntake({
    int? id,
    required int userProfileId,
    _i2.UserProfile? userProfile,
    required int intakeAmount,
    required DateTime intakeTime,
  }) = _WaterIntakeImpl;

  factory WaterIntake.fromJson(Map<String, dynamic> jsonSerialization) {
    return WaterIntake(
      id: jsonSerialization['id'] as int?,
      userProfileId: jsonSerialization['userProfileId'] as int,
      userProfile: jsonSerialization['userProfile'] == null
          ? null
          : _i2.UserProfile.fromJson(
              (jsonSerialization['userProfile'] as Map<String, dynamic>)),
      intakeAmount: jsonSerialization['intakeAmount'] as int,
      intakeTime:
          _i1.DateTimeJsonExtension.fromJson(jsonSerialization['intakeTime']),
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  int userProfileId;

  _i2.UserProfile? userProfile;

  int intakeAmount;

  DateTime intakeTime;

  /// Returns a shallow copy of this [WaterIntake]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  WaterIntake copyWith({
    int? id,
    int? userProfileId,
    _i2.UserProfile? userProfile,
    int? intakeAmount,
    DateTime? intakeTime,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'userProfileId': userProfileId,
      if (userProfile != null) 'userProfile': userProfile?.toJson(),
      'intakeAmount': intakeAmount,
      'intakeTime': intakeTime.toJson(),
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _WaterIntakeImpl extends WaterIntake {
  _WaterIntakeImpl({
    int? id,
    required int userProfileId,
    _i2.UserProfile? userProfile,
    required int intakeAmount,
    required DateTime intakeTime,
  }) : super._(
          id: id,
          userProfileId: userProfileId,
          userProfile: userProfile,
          intakeAmount: intakeAmount,
          intakeTime: intakeTime,
        );

  /// Returns a shallow copy of this [WaterIntake]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  WaterIntake copyWith({
    Object? id = _Undefined,
    int? userProfileId,
    Object? userProfile = _Undefined,
    int? intakeAmount,
    DateTime? intakeTime,
  }) {
    return WaterIntake(
      id: id is int? ? id : this.id,
      userProfileId: userProfileId ?? this.userProfileId,
      userProfile: userProfile is _i2.UserProfile?
          ? userProfile
          : this.userProfile?.copyWith(),
      intakeAmount: intakeAmount ?? this.intakeAmount,
      intakeTime: intakeTime ?? this.intakeTime,
    );
  }
}
