/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters

import 'package:dartway_serverpod_core_server/src/domain/api/dw_model_wrapper.dart'
    as _i18;
import 'package:serverpod/protocol.dart' as _i2;
// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod/serverpod.dart' as _i1;

import '/src/domain/api/dw_api_response.dart' as _i19;
import '/src/domain/api/dw_auth_data.dart' as _i20;
import '/src/domain/api/dw_backend_filter.dart' as _i21;
import '/src/domain/api/dw_model_wrapper.dart' as _i17;
import 'auth/auth_request/dw_auth_provider.dart' as _i3;
import 'auth/auth_request/dw_auth_request.dart' as _i4;
import 'auth/auth_request/dw_auth_request_status.dart' as _i5;
import 'auth/auth_request/dw_auth_request_type.dart' as _i6;
import 'auth/auth_verification/dw_auth_verification.dart' as _i7;
import 'auth/auth_verification/dw_auth_verification_type.dart' as _i8;
import 'auth/dw_auth_fail_reason.dart' as _i9;
import 'auth/dw_auth_key.dart' as _i10;
import 'auth/dw_user_password.dart' as _i11;
import 'cloud_files/dw_cloud_file.dart' as _i12;
import 'dw_app_notification.dart' as _i13;
import 'dw_backend_filter_type.dart' as _i14;
import 'dw_updates_transport.dart' as _i15;
import 'dw_webhook_log.dart' as _i16;

export 'auth/auth_request/dw_auth_provider.dart';
export 'auth/auth_request/dw_auth_request.dart';
export 'auth/auth_request/dw_auth_request_status.dart';
export 'auth/auth_request/dw_auth_request_type.dart';
export 'auth/auth_verification/dw_auth_verification.dart';
export 'auth/auth_verification/dw_auth_verification_type.dart';
export 'auth/dw_auth_fail_reason.dart';
export 'auth/dw_auth_key.dart';
export 'auth/dw_user_password.dart';
export 'cloud_files/dw_cloud_file.dart';
export 'dw_app_notification.dart';
export 'dw_backend_filter_type.dart';
export 'dw_updates_transport.dart';
export 'dw_webhook_log.dart';

class Protocol extends _i1.SerializationManagerServer {
  Protocol._();

  factory Protocol() => _instance;

  static final Protocol _instance = Protocol._();

