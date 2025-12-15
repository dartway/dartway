/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod/serverpod.dart' as _i1;
import 'package:serverpod/protocol.dart' as _i2;
import 'dw_tinkoff_api_method.dart' as _i3;
import 'dw_tinkoff_log.dart' as _i4;
import 'dw_tinkoff_log_type.dart' as _i5;
import 'dw_tinkoff_payment.dart' as _i6;
import 'dw_tinkoff_payment_status.dart' as _i7;
import 'dw_tinkoff_registered_card.dart' as _i8;
export 'dw_tinkoff_api_method.dart';
export 'dw_tinkoff_log.dart';
export 'dw_tinkoff_log_type.dart';
export 'dw_tinkoff_payment.dart';
export 'dw_tinkoff_payment_status.dart';
export 'dw_tinkoff_registered_card.dart';

class Protocol extends _i1.SerializationManagerServer {
  Protocol._();

  factory Protocol() => _instance;

  static final Protocol _instance = Protocol._();

  static final List<_i2.TableDefinition> targetTableDefinitions = [
    _i2.TableDefinition(
      name: 'dw_tinkoff_log',
      dartName: 'DwTinkoffLog',
      schema: 'public',
      module: 'dartway_serverpod_tinkoff',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'nextval(\'dw_tinkoff_log_id_seq\'::regclass)',
        ),
        _i2.ColumnDefinition(
          name: 'timestamp',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _i2.ColumnDefinition(
          name: 'terminalKey',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'logType',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'protocol:DwTinkoffLogType',
        ),
        _i2.ColumnDefinition(
          name: 'method',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'protocol:DwTinkoffApiMethod?',
        ),
        _i2.ColumnDefinition(
          name: 'endpoint',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'paramsString',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'tinkoffCustomerId',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'paymentId',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'paymentStatus',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'isOk',
          columnType: _i2.ColumnType.boolean,
          isNullable: true,
          dartType: 'bool?',
        ),
        _i2.ColumnDefinition(
          name: 'statusCode',
          columnType: _i2.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _i2.ColumnDefinition(
          name: 'statusMessage',
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
          name: 'errorDetails',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'responseData',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'dw_tinkoff_log_pkey',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'id',
            )
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: true,
        )
      ],
      managed: true,
    ),
    _i2.TableDefinition(
      name: 'dw_tinkoff_payment',
      dartName: 'DwTinkoffPayment',
      schema: 'public',
      module: 'dartway_serverpod_tinkoff',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'nextval(\'dw_tinkoff_payment_id_seq\'::regclass)',
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
        _i2.ColumnDefinition(
          name: 'terminalKey',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'tinkoffRawStatus',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'tinkoffStatus',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'protocol:DwTinkoffPaymentStatus',
        ),
        _i2.ColumnDefinition(
          name: 'tinkoffPaymentId',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'tinkoffCustomerId',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'orderIdentifier',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'amount',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'paymentUrl',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'dw_tinkoff_payment_pkey',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'id',
            )
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: true,
        ),
        _i2.IndexDefinition(
          indexName: 'tinkoff_payment_order_idx',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'orderIdentifier',
            )
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
        _i2.IndexDefinition(
          indexName: 'tinkoff_payment_id_idx',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'tinkoffPaymentId',
            )
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
        _i2.IndexDefinition(
          indexName: 'tinkoff_payment_customer_idx',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'tinkoffCustomerId',
            )
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
        _i2.IndexDefinition(
          indexName: 'tinkoff_payment_status_idx',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'tinkoffStatus',
            )
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _i2.TableDefinition(
      name: 'dw_tinkoff_registered_card',
      dartName: 'DwTinkoffRegisteredCard',
      schema: 'public',
      module: 'dartway_serverpod_tinkoff',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault:
              'nextval(\'dw_tinkoff_registered_card_id_seq\'::regclass)',
        ),
        _i2.ColumnDefinition(
          name: 'tinkoffCustomerId',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'cardPan',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'status',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'tinkoffCardId',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'rebillId',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'dw_tinkoff_registered_card_pkey',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'id',
            )
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: true,
        ),
        _i2.IndexDefinition(
          indexName: 'tinkoff_customer_idx',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'tinkoffCustomerId',
            )
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
        _i2.IndexDefinition(
          indexName: 'card_pan_idx',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'cardPan',
            )
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
        _i2.IndexDefinition(
          indexName: 'tinkoff_card_id_idx',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'tinkoffCardId',
            )
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
  ];

  @override
  T deserialize<T>(
    dynamic data, [
    Type? t,
  ]) {
    t ??= T;
    if (t == _i3.DwTinkoffApiMethod) {
      return _i3.DwTinkoffApiMethod.fromJson(data) as T;
    }
    if (t == _i4.DwTinkoffLog) {
      return _i4.DwTinkoffLog.fromJson(data) as T;
    }
    if (t == _i5.DwTinkoffLogType) {
      return _i5.DwTinkoffLogType.fromJson(data) as T;
    }
    if (t == _i6.DwTinkoffPayment) {
      return _i6.DwTinkoffPayment.fromJson(data) as T;
    }
    if (t == _i7.DwTinkoffPaymentStatus) {
      return _i7.DwTinkoffPaymentStatus.fromJson(data) as T;
    }
    if (t == _i8.DwTinkoffRegisteredCard) {
      return _i8.DwTinkoffRegisteredCard.fromJson(data) as T;
    }
    if (t == _i1.getType<_i3.DwTinkoffApiMethod?>()) {
      return (data != null ? _i3.DwTinkoffApiMethod.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i4.DwTinkoffLog?>()) {
      return (data != null ? _i4.DwTinkoffLog.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i5.DwTinkoffLogType?>()) {
      return (data != null ? _i5.DwTinkoffLogType.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i6.DwTinkoffPayment?>()) {
      return (data != null ? _i6.DwTinkoffPayment.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i7.DwTinkoffPaymentStatus?>()) {
      return (data != null ? _i7.DwTinkoffPaymentStatus.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i8.DwTinkoffRegisteredCard?>()) {
      return (data != null ? _i8.DwTinkoffRegisteredCard.fromJson(data) : null)
          as T;
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
    if (data is _i3.DwTinkoffApiMethod) {
      return 'DwTinkoffApiMethod';
    }
    if (data is _i4.DwTinkoffLog) {
      return 'DwTinkoffLog';
    }
    if (data is _i5.DwTinkoffLogType) {
      return 'DwTinkoffLogType';
    }
    if (data is _i6.DwTinkoffPayment) {
      return 'DwTinkoffPayment';
    }
    if (data is _i7.DwTinkoffPaymentStatus) {
      return 'DwTinkoffPaymentStatus';
    }
    if (data is _i8.DwTinkoffRegisteredCard) {
      return 'DwTinkoffRegisteredCard';
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
    if (dataClassName == 'DwTinkoffApiMethod') {
      return deserialize<_i3.DwTinkoffApiMethod>(data['data']);
    }
    if (dataClassName == 'DwTinkoffLog') {
      return deserialize<_i4.DwTinkoffLog>(data['data']);
    }
    if (dataClassName == 'DwTinkoffLogType') {
      return deserialize<_i5.DwTinkoffLogType>(data['data']);
    }
    if (dataClassName == 'DwTinkoffPayment') {
      return deserialize<_i6.DwTinkoffPayment>(data['data']);
    }
    if (dataClassName == 'DwTinkoffPaymentStatus') {
      return deserialize<_i7.DwTinkoffPaymentStatus>(data['data']);
    }
    if (dataClassName == 'DwTinkoffRegisteredCard') {
      return deserialize<_i8.DwTinkoffRegisteredCard>(data['data']);
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
      case _i4.DwTinkoffLog:
        return _i4.DwTinkoffLog.t;
      case _i6.DwTinkoffPayment:
        return _i6.DwTinkoffPayment.t;
      case _i8.DwTinkoffRegisteredCard:
        return _i8.DwTinkoffRegisteredCard.t;
    }
    return null;
  }

  @override
  List<_i2.TableDefinition> getTargetTableDefinitions() =>
      targetTableDefinitions;

  @override
  String getModuleName() => 'dartway_serverpod_tinkoff';
}
