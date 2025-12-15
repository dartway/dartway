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
import '../user_profile/user_gender.dart' as _i2;

abstract class UserProfile implements _i1.SerializableModel {
  UserProfile._({
    this.id,
    this.userInfoId,
    required this.phone,
    required this.agreedForMarketingCommunications,
    required this.conditionsAcceptedAt,
    required this.firstName,
    this.lastName,
    this.imageUrl,
    this.gender,
  });

  factory UserProfile({
    int? id,
    int? userInfoId,
    required String phone,
    required bool agreedForMarketingCommunications,
    required DateTime conditionsAcceptedAt,
    required String firstName,
    String? lastName,
    String? imageUrl,
    _i2.UserGender? gender,
  }) = _UserProfileImpl;

  factory UserProfile.fromJson(Map<String, dynamic> jsonSerialization) {
    return UserProfile(
      id: jsonSerialization['id'] as int?,
      userInfoId: jsonSerialization['userInfoId'] as int?,
      phone: jsonSerialization['phone'] as String,
      agreedForMarketingCommunications:
          jsonSerialization['agreedForMarketingCommunications'] as bool,
      conditionsAcceptedAt: _i1.DateTimeJsonExtension.fromJson(
          jsonSerialization['conditionsAcceptedAt']),
      firstName: jsonSerialization['firstName'] as String,
      lastName: jsonSerialization['lastName'] as String?,
      imageUrl: jsonSerialization['imageUrl'] as String?,
      gender: jsonSerialization['gender'] == null
          ? null
          : _i2.UserGender.fromJson((jsonSerialization['gender'] as String)),
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  int? userInfoId;

  String phone;

  bool agreedForMarketingCommunications;

  DateTime conditionsAcceptedAt;

  String firstName;

  String? lastName;

  String? imageUrl;

  _i2.UserGender? gender;

  /// Returns a shallow copy of this [UserProfile]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  UserProfile copyWith({
    int? id,
    int? userInfoId,
    String? phone,
    bool? agreedForMarketingCommunications,
    DateTime? conditionsAcceptedAt,
    String? firstName,
    String? lastName,
    String? imageUrl,
    _i2.UserGender? gender,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (userInfoId != null) 'userInfoId': userInfoId,
      'phone': phone,
      'agreedForMarketingCommunications': agreedForMarketingCommunications,
      'conditionsAcceptedAt': conditionsAcceptedAt.toJson(),
      'firstName': firstName,
      if (lastName != null) 'lastName': lastName,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (gender != null) 'gender': gender?.toJson(),
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _UserProfileImpl extends UserProfile {
  _UserProfileImpl({
    int? id,
    int? userInfoId,
    required String phone,
    required bool agreedForMarketingCommunications,
    required DateTime conditionsAcceptedAt,
    required String firstName,
    String? lastName,
    String? imageUrl,
    _i2.UserGender? gender,
  }) : super._(
          id: id,
          userInfoId: userInfoId,
          phone: phone,
          agreedForMarketingCommunications: agreedForMarketingCommunications,
          conditionsAcceptedAt: conditionsAcceptedAt,
          firstName: firstName,
          lastName: lastName,
          imageUrl: imageUrl,
          gender: gender,
        );

  /// Returns a shallow copy of this [UserProfile]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  UserProfile copyWith({
    Object? id = _Undefined,
    Object? userInfoId = _Undefined,
    String? phone,
    bool? agreedForMarketingCommunications,
    DateTime? conditionsAcceptedAt,
    String? firstName,
    Object? lastName = _Undefined,
    Object? imageUrl = _Undefined,
    Object? gender = _Undefined,
  }) {
    return UserProfile(
      id: id is int? ? id : this.id,
      userInfoId: userInfoId is int? ? userInfoId : this.userInfoId,
      phone: phone ?? this.phone,
      agreedForMarketingCommunications: agreedForMarketingCommunications ??
          this.agreedForMarketingCommunications,
      conditionsAcceptedAt: conditionsAcceptedAt ?? this.conditionsAcceptedAt,
      firstName: firstName ?? this.firstName,
      lastName: lastName is String? ? lastName : this.lastName,
      imageUrl: imageUrl is String? ? imageUrl : this.imageUrl,
      gender: gender is _i2.UserGender? ? gender : this.gender,
    );
  }
}