  static final List<_i2.TableDefinition> targetTableDefinitions = [
    _i2.TableDefinition(
      name: 'dw_app_notification',
      dartName: 'DwAppNotification',
      schema: 'public',
      module: 'dartway_serverpod_core',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'nextval(\'dw_app_notification_id_seq\'::regclass)',
        ),
        _i2.ColumnDefinition(
          name: 'toUserId',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'identifier',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'timestamp',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
          columnDefault: 'CURRENT_TIMESTAMP',
        ),
        _i2.ColumnDefinition(
          name: 'title',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'body',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'goToPath',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'isRead',
          columnType: _i2.ColumnType.boolean,
          isNullable: false,
          dartType: 'bool',
          columnDefault: 'false',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'dw_app_notification_pkey',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'id',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: true,
        ),
      ],
      managed: true,
    ),
    _i2.TableDefinition(
      name: 'dw_auth_key',
      dartName: 'DwAuthKey',
      schema: 'public',
      module: 'dartway_serverpod_core',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'nextval(\'dw_auth_key_id_seq\'::regclass)',
        ),
        _i2.ColumnDefinition(
          name: 'userId',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'hash',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'dw_auth_key_pkey',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'id',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: true,
        ),
        _i2.IndexDefinition(
          indexName: 'dw_auth_key_userId_idx',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'userId',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _i2.TableDefinition(
      name: 'dw_auth_request',
      dartName: 'DwAuthRequest',
      schema: 'public',
      module: 'dartway_serverpod_core',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'nextval(\'dw_auth_request_id_seq\'::regclass)',
        ),
        _i2.ColumnDefinition(
          name: 'createdAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
          columnDefault: 'CURRENT_TIMESTAMP',
        ),
        _i2.ColumnDefinition(
          name: 'requestType',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'protocol:DwAuthRequestType',
        ),
        _i2.ColumnDefinition(
          name: 'userIdentifier',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'userId',
          columnType: _i2.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _i2.ColumnDefinition(
          name: 'authProvider',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'protocol:DwAuthProvider',
        ),
        _i2.ColumnDefinition(
          name: 'verificationType',
          columnType: _i2.ColumnType.bigint,
          isNullable: true,
          dartType: 'protocol:DwAuthVerificationType?',
        ),
        _i2.ColumnDefinition(
          name: 'verificationHash',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'status',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'protocol:DwAuthRequestStatus',
          columnDefault: '\'created\'::text',
        ),
        _i2.ColumnDefinition(
          name: 'failReason',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'protocol:DwAuthFailReason?',
        ),
        _i2.ColumnDefinition(
          name: 'extraData',
          columnType: _i2.ColumnType.json,
          isNullable: true,
          dartType: 'Map<String,String>?',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'dw_auth_request_pkey',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'id',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: true,
        ),
      ],
      managed: true,
    ),
    _i2.TableDefinition(
      name: 'dw_auth_verification',
      dartName: 'DwAuthVerification',
      schema: 'public',
      module: 'dartway_serverpod_core',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'nextval(\'dw_auth_verification_id_seq\'::regclass)',
        ),
        _i2.ColumnDefinition(
          name: 'dwAuthRequestId',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'createdAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
          columnDefault: 'CURRENT_TIMESTAMP',
        ),
        _i2.ColumnDefinition(
          name: 'failReason',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'protocol:DwAuthFailReason?',
        ),
        _i2.ColumnDefinition(
          name: 'accessToken',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
      ],
      foreignKeys: [
        _i2.ForeignKeyDefinition(
          constraintName: 'dw_auth_verification_fk_0',
          columns: ['dwAuthRequestId'],
          referenceTable: 'dw_auth_request',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _i2.ForeignKeyAction.noAction,
          onDelete: _i2.ForeignKeyAction.noAction,
          matchType: null,
        ),
      ],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'dw_auth_verification_pkey',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'id',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: true,
        ),
      ],
      managed: true,
    ),
    _i2.TableDefinition(
      name: 'dw_cloud_file',
      dartName: 'DwCloudFile',
      schema: 'public',
      module: 'dartway_serverpod_core',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'nextval(\'dw_cloud_file_id_seq\'::regclass)',
        ),
        _i2.ColumnDefinition(
          name: 'createdBy',
          columnType: _i2.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _i2.ColumnDefinition(
          name: 'bucket',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'path',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'publicUrl',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'size',
          columnType: _i2.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _i2.ColumnDefinition(
          name: 'mimeType',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'createdAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _i2.ColumnDefinition(
          name: 'verifiedAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: true,
          dartType: 'DateTime?',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'dw_cloud_file_pkey',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'id',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: true,
        ),
      ],
      managed: true,
    ),
    _i2.TableDefinition(
      name: 'dw_user_password',
      dartName: 'DwUserPassword',
      schema: 'public',
      module: 'dartway_serverpod_core',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'nextval(\'dw_user_password_id_seq\'::regclass)',
        ),
        _i2.ColumnDefinition(
          name: 'userId',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'passwordHash',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'createdAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _i2.ColumnDefinition(
          name: 'updatedAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'dw_user_password_pkey',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'id',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: true,
        ),
        _i2.IndexDefinition(
          indexName: 'dw_user_password_user_id_idx',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'userId',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _i2.TableDefinition(
      name: 'dw_web_server_log',
      dartName: 'DwWebServerLog',
      schema: 'public',
      module: 'dartway_serverpod_core',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'nextval(\'dw_web_server_log_id_seq\'::regclass)',
        ),
        _i2.ColumnDefinition(
          name: 'createdAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _i2.ColumnDefinition(
          name: 'method',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'url',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'headers',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'body',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'statusCode',
          columnType: _i2.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _i2.ColumnDefinition(
          name: 'status',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'error',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'durationMs',
          columnType: _i2.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _i2.ColumnDefinition(
          name: 'handler',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'ip',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'dw_web_server_log_pkey',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'id',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: true,
        ),
      ],
      managed: true,
    ),
  ];

  @override
  T deserialize<T>(dynamic data, [Type? t]) {
    t ??= T;
    if (t == _i3.DwAuthProvider) {
      return _i3.DwAuthProvider.fromJson(data) as T;
    }
    if (t == _i4.DwAuthRequest) {
      return _i4.DwAuthRequest.fromJson(data) as T;
    }
    if (t == _i5.DwAuthRequestStatus) {
      return _i5.DwAuthRequestStatus.fromJson(data) as T;
    }
    if (t == _i6.DwAuthRequestType) {
      return _i6.DwAuthRequestType.fromJson(data) as T;
    }
    if (t == _i7.DwAuthVerification) {
      return _i7.DwAuthVerification.fromJson(data) as T;
    }
    if (t == _i8.DwAuthVerificationType) {
      return _i8.DwAuthVerificationType.fromJson(data) as T;
    }
    if (t == _i9.DwAuthFailReason) {
      return _i9.DwAuthFailReason.fromJson(data) as T;
    }
    if (t == _i10.DwAuthKey) {
      return _i10.DwAuthKey.fromJson(data) as T;
    }
    if (t == _i11.DwUserPassword) {
      return _i11.DwUserPassword.fromJson(data) as T;
    }
    if (t == _i12.DwCloudFile) {
      return _i12.DwCloudFile.fromJson(data) as T;
    }
    if (t == _i13.DwAppNotification) {
      return _i13.DwAppNotification.fromJson(data) as T;
    }
    if (t == _i14.DwBackendFilterType) {
      return _i14.DwBackendFilterType.fromJson(data) as T;
    }
    if (t == _i15.DwUpdatesTransport) {
      return _i15.DwUpdatesTransport.fromJson(data) as T;
    }
    if (t == _i16.DwWebServerLog) {
      return _i16.DwWebServerLog.fromJson(data) as T;
    }
    if (t == _i1.getType<_i3.DwAuthProvider?>()) {
      return (data != null ? _i3.DwAuthProvider.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i4.DwAuthRequest?>()) {
      return (data != null ? _i4.DwAuthRequest.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i5.DwAuthRequestStatus?>()) {
      return (data != null ? _i5.DwAuthRequestStatus.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i6.DwAuthRequestType?>()) {
      return (data != null ? _i6.DwAuthRequestType.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i7.DwAuthVerification?>()) {
      return (data != null ? _i7.DwAuthVerification.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i8.DwAuthVerificationType?>()) {
      return (data != null ? _i8.DwAuthVerificationType.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i9.DwAuthFailReason?>()) {
      return (data != null ? _i9.DwAuthFailReason.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i10.DwAuthKey?>()) {
      return (data != null ? _i10.DwAuthKey.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i11.DwUserPassword?>()) {
      return (data != null ? _i11.DwUserPassword.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i12.DwCloudFile?>()) {
      return (data != null ? _i12.DwCloudFile.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i13.DwAppNotification?>()) {
      return (data != null ? _i13.DwAppNotification.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i14.DwBackendFilterType?>()) {
      return (data != null ? _i14.DwBackendFilterType.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i15.DwUpdatesTransport?>()) {
      return (data != null ? _i15.DwUpdatesTransport.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i16.DwWebServerLog?>()) {
      return (data != null ? _i16.DwWebServerLog.fromJson(data) : null) as T;
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
    if (t == List<_i17.DwModelWrapper>) {
      return (data as List)
              .map((e) => deserialize<_i17.DwModelWrapper>(e))
              .toList()
          as T;
    }
    if (t == _i17.DwModelWrapper) {
      return _i17.DwModelWrapper.fromJson(data) as T;
    }
    if (t == List<_i18.DwModelWrapper>) {
      return (data as List)
              .map((e) => deserialize<_i18.DwModelWrapper>(e))
              .toList()
          as T;
    }
    if (t == _i19.DwApiResponse) {
      return _i19.DwApiResponse.fromJson(data) as T;
    }
    if (t == _i20.DwAuthData) {
      return _i20.DwAuthData.fromJson(data) as T;
    }
    if (t == _i21.DwBackendFilter) {
      return _i21.DwBackendFilter.fromJson(data) as T;
    }
    if (t == _i1.getType<_i17.DwModelWrapper?>()) {
      return (data != null ? _i17.DwModelWrapper.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i19.DwApiResponse?>()) {
      return (data != null ? _i19.DwApiResponse.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i20.DwAuthData?>()) {
      return (data != null ? _i20.DwAuthData.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i21.DwBackendFilter?>()) {
      return (data != null ? _i21.DwBackendFilter.fromJson(data) : null) as T;
    }
    try {
      return _i2.Protocol().deserialize<T>(data, t);
    } on _i1.DeserializationTypeNotFoundException catch (_) {}
    return super.deserialize<T>(data, t);
  }

  @override
  String? getClassNameForObject(Object? data) {
    String? className = super.getClassNameForObject(data);
    if (className != null) return className;
    if (data is _i17.DwModelWrapper) {
      return 'DwModelWrapper';
    }
    if (data is _i19.DwApiResponse) {
      return 'DwApiResponse';
    }
    if (data is _i20.DwAuthData) {
      return 'DwAuthData';
    }
    if (data is _i21.DwBackendFilter) {
      return 'DwBackendFilter';
    }
    if (data is _i3.DwAuthProvider) {
      return 'DwAuthProvider';
    }
    if (data is _i4.DwAuthRequest) {
      return 'DwAuthRequest';
    }
    if (data is _i5.DwAuthRequestStatus) {
      return 'DwAuthRequestStatus';
    }
    if (data is _i6.DwAuthRequestType) {
      return 'DwAuthRequestType';
    }
    if (data is _i7.DwAuthVerification) {
      return 'DwAuthVerification';
    }
    if (data is _i8.DwAuthVerificationType) {
      return 'DwAuthVerificationType';
    }
    if (data is _i9.DwAuthFailReason) {
      return 'DwAuthFailReason';
    }
    if (data is _i10.DwAuthKey) {
      return 'DwAuthKey';
    }
    if (data is _i11.DwUserPassword) {
      return 'DwUserPassword';
    }
    if (data is _i12.DwCloudFile) {
      return 'DwCloudFile';
    }
    if (data is _i13.DwAppNotification) {
      return 'DwAppNotification';
    }
    if (data is _i14.DwBackendFilterType) {
      return 'DwBackendFilterType';
    }
    if (data is _i15.DwUpdatesTransport) {
      return 'DwUpdatesTransport';
    }
    if (data is _i16.DwWebServerLog) {
      return 'DwWebServerLog';
    }
    className = _i2.Protocol().getClassNameForObject(data);
    if (className != null) {
      return 'serverpod.$className';
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
      return deserialize<_i17.DwModelWrapper>(data['data']);
    }
    if (dataClassName == 'DwApiResponse') {
      return deserialize<_i19.DwApiResponse>(data['data']);
    }
    if (dataClassName == 'DwAuthData') {
      return deserialize<_i20.DwAuthData>(data['data']);
    }
    if (dataClassName == 'DwBackendFilter') {
      return deserialize<_i21.DwBackendFilter>(data['data']);
    }
    if (dataClassName == 'DwAuthProvider') {
      return deserialize<_i3.DwAuthProvider>(data['data']);
    }
    if (dataClassName == 'DwAuthRequest') {
      return deserialize<_i4.DwAuthRequest>(data['data']);
    }
    if (dataClassName == 'DwAuthRequestStatus') {
      return deserialize<_i5.DwAuthRequestStatus>(data['data']);
    }
    if (dataClassName == 'DwAuthRequestType') {
      return deserialize<_i6.DwAuthRequestType>(data['data']);
    }
    if (dataClassName == 'DwAuthVerification') {
      return deserialize<_i7.DwAuthVerification>(data['data']);
    }
    if (dataClassName == 'DwAuthVerificationType') {
      return deserialize<_i8.DwAuthVerificationType>(data['data']);
    }
    if (dataClassName == 'DwAuthFailReason') {
      return deserialize<_i9.DwAuthFailReason>(data['data']);
    }
    if (dataClassName == 'DwAuthKey') {
      return deserialize<_i10.DwAuthKey>(data['data']);
    }
    if (dataClassName == 'DwUserPassword') {
      return deserialize<_i11.DwUserPassword>(data['data']);
    }
    if (dataClassName == 'DwCloudFile') {
      return deserialize<_i12.DwCloudFile>(data['data']);
    }
    if (dataClassName == 'DwAppNotification') {
      return deserialize<_i13.DwAppNotification>(data['data']);
    }
    if (dataClassName == 'DwBackendFilterType') {
      return deserialize<_i14.DwBackendFilterType>(data['data']);
    }
    if (dataClassName == 'DwUpdatesTransport') {
      return deserialize<_i15.DwUpdatesTransport>(data['data']);
    }
    if (dataClassName == 'DwWebServerLog') {
      return deserialize<_i16.DwWebServerLog>(data['data']);
    }
    if (dataClassName.startsWith('serverpod.')) {
      data['className'] = dataClassName.substring(10);
      return _i2.Protocol().deserializeByClassName(data);
    }
    return super.deserializeByClassName(data);
  }

  @override
  _i1.Table? getTableForType(Type t) {
    {
      var table = _i2.Protocol().getTableForType(t);
      if (table != null) {
        return table;
      }
    }
    switch (t) {
      case _i4.DwAuthRequest:
        return _i4.DwAuthRequest.t;
      case _i7.DwAuthVerification:
        return _i7.DwAuthVerification.t;
      case _i10.DwAuthKey:
        return _i10.DwAuthKey.t;
      case _i11.DwUserPassword:
        return _i11.DwUserPassword.t;
      case _i12.DwCloudFile:
        return _i12.DwCloudFile.t;
      case _i13.DwAppNotification:
        return _i13.DwAppNotification.t;
      case _i16.DwWebServerLog:
        return _i16.DwWebServerLog.t;
    }
    return null;
  }

  @override
  List<_i2.TableDefinition> getTargetTableDefinitions() =>
      targetTableDefinitions;

  @override
  String getModuleName() => 'dartway_serverpod_core';
}
