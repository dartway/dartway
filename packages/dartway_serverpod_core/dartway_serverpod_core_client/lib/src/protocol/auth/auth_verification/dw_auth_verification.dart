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

import '../auth_request/dw_auth_request.dart' as _i2;
import '../dw_auth_fail_reason.dart' as _i3;

abstract class DwAuthVerification implements _i1.SerializableModel {
  DwAuthVerification._({
    this.id,
    required this.dwAuthRequestId,
    this.dwAuthRequest,
    DateTime? createdAt,
    this.verificationCode,
    this.failReason,
    this.accessToken,
  }) : createdAt = createdAt ?? DateTime.now();

  factory DwAuthVerification({
    int? id,
    required int dwAuthRequestId,
    _i2.DwAuthRequest? dwAuthRequest,
    DateTime? createdAt,
    String? verificationCode,
    _i3.DwAuthFailReason? failReason,
    String? accessToken,
  }) = _DwAuthVerificationImpl;

  factory DwAuthVerification.fromJson(Map<String, dynamic> jsonSerialization) {
    return DwAuthVerification(
      id: jsonSerialization['id'] as int?,
      dwAuthRequestId: jsonSerialization['dwAuthRequestId'] as int,
      dwAuthRequest: jsonSerialization['dwAuthRequest'] == null
          ? null
          : _i2.DwAuthRequest.fromJson(
              (jsonSerialization['dwAuthRequest'] as Map<String, dynamic>)),
      createdAt:
          _i1.DateTimeJsonExtension.fromJson(jsonSerialization['createdAt']),
      verificationCode: jsonSerialization['verificationCode'] as String?,
      failReason: jsonSerialization['failReason'] == null
          ? null
          : _i3.DwAuthFailReason.fromJson(
              (jsonSerialization['failReason'] as String)),
      accessToken: jsonSerialization['accessToken'] as String?,
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  int dwAuthRequestId;

  _i2.DwAuthRequest? dwAuthRequest;

  DateTime createdAt;

  String? verificationCode;

  _i3.DwAuthFailReason? failReason;

  String? accessToken;

  /// Returns a shallow copy of this [DwAuthVerification]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  DwAuthVerification copyWith({
    int? id,
    int? dwAuthRequestId,
    _i2.DwAuthRequest? dwAuthRequest,
    DateTime? createdAt,
    String? verificationCode,
    _i3.DwAuthFailReason? failReason,
    String? accessToken,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'dwAuthRequestId': dwAuthRequestId,
      if (dwAuthRequest != null) 'dwAuthRequest': dwAuthRequest?.toJson(),
      'createdAt': createdAt.toJson(),
      if (verificationCode != null) 'verificationCode': verificationCode,
      if (failReason != null) 'failReason': failReason?.toJson(),
      if (accessToken != null) 'accessToken': accessToken,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _DwAuthVerificationImpl extends DwAuthVerification {
  _DwAuthVerificationImpl({
    int? id,
    required int dwAuthRequestId,
    _i2.DwAuthRequest? dwAuthRequest,
    DateTime? createdAt,
    String? verificationCode,
    _i3.DwAuthFailReason? failReason,
    String? accessToken,
  }) : super._(
          id: id,
          dwAuthRequestId: dwAuthRequestId,
          dwAuthRequest: dwAuthRequest,
          createdAt: createdAt,
          verificationCode: verificationCode,
          failReason: failReason,
          accessToken: accessToken,
        );

  /// Returns a shallow copy of this [DwAuthVerification]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  DwAuthVerification copyWith({
    Object? id = _Undefined,
    int? dwAuthRequestId,
    Object? dwAuthRequest = _Undefined,
    DateTime? createdAt,
    Object? verificationCode = _Undefined,
    Object? failReason = _Undefined,
    Object? accessToken = _Undefined,
  }) {
    return DwAuthVerification(
      id: id is int? ? id : this.id,
      dwAuthRequestId: dwAuthRequestId ?? this.dwAuthRequestId,
      dwAuthRequest: dwAuthRequest is _i2.DwAuthRequest?
          ? dwAuthRequest
          : this.dwAuthRequest?.copyWith(),
      createdAt: createdAt ?? this.createdAt,
      verificationCode: verificationCode is String?
          ? verificationCode
          : this.verificationCode,
      failReason:
          failReason is _i3.DwAuthFailReason? ? failReason : this.failReason,
      accessToken: accessToken is String? ? accessToken : this.accessToken,
    );
  }
}
