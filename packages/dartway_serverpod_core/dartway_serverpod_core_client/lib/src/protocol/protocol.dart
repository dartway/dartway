/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters

import 'package:dartway_serverpod_core_client/src/domain/api/dw_model_wrapper.dart'
    as _i17;
// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod_client/serverpod_client.dart' as _i1;

import '/src/domain/api/dw_api_response.dart' as _i18;
import '/src/domain/api/dw_auth_data.dart' as _i19;
import '/src/domain/api/dw_backend_filter.dart' as _i20;
import '/src/domain/api/dw_model_wrapper.dart' as _i16;
import 'auth/auth_request/dw_auth_provider.dart' as _i2;
import 'auth/auth_request/dw_auth_request.dart' as _i3;
import 'auth/auth_request/dw_auth_request_status.dart' as _i4;
import 'auth/auth_request/dw_auth_request_type.dart' as _i5;
import 'auth/auth_verification/dw_auth_verification.dart' as _i6;
import 'auth/auth_verification/dw_auth_verification_type.dart' as _i7;
import 'auth/dw_auth_fail_reason.dart' as _i8;
import 'auth/dw_auth_key.dart' as _i9;
import 'auth/dw_user_password.dart' as _i10;
import 'cloud_files/dw_cloud_file.dart' as _i11;
import 'dw_app_notification.dart' as _i12;
import 'dw_backend_filter_type.dart' as _i13;
import 'dw_updates_transport.dart' as _i14;
import 'dw_webhook_log.dart' as _i15;

export 'auth/auth_request/dw_auth_provider.dart';
export 'auth/auth_request/dw_auth_request.dart';
export 'auth/auth_request/dw_auth_request_status.dart';
export 'auth/auth_request/dw_auth_request_type.dart';
export 'auth/auth_verification/dw_auth_verification.dart';
export 'auth/auth_verification/dw_auth_verification_type.dart';
export 'auth/dw_auth_fail_reason.dart';
export 'auth/dw_auth_key.dart';
export 'auth/dw_user_password.dart';
export 'client.dart';
export 'cloud_files/dw_cloud_file.dart';
export 'dw_app_notification.dart';
export 'dw_backend_filter_type.dart';
export 'dw_updates_transport.dart';
export 'dw_webhook_log.dart';

class Protocol extends _i1.SerializationManager {
  Protocol._();

  factory Protocol() => _instance;

  static final Protocol _instance = Protocol._();

