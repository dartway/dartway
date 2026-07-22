/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod/serverpod.dart' as _i1;
import 'package:serverpod/protocol.dart' as _i2;
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
import 'push/dw_push_delivery.dart' as _i17;
import 'push/dw_push_message.dart' as _i18;
import 'push/dw_push_message_recipient.dart' as _i19;
import 'push/dw_push_metric_bucket.dart' as _i20;
import 'push/dw_push_recipient_state.dart' as _i21;
import 'push/dw_push_runtime_state.dart' as _i22;
import '/src/domain/api/dw_model_wrapper.dart' as _i23;
import 'package:dartway_serverpod_core_server/src/domain/api/dw_model_wrapper.dart'
    as _i24;
import 'package:dartway_serverpod_core_server/src/domain/api/dw_order_by.dart'
    as _i25;
import '/src/domain/api/dw_api_response.dart' as _i26;
import '/src/domain/api/dw_auth_data.dart' as _i27;
import '/src/domain/api/dw_backend_filter.dart' as _i28;
import '/src/domain/api/dw_order_by.dart' as _i29;
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
export 'push/dw_push_delivery.dart';
export 'push/dw_push_message.dart';
export 'push/dw_push_message_recipient.dart';
export 'push/dw_push_metric_bucket.dart';
export 'push/dw_push_recipient_state.dart';
export 'push/dw_push_runtime_state.dart';

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
      name: 'dw_push_delivery',
      dartName: 'DwPushDelivery',
      schema: 'public',
      module: 'dartway_serverpod_core',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'nextval(\'dw_push_delivery_id_seq\'::regclass)',
        ),
        _i2.ColumnDefinition(
          name: 'messageId',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'recipientId',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'availableAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _i2.ColumnDefinition(
          name: 'attemptCount',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
          columnDefault: '0',
        ),
        _i2.ColumnDefinition(
          name: 'leaseId',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'leaseExpiresAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: true,
          dartType: 'DateTime?',
        ),
        _i2.ColumnDefinition(
          name: 'lastError',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'createdAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
          columnDefault: 'CURRENT_TIMESTAMP',
        ),
      ],
      foreignKeys: [
        _i2.ForeignKeyDefinition(
          constraintName: 'dw_push_delivery_fk_0',
          columns: ['messageId'],
          referenceTable: 'dw_push_message',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _i2.ForeignKeyAction.noAction,
          onDelete: _i2.ForeignKeyAction.cascade,
          matchType: null,
        ),
      ],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'dw_push_delivery_pkey',
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
          indexName: 'dw_push_delivery_message_recipient_idx',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'messageId',
            ),
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'recipientId',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
        _i2.IndexDefinition(
          indexName: 'dw_push_delivery_claim_idx',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'availableAt',
            ),
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'leaseExpiresAt',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
        _i2.IndexDefinition(
          indexName: 'dw_push_delivery_recipient_idx',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'recipientId',
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
      name: 'dw_push_message',
      dartName: 'DwPushMessage',
      schema: 'public',
      module: 'dartway_serverpod_core',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'nextval(\'dw_push_message_id_seq\'::regclass)',
        ),
        _i2.ColumnDefinition(
          name: 'deduplicationKey',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'category',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
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
          name: 'imageUrl',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'data',
          columnType: _i2.ColumnType.json,
          isNullable: true,
          dartType: 'Map<String,String>?',
        ),
        _i2.ColumnDefinition(
          name: 'createdAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
          columnDefault: 'CURRENT_TIMESTAMP',
        ),
        _i2.ColumnDefinition(
          name: 'audienceClosedAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: true,
          dartType: 'DateTime?',
        ),
        _i2.ColumnDefinition(
          name: 'scheduledAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _i2.ColumnDefinition(
          name: 'expiresAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'dw_push_message_pkey',
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
          indexName: 'dw_push_message_deduplication_key_idx',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'deduplicationKey',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
        _i2.IndexDefinition(
          indexName: 'dw_push_message_expires_at_idx',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'expiresAt',
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
      name: 'dw_push_message_recipient',
      dartName: 'DwPushMessageRecipient',
      schema: 'public',
      module: 'dartway_serverpod_core',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault:
              'nextval(\'dw_push_message_recipient_id_seq\'::regclass)',
        ),
        _i2.ColumnDefinition(
          name: 'messageId',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'recipientId',
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
      ],
      foreignKeys: [
        _i2.ForeignKeyDefinition(
          constraintName: 'dw_push_message_recipient_fk_0',
          columns: ['messageId'],
          referenceTable: 'dw_push_message',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _i2.ForeignKeyAction.noAction,
          onDelete: _i2.ForeignKeyAction.cascade,
          matchType: null,
        ),
      ],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'dw_push_message_recipient_pkey',
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
          indexName: 'dw_push_message_recipient_unique_idx',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'messageId',
            ),
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'recipientId',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
        _i2.IndexDefinition(
          indexName: 'dw_push_message_recipient_recipient_idx',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'recipientId',
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
      name: 'dw_push_metric_bucket',
      dartName: 'DwPushMetricBucket',
      schema: 'public',
      module: 'dartway_serverpod_core',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'nextval(\'dw_push_metric_bucket_id_seq\'::regclass)',
        ),
        _i2.ColumnDefinition(
          name: 'bucketStart',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _i2.ColumnDefinition(
          name: 'category',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'outcome',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'eventCount',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
          columnDefault: '0',
        ),
        _i2.ColumnDefinition(
          name: 'updatedAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
          columnDefault: 'CURRENT_TIMESTAMP',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'dw_push_metric_bucket_pkey',
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
          indexName: 'dw_push_metric_bucket_identity_idx',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'bucketStart',
            ),
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'category',
            ),
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'outcome',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
        _i2.IndexDefinition(
          indexName: 'dw_push_metric_bucket_start_idx',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'bucketStart',
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
      name: 'dw_push_recipient_state',
      dartName: 'DwPushRecipientState',
      schema: 'public',
      module: 'dartway_serverpod_core',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault:
              'nextval(\'dw_push_recipient_state_id_seq\'::regclass)',
        ),
        _i2.ColumnDefinition(
          name: 'recipientId',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'stateKey',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'nextAllowedAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _i2.ColumnDefinition(
          name: 'metadata',
          columnType: _i2.ColumnType.json,
          isNullable: true,
          dartType: 'Map<String,String>?',
        ),
        _i2.ColumnDefinition(
          name: 'updatedAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
          columnDefault: 'CURRENT_TIMESTAMP',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'dw_push_recipient_state_pkey',
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
          indexName: 'dw_push_recipient_state_identity_idx',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'recipientId',
            ),
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'stateKey',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
        _i2.IndexDefinition(
          indexName: 'dw_push_recipient_state_next_allowed_idx',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'nextAllowedAt',
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
      name: 'dw_push_runtime_state',
      dartName: 'DwPushRuntimeState',
      schema: 'public',
      module: 'dartway_serverpod_core',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'nextval(\'dw_push_runtime_state_id_seq\'::regclass)',
        ),
        _i2.ColumnDefinition(
          name: 'workerName',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'isPaused',
          columnType: _i2.ColumnType.boolean,
          isNullable: false,
          dartType: 'bool',
          columnDefault: 'false',
        ),
        _i2.ColumnDefinition(
          name: 'pausedUntil',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: true,
          dartType: 'DateTime?',
        ),
        _i2.ColumnDefinition(
          name: 'lastClaimedAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: true,
          dartType: 'DateTime?',
        ),
        _i2.ColumnDefinition(
          name: 'lastCompletedAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: true,
          dartType: 'DateTime?',
        ),
        _i2.ColumnDefinition(
          name: 'lastErrorAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: true,
          dartType: 'DateTime?',
        ),
        _i2.ColumnDefinition(
          name: 'lastError',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'updatedAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
          columnDefault: 'CURRENT_TIMESTAMP',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'dw_push_runtime_state_pkey',
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
          indexName: 'dw_push_runtime_state_worker_name_idx',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'workerName',
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

  static String? getClassNameFromObjectJson(dynamic data) {
    if (data is! Map) return null;
    final className = data['__className__'] as String?;
    if (className == null) return null;
    if (!className.startsWith('dartway_serverpod_core.')) return className;
    return className.substring(23);
  }

  @override
  T deserialize<T>(
    dynamic data, [
    Type? t,
  ]) {
    t ??= T;

    final dataClassName = getClassNameFromObjectJson(data);
    if (dataClassName != null && dataClassName != getClassNameForType(t)) {
      try {
        return deserializeByClassName({
          'className': dataClassName,
          'data': data,
        });
      } on FormatException catch (_) {
        // If the className is not recognized (e.g., older client receiving
        // data with a new subtype), fall back to deserializing without the
        // className, using the expected type T.
      }
    }

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
    if (t == _i17.DwPushDelivery) {
      return _i17.DwPushDelivery.fromJson(data) as T;
    }
    if (t == _i18.DwPushMessage) {
      return _i18.DwPushMessage.fromJson(data) as T;
    }
    if (t == _i19.DwPushMessageRecipient) {
      return _i19.DwPushMessageRecipient.fromJson(data) as T;
    }
    if (t == _i20.DwPushMetricBucket) {
      return _i20.DwPushMetricBucket.fromJson(data) as T;
    }
    if (t == _i21.DwPushRecipientState) {
      return _i21.DwPushRecipientState.fromJson(data) as T;
    }
    if (t == _i22.DwPushRuntimeState) {
      return _i22.DwPushRuntimeState.fromJson(data) as T;
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
    if (t == _i1.getType<_i17.DwPushDelivery?>()) {
      return (data != null ? _i17.DwPushDelivery.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i18.DwPushMessage?>()) {
      return (data != null ? _i18.DwPushMessage.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i19.DwPushMessageRecipient?>()) {
      return (data != null ? _i19.DwPushMessageRecipient.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i20.DwPushMetricBucket?>()) {
      return (data != null ? _i20.DwPushMetricBucket.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i21.DwPushRecipientState?>()) {
      return (data != null ? _i21.DwPushRecipientState.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i22.DwPushRuntimeState?>()) {
      return (data != null ? _i22.DwPushRuntimeState.fromJson(data) : null)
          as T;
    }
    if (t == Map<String, String>) {
      return (data as Map).map(
            (k, v) => MapEntry(deserialize<String>(k), deserialize<String>(v)),
          )
          as T;
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
    if (t == List<_i23.DwModelWrapper>) {
      return (data as List)
              .map((e) => deserialize<_i23.DwModelWrapper>(e))
              .toList()
          as T;
    }
    if (t == _i23.DwModelWrapper) {
      return _i23.DwModelWrapper.fromJson(data) as T;
    }
    if (t == List<_i24.DwModelWrapper>) {
      return (data as List)
              .map((e) => deserialize<_i24.DwModelWrapper>(e))
              .toList()
          as T;
    }
    if (t == List<_i25.DwOrderBy>) {
      return (data as List).map((e) => deserialize<_i25.DwOrderBy>(e)).toList()
          as T;
    }
    if (t == _i1.getType<List<_i25.DwOrderBy>?>()) {
      return (data != null
              ? (data as List)
                    .map((e) => deserialize<_i25.DwOrderBy>(e))
                    .toList()
              : null)
          as T;
    }
    if (t == _i26.DwApiResponse) {
      return _i26.DwApiResponse.fromJson(data) as T;
    }
    if (t == _i27.DwAuthData) {
      return _i27.DwAuthData.fromJson(data) as T;
    }
    if (t == _i28.DwBackendFilter) {
      return _i28.DwBackendFilter.fromJson(data) as T;
    }
    if (t == _i29.DwOrderBy) {
      return _i29.DwOrderBy.fromJson(data) as T;
    }
    if (t == _i1.getType<_i23.DwModelWrapper?>()) {
      return (data != null ? _i23.DwModelWrapper.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i26.DwApiResponse?>()) {
      return (data != null ? _i26.DwApiResponse.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i27.DwAuthData?>()) {
      return (data != null ? _i27.DwAuthData.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i28.DwBackendFilter?>()) {
      return (data != null ? _i28.DwBackendFilter.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i29.DwOrderBy?>()) {
      return (data != null ? _i29.DwOrderBy.fromJson(data) : null) as T;
    }
    try {
      return _i2.Protocol().deserialize<T>(data, t);
    } on _i1.DeserializationTypeNotFoundException catch (_) {}
    return super.deserialize<T>(data, t);
  }

  static String? getClassNameForType(Type type) {
    return switch (type) {
      _i23.DwModelWrapper => 'DwModelWrapper',
      _i26.DwApiResponse => 'DwApiResponse',
      _i27.DwAuthData => 'DwAuthData',
      _i28.DwBackendFilter => 'DwBackendFilter',
      _i29.DwOrderBy => 'DwOrderBy',
      _i3.DwAuthProvider => 'DwAuthProvider',
      _i4.DwAuthRequest => 'DwAuthRequest',
      _i5.DwAuthRequestStatus => 'DwAuthRequestStatus',
      _i6.DwAuthRequestType => 'DwAuthRequestType',
      _i7.DwAuthVerification => 'DwAuthVerification',
      _i8.DwAuthVerificationType => 'DwAuthVerificationType',
      _i9.DwAuthFailReason => 'DwAuthFailReason',
      _i10.DwAuthKey => 'DwAuthKey',
      _i11.DwUserPassword => 'DwUserPassword',
      _i12.DwCloudFile => 'DwCloudFile',
      _i13.DwAppNotification => 'DwAppNotification',
      _i14.DwBackendFilterType => 'DwBackendFilterType',
      _i15.DwUpdatesTransport => 'DwUpdatesTransport',
      _i16.DwWebServerLog => 'DwWebServerLog',
      _i17.DwPushDelivery => 'DwPushDelivery',
      _i18.DwPushMessage => 'DwPushMessage',
      _i19.DwPushMessageRecipient => 'DwPushMessageRecipient',
      _i20.DwPushMetricBucket => 'DwPushMetricBucket',
      _i21.DwPushRecipientState => 'DwPushRecipientState',
      _i22.DwPushRuntimeState => 'DwPushRuntimeState',
      _ => null,
    };
  }

  @override
  String? getClassNameForObject(Object? data) {
    String? className = super.getClassNameForObject(data);
    if (className != null) return className;

    if (data is Map<String, dynamic> && data['__className__'] is String) {
      return (data['__className__'] as String).replaceFirst(
        'dartway_serverpod_core.',
        '',
      );
    }

    switch (data) {
      case _i23.DwModelWrapper():
        return 'DwModelWrapper';
      case _i26.DwApiResponse():
        return 'DwApiResponse';
      case _i27.DwAuthData():
        return 'DwAuthData';
      case _i28.DwBackendFilter():
        return 'DwBackendFilter';
      case _i29.DwOrderBy():
        return 'DwOrderBy';
      case _i3.DwAuthProvider():
        return 'DwAuthProvider';
      case _i4.DwAuthRequest():
        return 'DwAuthRequest';
      case _i5.DwAuthRequestStatus():
        return 'DwAuthRequestStatus';
      case _i6.DwAuthRequestType():
        return 'DwAuthRequestType';
      case _i7.DwAuthVerification():
        return 'DwAuthVerification';
      case _i8.DwAuthVerificationType():
        return 'DwAuthVerificationType';
      case _i9.DwAuthFailReason():
        return 'DwAuthFailReason';
      case _i10.DwAuthKey():
        return 'DwAuthKey';
      case _i11.DwUserPassword():
        return 'DwUserPassword';
      case _i12.DwCloudFile():
        return 'DwCloudFile';
      case _i13.DwAppNotification():
        return 'DwAppNotification';
      case _i14.DwBackendFilterType():
        return 'DwBackendFilterType';
      case _i15.DwUpdatesTransport():
        return 'DwUpdatesTransport';
      case _i16.DwWebServerLog():
        return 'DwWebServerLog';
      case _i17.DwPushDelivery():
        return 'DwPushDelivery';
      case _i18.DwPushMessage():
        return 'DwPushMessage';
      case _i19.DwPushMessageRecipient():
        return 'DwPushMessageRecipient';
      case _i20.DwPushMetricBucket():
        return 'DwPushMetricBucket';
      case _i21.DwPushRecipientState():
        return 'DwPushRecipientState';
      case _i22.DwPushRuntimeState():
        return 'DwPushRuntimeState';
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
      return deserialize<_i23.DwModelWrapper>(data['data']);
    }
    if (dataClassName == 'DwApiResponse') {
      return deserialize<_i26.DwApiResponse>(data['data']);
    }
    if (dataClassName == 'DwAuthData') {
      return deserialize<_i27.DwAuthData>(data['data']);
    }
    if (dataClassName == 'DwBackendFilter') {
      return deserialize<_i28.DwBackendFilter>(data['data']);
    }
    if (dataClassName == 'DwOrderBy') {
      return deserialize<_i29.DwOrderBy>(data['data']);
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
    if (dataClassName == 'DwPushDelivery') {
      return deserialize<_i17.DwPushDelivery>(data['data']);
    }
    if (dataClassName == 'DwPushMessage') {
      return deserialize<_i18.DwPushMessage>(data['data']);
    }
    if (dataClassName == 'DwPushMessageRecipient') {
      return deserialize<_i19.DwPushMessageRecipient>(data['data']);
    }
    if (dataClassName == 'DwPushMetricBucket') {
      return deserialize<_i20.DwPushMetricBucket>(data['data']);
    }
    if (dataClassName == 'DwPushRecipientState') {
      return deserialize<_i21.DwPushRecipientState>(data['data']);
    }
    if (dataClassName == 'DwPushRuntimeState') {
      return deserialize<_i22.DwPushRuntimeState>(data['data']);
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
      case _i17.DwPushDelivery:
        return _i17.DwPushDelivery.t;
      case _i18.DwPushMessage:
        return _i18.DwPushMessage.t;
      case _i19.DwPushMessageRecipient:
        return _i19.DwPushMessageRecipient.t;
      case _i20.DwPushMetricBucket:
        return _i20.DwPushMetricBucket.t;
      case _i21.DwPushRecipientState:
        return _i21.DwPushRecipientState.t;
      case _i22.DwPushRuntimeState:
        return _i22.DwPushRuntimeState.t;
    }
    return null;
  }

  @override
  List<_i2.TableDefinition> getTargetTableDefinitions() =>
      targetTableDefinitions;

  @override
  String getModuleName() => 'dartway_serverpod_core';

  /// Maps any `Record`s known to this [Protocol] to their JSON representation
  ///
  /// Throws in case the record type is not known.
  ///
  /// This method will return `null` (only) for `null` inputs.
  Map<String, dynamic>? mapRecordToJson(Record? record) {
    if (record == null) {
      return null;
    }
    try {
      return _i2.Protocol().mapRecordToJson(record);
    } catch (_) {}
    throw Exception('Unsupported record type ${record.runtimeType}');
  }
}
