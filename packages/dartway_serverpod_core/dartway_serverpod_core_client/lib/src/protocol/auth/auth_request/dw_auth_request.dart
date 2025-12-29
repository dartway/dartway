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
import '../../auth/auth_request/dw_auth_request_status.dart' as _i2;
import '../../auth/auth_request/dw_auth_request_type.dart' as _i3;
import '../../auth/auth_request/dw_auth_provider.dart' as _i4;
import '../../auth/auth_verification/dw_auth_verification_type.dart' as _i5;
import '../../auth/dw_auth_fail_reason.dart' as _i6;

abstract class DwAuthRequest implements _i1.SerializableModel {
  DwAuthRequest._({
    this.id,
    DateTime? createdAt,
    required this.requestType,
    required this.userIdentifier,
    this.userId,
    required this.authProvider,
    this.verificationType,
    this.password,
    this.newPassword,
    this.accessToken,
    _i2.DwAuthRequestStatus? status,
    this.failReason,
    this.extraData,
  })  : createdAt = createdAt ?? DateTime.now(),
        status = status ?? _i2.DwAuthRequestStatus.created;

  factory DwAuthRequest({
    int? id,
    DateTime? createdAt,
    required _i3.DwAuthRequestType requestType,
    required String userIdentifier,
    int? userId,
    required _i4.DwAuthProvider authProvider,
    _i5.DwAuthVerificationType? verificationType,
    String? password,
    String? newPassword,
    String? accessToken,
    _i2.DwAuthRequestStatus? status,
    _i6.DwAuthFailReason? failReason,
    Map<String, String>? extraData,
  }) = _DwAuthRequestImpl;

  factory DwAuthRequest.fromJson(Map<String, dynamic> jsonSerialization) {
    return DwAuthRequest(
      id: jsonSerialization['id'] as int?,
      createdAt:
          _i1.DateTimeJsonExtension.fromJson(jsonSerialization['createdAt']),
      requestType: _i3.DwAuthRequestType.fromJson(
          (jsonSerialization['requestType'] as String)),
      userIdentifier: jsonSerialization['userIdentifier'] as String,
      userId: jsonSerialization['userId'] as int?,
      authProvider: _i4.DwAuthProvider.fromJson(
          (jsonSerialization['authProvider'] as String)),
      verificationType: jsonSerialization['verificationType'] == null
          ? null
          : _i5.DwAuthVerificationType.fromJson(
              (jsonSerialization['verificationType'] as int)),
      password: jsonSerialization['password'] as String?,
      newPassword: jsonSerialization['newPassword'] as String?,
      accessToken: jsonSerialization['accessToken'] as String?,
      status: _i2.DwAuthRequestStatus.fromJson(
          (jsonSerialization['status'] as String)),
      failReason: jsonSerialization['failReason'] == null
          ? null
          : _i6.DwAuthFailReason.fromJson(
              (jsonSerialization['failReason'] as String)),
      extraData:
          (jsonSerialization['extraData'] as Map?)?.map((k, v) => MapEntry(
                k as String,
                v as String,
              )),
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  DateTime createdAt;

  _i3.DwAuthRequestType requestType;

  String userIdentifier;

  int? userId;

  _i4.DwAuthProvider authProvider;

  _i5.DwAuthVerificationType? verificationType;

  String? password;

  String? newPassword;

  String? accessToken;

  _i2.DwAuthRequestStatus status;

  _i6.DwAuthFailReason? failReason;

  Map<String, String>? extraData;

  /// Returns a shallow copy of this [DwAuthRequest]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  DwAuthRequest copyWith({
    int? id,
    DateTime? createdAt,
    _i3.DwAuthRequestType? requestType,
    String? userIdentifier,
    int? userId,
    _i4.DwAuthProvider? authProvider,
    _i5.DwAuthVerificationType? verificationType,
    String? password,
    String? newPassword,
    String? accessToken,
    _i2.DwAuthRequestStatus? status,
    _i6.DwAuthFailReason? failReason,
    Map<String, String>? extraData,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'createdAt': createdAt.toJson(),
      'requestType': requestType.toJson(),
      'userIdentifier': userIdentifier,
      if (userId != null) 'userId': userId,
      'authProvider': authProvider.toJson(),
      if (verificationType != null)
        'verificationType': verificationType?.toJson(),
      if (password != null) 'password': password,
      if (newPassword != null) 'newPassword': newPassword,
      if (accessToken != null) 'accessToken': accessToken,
      'status': status.toJson(),
      if (failReason != null) 'failReason': failReason?.toJson(),
      if (extraData != null) 'extraData': extraData?.toJson(),
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _DwAuthRequestImpl extends DwAuthRequest {
  _DwAuthRequestImpl({
    int? id,
    DateTime? createdAt,
    required _i3.DwAuthRequestType requestType,
    required String userIdentifier,
    int? userId,
    required _i4.DwAuthProvider authProvider,
    _i5.DwAuthVerificationType? verificationType,
    String? password,
    String? newPassword,
    String? accessToken,
    _i2.DwAuthRequestStatus? status,
    _i6.DwAuthFailReason? failReason,
    Map<String, String>? extraData,
  }) : super._(
          id: id,
          createdAt: createdAt,
          requestType: requestType,
          userIdentifier: userIdentifier,
          userId: userId,
          authProvider: authProvider,
          verificationType: verificationType,
          password: password,
          newPassword: newPassword,
          accessToken: accessToken,
          status: status,
          failReason: failReason,
          extraData: extraData,
        );

  /// Returns a shallow copy of this [DwAuthRequest]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  DwAuthRequest copyWith({
    Object? id = _Undefined,
    DateTime? createdAt,
    _i3.DwAuthRequestType? requestType,
    String? userIdentifier,
    Object? userId = _Undefined,
    _i4.DwAuthProvider? authProvider,
    Object? verificationType = _Undefined,
    Object? password = _Undefined,
    Object? newPassword = _Undefined,
    Object? accessToken = _Undefined,
    _i2.DwAuthRequestStatus? status,
    Object? failReason = _Undefined,
    Object? extraData = _Undefined,
  }) {
    return DwAuthRequest(
      id: id is int? ? id : this.id,
      createdAt: createdAt ?? this.createdAt,
      requestType: requestType ?? this.requestType,
      userIdentifier: userIdentifier ?? this.userIdentifier,
      userId: userId is int? ? userId : this.userId,
      authProvider: authProvider ?? this.authProvider,
      verificationType: verificationType is _i5.DwAuthVerificationType?
          ? verificationType
          : this.verificationType,
      password: password is String? ? password : this.password,
      newPassword: newPassword is String? ? newPassword : this.newPassword,
      accessToken: accessToken is String? ? accessToken : this.accessToken,
      status: status ?? this.status,
      failReason:
          failReason is _i6.DwAuthFailReason? ? failReason : this.failReason,
      extraData: extraData is Map<String, String>?
          ? extraData
          : this.extraData?.map((
                key0,
                value0,
              ) =>
                  MapEntry(
                    key0,
                    value0,
                  )),
    );
  }
}