  @override
  T deserialize<T>(dynamic data, [Type? t]) {
    t ??= T;
    if (data is Map<String, dynamic>) {
      final manualDeserialization = _i18.DwApiResponse.manualDeserialization<T>(
        data,
      );
      if (manualDeserialization != null) return manualDeserialization;
    }
    if (t == _i2.DwAuthProvider) {
      return _i2.DwAuthProvider.fromJson(data) as T;
    }
    if (t == _i3.DwAuthRequest) {
      return _i3.DwAuthRequest.fromJson(data) as T;
    }
    if (t == _i4.DwAuthRequestStatus) {
      return _i4.DwAuthRequestStatus.fromJson(data) as T;
    }
    if (t == _i5.DwAuthRequestType) {
      return _i5.DwAuthRequestType.fromJson(data) as T;
    }
    if (t == _i6.DwAuthVerification) {
      return _i6.DwAuthVerification.fromJson(data) as T;
    }
    if (t == _i7.DwAuthVerificationType) {
      return _i7.DwAuthVerificationType.fromJson(data) as T;
    }
    if (t == _i8.DwAuthFailReason) {
      return _i8.DwAuthFailReason.fromJson(data) as T;
    }
    if (t == _i9.DwAuthKey) {
      return _i9.DwAuthKey.fromJson(data) as T;
    }
    if (t == _i10.DwUserPassword) {
      return _i10.DwUserPassword.fromJson(data) as T;
    }
    if (t == _i11.DwCloudFile) {
      return _i11.DwCloudFile.fromJson(data) as T;
    }
    if (t == _i12.DwAppNotification) {
      return _i12.DwAppNotification.fromJson(data) as T;
    }
    if (t == _i13.DwBackendFilterType) {
      return _i13.DwBackendFilterType.fromJson(data) as T;
    }
    if (t == _i14.DwUpdatesTransport) {
      return _i14.DwUpdatesTransport.fromJson(data) as T;
    }
    if (t == _i15.DwWebServerLog) {
      return _i15.DwWebServerLog.fromJson(data) as T;
    }
    if (t == _i1.getType<_i2.DwAuthProvider?>()) {
      return (data != null ? _i2.DwAuthProvider.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i3.DwAuthRequest?>()) {
      return (data != null ? _i3.DwAuthRequest.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i4.DwAuthRequestStatus?>()) {
      return (data != null ? _i4.DwAuthRequestStatus.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i5.DwAuthRequestType?>()) {
      return (data != null ? _i5.DwAuthRequestType.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i6.DwAuthVerification?>()) {
      return (data != null ? _i6.DwAuthVerification.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i7.DwAuthVerificationType?>()) {
      return (data != null ? _i7.DwAuthVerificationType.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i8.DwAuthFailReason?>()) {
      return (data != null ? _i8.DwAuthFailReason.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i9.DwAuthKey?>()) {
      return (data != null ? _i9.DwAuthKey.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i10.DwUserPassword?>()) {
      return (data != null ? _i10.DwUserPassword.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i11.DwCloudFile?>()) {
      return (data != null ? _i11.DwCloudFile.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i12.DwAppNotification?>()) {
      return (data != null ? _i12.DwAppNotification.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i13.DwBackendFilterType?>()) {
      return (data != null ? _i13.DwBackendFilterType.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i14.DwUpdatesTransport?>()) {
      return (data != null ? _i14.DwUpdatesTransport.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i15.DwWebServerLog?>()) {
      return (data != null ? _i15.DwWebServerLog.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<Map<String, String>?>()) {
      return (data != null
              ? (data as Map).map(
                (k, v) =>
                    MapEntry(deserialize<String>(k), deserialize<String>(v)),
              )
              : null)
          as T;
    }
    if (t == List<_i16.DwModelWrapper>) {
      return (data as List)
              .map((e) => deserialize<_i16.DwModelWrapper>(e))
              .toList()
          as T;
    }
    if (t == _i16.DwModelWrapper) {
      return _i16.DwModelWrapper.fromJson(data) as T;
    }
    if (t == List<_i17.DwModelWrapper>) {
      return (data as List)
              .map((e) => deserialize<_i17.DwModelWrapper>(e))
              .toList()
          as T;
    }
    if (t == _i18.DwApiResponse) {
      return _i18.DwApiResponse.fromJson(data) as T;
    }
    if (t == _i19.DwAuthData) {
      return _i19.DwAuthData.fromJson(data) as T;
    }
    if (t == _i20.DwBackendFilter) {
      return _i20.DwBackendFilter.fromJson(data) as T;
    }
    if (t == _i1.getType<_i16.DwModelWrapper?>()) {
      return (data != null ? _i16.DwModelWrapper.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i18.DwApiResponse?>()) {
      return (data != null ? _i18.DwApiResponse.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i19.DwAuthData?>()) {
      return (data != null ? _i19.DwAuthData.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i20.DwBackendFilter?>()) {
      return (data != null ? _i20.DwBackendFilter.fromJson(data) : null) as T;
    }
    return super.deserialize<T>(data, t);
  }

  @override
  String? getClassNameForObject(Object? data) {
    String? className = super.getClassNameForObject(data);
    if (className != null) return className;
    if (data is _i16.DwModelWrapper) {
      return 'DwModelWrapper';
    }
    if (data is _i18.DwApiResponse) {
      return 'DwApiResponse';
    }
    if (data is _i19.DwAuthData) {
      return 'DwAuthData';
    }
    if (data is _i20.DwBackendFilter) {
      return 'DwBackendFilter';
    }
    if (data is _i2.DwAuthProvider) {
      return 'DwAuthProvider';
    }
    if (data is _i3.DwAuthRequest) {
      return 'DwAuthRequest';
    }
    if (data is _i4.DwAuthRequestStatus) {
      return 'DwAuthRequestStatus';
    }
    if (data is _i5.DwAuthRequestType) {
      return 'DwAuthRequestType';
    }
    if (data is _i6.DwAuthVerification) {
      return 'DwAuthVerification';
    }
    if (data is _i7.DwAuthVerificationType) {
      return 'DwAuthVerificationType';
    }
    if (data is _i8.DwAuthFailReason) {
      return 'DwAuthFailReason';
    }
    if (data is _i9.DwAuthKey) {
      return 'DwAuthKey';
    }
    if (data is _i10.DwUserPassword) {
      return 'DwUserPassword';
    }
    if (data is _i11.DwCloudFile) {
      return 'DwCloudFile';
    }
    if (data is _i12.DwAppNotification) {
      return 'DwAppNotification';
    }
    if (data is _i13.DwBackendFilterType) {
      return 'DwBackendFilterType';
    }
    if (data is _i14.DwUpdatesTransport) {
      return 'DwUpdatesTransport';
    }
    if (data is _i15.DwWebServerLog) {
      return 'DwWebServerLog';
    }
    return null;
  }

  @override
  dynamic deserializeByClassName(Map<String, dynamic> data) {
    var dataClassName = data['className'];
    if (dataClassName is! String) {
      return super.deserializeByClassName(data);
    }
    if (dataClassName == 'DwModelWrapper') {
      return deserialize<_i16.DwModelWrapper>(data['data']);
    }
    if (dataClassName == 'DwApiResponse') {
      return deserialize<_i18.DwApiResponse>(data['data']);
    }
    if (dataClassName == 'DwAuthData') {
      return deserialize<_i19.DwAuthData>(data['data']);
    }
    if (dataClassName == 'DwBackendFilter') {
      return deserialize<_i20.DwBackendFilter>(data['data']);
    }
    if (dataClassName == 'DwAuthProvider') {
      return deserialize<_i2.DwAuthProvider>(data['data']);
    }
    if (dataClassName == 'DwAuthRequest') {
      return deserialize<_i3.DwAuthRequest>(data['data']);
    }
    if (dataClassName == 'DwAuthRequestStatus') {
      return deserialize<_i4.DwAuthRequestStatus>(data['data']);
    }
    if (dataClassName == 'DwAuthRequestType') {
      return deserialize<_i5.DwAuthRequestType>(data['data']);
    }
    if (dataClassName == 'DwAuthVerification') {
      return deserialize<_i6.DwAuthVerification>(data['data']);
    }
    if (dataClassName == 'DwAuthVerificationType') {
      return deserialize<_i7.DwAuthVerificationType>(data['data']);
    }
    if (dataClassName == 'DwAuthFailReason') {
      return deserialize<_i8.DwAuthFailReason>(data['data']);
    }
    if (dataClassName == 'DwAuthKey') {
      return deserialize<_i9.DwAuthKey>(data['data']);
    }
    if (dataClassName == 'DwUserPassword') {
      return deserialize<_i10.DwUserPassword>(data['data']);
    }
    if (dataClassName == 'DwCloudFile') {
      return deserialize<_i11.DwCloudFile>(data['data']);
    }
    if (dataClassName == 'DwAppNotification') {
      return deserialize<_i12.DwAppNotification>(data['data']);
    }
    if (dataClassName == 'DwBackendFilterType') {
      return deserialize<_i13.DwBackendFilterType>(data['data']);
    }
    if (dataClassName == 'DwUpdatesTransport') {
      return deserialize<_i14.DwUpdatesTransport>(data['data']);
    }
    if (dataClassName == 'DwWebServerLog') {
      return deserialize<_i15.DwWebServerLog>(data['data']);
    }
    return super.deserializeByClassName(data);
  }
}
