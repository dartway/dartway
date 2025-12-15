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

abstract class DwWebServerLog implements _i1.SerializableModel {
  DwWebServerLog._({
    this.id,
    required this.createdAt,
    required this.method,
    required this.url,
    this.headers,
    this.body,
    this.statusCode,
    this.status,
    this.error,
    this.durationMs,
    this.handler,
    this.ip,
  });

  factory DwWebServerLog({
    int? id,
    required DateTime createdAt,
    required String method,
    required String url,
    String? headers,
    String? body,
    int? statusCode,
    String? status,
    String? error,
    int? durationMs,
    String? handler,
    String? ip,
  }) = _DwWebServerLogImpl;

  factory DwWebServerLog.fromJson(Map<String, dynamic> jsonSerialization) {
    return DwWebServerLog(
      id: jsonSerialization['id'] as int?,
      createdAt:
          _i1.DateTimeJsonExtension.fromJson(jsonSerialization['createdAt']),
      method: jsonSerialization['method'] as String,
      url: jsonSerialization['url'] as String,
      headers: jsonSerialization['headers'] as String?,
      body: jsonSerialization['body'] as String?,
      statusCode: jsonSerialization['statusCode'] as int?,
      status: jsonSerialization['status'] as String?,
      error: jsonSerialization['error'] as String?,
      durationMs: jsonSerialization['durationMs'] as int?,
      handler: jsonSerialization['handler'] as String?,
      ip: jsonSerialization['ip'] as String?,
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  DateTime createdAt;

  String method;

  String url;

  String? headers;

  String? body;

  int? statusCode;

  String? status;

  String? error;

  int? durationMs;

  String? handler;

  String? ip;

  /// Returns a shallow copy of this [DwWebServerLog]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  DwWebServerLog copyWith({
    int? id,
    DateTime? createdAt,
    String? method,
    String? url,
    String? headers,
    String? body,
    int? statusCode,
    String? status,
    String? error,
    int? durationMs,
    String? handler,
    String? ip,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'createdAt': createdAt.toJson(),
      'method': method,
      'url': url,
      if (headers != null) 'headers': headers,
      if (body != null) 'body': body,
      if (statusCode != null) 'statusCode': statusCode,
      if (status != null) 'status': status,
      if (error != null) 'error': error,
      if (durationMs != null) 'durationMs': durationMs,
      if (handler != null) 'handler': handler,
      if (ip != null) 'ip': ip,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _DwWebServerLogImpl extends DwWebServerLog {
  _DwWebServerLogImpl({
    int? id,
    required DateTime createdAt,
    required String method,
    required String url,
    String? headers,
    String? body,
    int? statusCode,
    String? status,
    String? error,
    int? durationMs,
    String? handler,
    String? ip,
  }) : super._(
          id: id,
          createdAt: createdAt,
          method: method,
          url: url,
          headers: headers,
          body: body,
          statusCode: statusCode,
          status: status,
          error: error,
          durationMs: durationMs,
          handler: handler,
          ip: ip,
        );

  /// Returns a shallow copy of this [DwWebServerLog]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  DwWebServerLog copyWith({
    Object? id = _Undefined,
    DateTime? createdAt,
    String? method,
    String? url,
    Object? headers = _Undefined,
    Object? body = _Undefined,
    Object? statusCode = _Undefined,
    Object? status = _Undefined,
    Object? error = _Undefined,
    Object? durationMs = _Undefined,
    Object? handler = _Undefined,
    Object? ip = _Undefined,
  }) {
    return DwWebServerLog(
      id: id is int? ? id : this.id,
      createdAt: createdAt ?? this.createdAt,
      method: method ?? this.method,
      url: url ?? this.url,
      headers: headers is String? ? headers : this.headers,
      body: body is String? ? body : this.body,
      statusCode: statusCode is int? ? statusCode : this.statusCode,
      status: status is String? ? status : this.status,
      error: error is String? ? error : this.error,
      durationMs: durationMs is int? ? durationMs : this.durationMs,
      handler: handler is String? ? handler : this.handler,
      ip: ip is String? ? ip : this.ip,
    );
  }
}
