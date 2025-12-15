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
import 'dw_tinkoff_log_type.dart' as _i2;
import 'dw_tinkoff_api_method.dart' as _i3;

abstract class DwTinkoffLog implements _i1.SerializableModel {
  DwTinkoffLog._({
    this.id,
    required this.timestamp,
    this.terminalKey,
    required this.logType,
    this.method,
    this.endpoint,
    this.paramsString,
    this.tinkoffCustomerId,
    this.paymentId,
    this.paymentStatus,
    this.isOk,
    this.statusCode,
    this.statusMessage,
    this.error,
    this.errorDetails,
    this.responseData,
  });

  factory DwTinkoffLog({
    int? id,
    required DateTime timestamp,
    String? terminalKey,
    required _i2.DwTinkoffLogType logType,
    _i3.DwTinkoffApiMethod? method,
    String? endpoint,
    String? paramsString,
    String? tinkoffCustomerId,
    String? paymentId,
    String? paymentStatus,
    bool? isOk,
    int? statusCode,
    String? statusMessage,
    String? error,
    String? errorDetails,
    String? responseData,
  }) = _DwTinkoffLogImpl;

  factory DwTinkoffLog.fromJson(Map<String, dynamic> jsonSerialization) {
    return DwTinkoffLog(
      id: jsonSerialization['id'] as int?,
      timestamp:
          _i1.DateTimeJsonExtension.fromJson(jsonSerialization['timestamp']),
      terminalKey: jsonSerialization['terminalKey'] as String?,
      logType: _i2.DwTinkoffLogType.fromJson(
          (jsonSerialization['logType'] as String)),
      method: jsonSerialization['method'] == null
          ? null
          : _i3.DwTinkoffApiMethod.fromJson(
              (jsonSerialization['method'] as String)),
      endpoint: jsonSerialization['endpoint'] as String?,
      paramsString: jsonSerialization['paramsString'] as String?,
      tinkoffCustomerId: jsonSerialization['tinkoffCustomerId'] as String?,
      paymentId: jsonSerialization['paymentId'] as String?,
      paymentStatus: jsonSerialization['paymentStatus'] as String?,
      isOk: jsonSerialization['isOk'] as bool?,
      statusCode: jsonSerialization['statusCode'] as int?,
      statusMessage: jsonSerialization['statusMessage'] as String?,
      error: jsonSerialization['error'] as String?,
      errorDetails: jsonSerialization['errorDetails'] as String?,
      responseData: jsonSerialization['responseData'] as String?,
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  DateTime timestamp;

  String? terminalKey;

  _i2.DwTinkoffLogType logType;

  _i3.DwTinkoffApiMethod? method;

  String? endpoint;

  String? paramsString;

  String? tinkoffCustomerId;

  String? paymentId;

  String? paymentStatus;

  bool? isOk;

  int? statusCode;

  String? statusMessage;

  String? error;

  String? errorDetails;

  String? responseData;

  /// Returns a shallow copy of this [DwTinkoffLog]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  DwTinkoffLog copyWith({
    int? id,
    DateTime? timestamp,
    String? terminalKey,
    _i2.DwTinkoffLogType? logType,
    _i3.DwTinkoffApiMethod? method,
    String? endpoint,
    String? paramsString,
    String? tinkoffCustomerId,
    String? paymentId,
    String? paymentStatus,
    bool? isOk,
    int? statusCode,
    String? statusMessage,
    String? error,
    String? errorDetails,
    String? responseData,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'timestamp': timestamp.toJson(),
      if (terminalKey != null) 'terminalKey': terminalKey,
      'logType': logType.toJson(),
      if (method != null) 'method': method?.toJson(),
      if (endpoint != null) 'endpoint': endpoint,
      if (paramsString != null) 'paramsString': paramsString,
      if (tinkoffCustomerId != null) 'tinkoffCustomerId': tinkoffCustomerId,
      if (paymentId != null) 'paymentId': paymentId,
      if (paymentStatus != null) 'paymentStatus': paymentStatus,
      if (isOk != null) 'isOk': isOk,
      if (statusCode != null) 'statusCode': statusCode,
      if (statusMessage != null) 'statusMessage': statusMessage,
      if (error != null) 'error': error,
      if (errorDetails != null) 'errorDetails': errorDetails,
      if (responseData != null) 'responseData': responseData,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _DwTinkoffLogImpl extends DwTinkoffLog {
  _DwTinkoffLogImpl({
    int? id,
    required DateTime timestamp,
    String? terminalKey,
    required _i2.DwTinkoffLogType logType,
    _i3.DwTinkoffApiMethod? method,
    String? endpoint,
    String? paramsString,
    String? tinkoffCustomerId,
    String? paymentId,
    String? paymentStatus,
    bool? isOk,
    int? statusCode,
    String? statusMessage,
    String? error,
    String? errorDetails,
    String? responseData,
  }) : super._(
          id: id,
          timestamp: timestamp,
          terminalKey: terminalKey,
          logType: logType,
          method: method,
          endpoint: endpoint,
          paramsString: paramsString,
          tinkoffCustomerId: tinkoffCustomerId,
          paymentId: paymentId,
          paymentStatus: paymentStatus,
          isOk: isOk,
          statusCode: statusCode,
          statusMessage: statusMessage,
          error: error,
          errorDetails: errorDetails,
          responseData: responseData,
        );

  /// Returns a shallow copy of this [DwTinkoffLog]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  DwTinkoffLog copyWith({
    Object? id = _Undefined,
    DateTime? timestamp,
    Object? terminalKey = _Undefined,
    _i2.DwTinkoffLogType? logType,
    Object? method = _Undefined,
    Object? endpoint = _Undefined,
    Object? paramsString = _Undefined,
    Object? tinkoffCustomerId = _Undefined,
    Object? paymentId = _Undefined,
    Object? paymentStatus = _Undefined,
    Object? isOk = _Undefined,
    Object? statusCode = _Undefined,
    Object? statusMessage = _Undefined,
    Object? error = _Undefined,
    Object? errorDetails = _Undefined,
    Object? responseData = _Undefined,
  }) {
    return DwTinkoffLog(
      id: id is int? ? id : this.id,
      timestamp: timestamp ?? this.timestamp,
      terminalKey: terminalKey is String? ? terminalKey : this.terminalKey,
      logType: logType ?? this.logType,
      method: method is _i3.DwTinkoffApiMethod? ? method : this.method,
      endpoint: endpoint is String? ? endpoint : this.endpoint,
      paramsString: paramsString is String? ? paramsString : this.paramsString,
      tinkoffCustomerId: tinkoffCustomerId is String?
          ? tinkoffCustomerId
          : this.tinkoffCustomerId,
      paymentId: paymentId is String? ? paymentId : this.paymentId,
      paymentStatus:
          paymentStatus is String? ? paymentStatus : this.paymentStatus,
      isOk: isOk is bool? ? isOk : this.isOk,
      statusCode: statusCode is int? ? statusCode : this.statusCode,
      statusMessage:
          statusMessage is String? ? statusMessage : this.statusMessage,
      error: error is String? ? error : this.error,
      errorDetails: errorDetails is String? ? errorDetails : this.errorDetails,
      responseData: responseData is String? ? responseData : this.responseData,
    );
  }
}
