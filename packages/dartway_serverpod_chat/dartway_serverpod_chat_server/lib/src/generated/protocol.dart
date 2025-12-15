/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters

import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart'
    as _i3;
import 'package:serverpod/protocol.dart' as _i2;
// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod/serverpod.dart' as _i1;

import 'dw_chat_channel.dart' as _i4;
import 'dw_chat_custom_message_type.dart' as _i5;
import 'dw_chat_initial_data.dart' as _i6;
import 'dw_chat_message.dart' as _i7;
import 'dw_chat_participant.dart' as _i8;
import 'dw_chat_read_message_event.dart' as _i9;
import 'dw_chat_typing_message_event.dart' as _i10;

export 'dw_chat_channel.dart';
export 'dw_chat_custom_message_type.dart';
export 'dw_chat_initial_data.dart';
export 'dw_chat_message.dart';
export 'dw_chat_participant.dart';
export 'dw_chat_read_message_event.dart';
export 'dw_chat_typing_message_event.dart';

class Protocol extends _i1.SerializationManagerServer {
  Protocol._();

  factory Protocol() => _instance;

  static final Protocol _instance = Protocol._();

  static final List<_i2.TableDefinition> targetTableDefinitions = [
    _i2.TableDefinition(
      name: 'dw_chat_channel',
      dartName: 'DwChatChannel',
      schema: 'public',
      module: 'dartway_serverpod_chat',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'nextval(\'dw_chat_channel_id_seq\'::regclass)',
        ),
        _i2.ColumnDefinition(
          name: 'channel',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'dw_chat_channel_pkey',
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
          indexName: 'channel_name_idx',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'channel',
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
      name: 'dw_chat_message',
      dartName: 'DwChatMessage',
      schema: 'public',
      module: 'dartway_serverpod_chat',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'nextval(\'dw_chat_message_id_seq\'::regclass)',
        ),
        _i2.ColumnDefinition(
          name: 'userId',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'chatChannelId',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'sentAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _i2.ColumnDefinition(
          name: 'text',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'attachmentIds',
          columnType: _i2.ColumnType.json,
          isNullable: true,
          dartType: 'List<int>?',
        ),
        _i2.ColumnDefinition(
          name: 'customMessageType',
          columnType: _i2.ColumnType.json,
          isNullable: true,
          dartType: 'protocol:DwChatCustomMessageType?',
        ),
        _i2.ColumnDefinition(
          name: 'replyMessageId',
          columnType: _i2.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _i2.ColumnDefinition(
          name: 'isDeleted',
          columnType: _i2.ColumnType.boolean,
          isNullable: false,
          dartType: 'bool',
          columnDefault: 'false',
        ),
      ],
      foreignKeys: [
        _i2.ForeignKeyDefinition(
          constraintName: 'dw_chat_message_fk_0',
          columns: ['chatChannelId'],
          referenceTable: 'dw_chat_channel',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _i2.ForeignKeyAction.noAction,
          onDelete: _i2.ForeignKeyAction.cascade,
          matchType: null,
        ),
      ],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'dw_chat_message_pkey',
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
      name: 'dw_chat_participant',
      dartName: 'DwChatParticipant',
      schema: 'public',
      module: 'dartway_serverpod_chat',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'nextval(\'dw_chat_participant_id_seq\'::regclass)',
        ),
        _i2.ColumnDefinition(
          name: 'userId',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'chatChannelId',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'lastMessageId',
          columnType: _i2.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _i2.ColumnDefinition(
          name: 'lastMessageSentAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: true,
          dartType: 'DateTime?',
        ),
        _i2.ColumnDefinition(
          name: 'unreadCount',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
          columnDefault: '0',
        ),
        _i2.ColumnDefinition(
          name: 'lastReadMessageId',
          columnType: _i2.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _i2.ColumnDefinition(
          name: 'isDeleted',
          columnType: _i2.ColumnType.boolean,
          isNullable: false,
          dartType: 'bool',
          columnDefault: 'false',
        ),
      ],
      foreignKeys: [
        _i2.ForeignKeyDefinition(
          constraintName: 'dw_chat_participant_fk_0',
          columns: ['chatChannelId'],
          referenceTable: 'dw_chat_channel',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _i2.ForeignKeyAction.noAction,
          onDelete: _i2.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _i2.ForeignKeyDefinition(
          constraintName: 'dw_chat_participant_fk_1',
          columns: ['lastMessageId'],
          referenceTable: 'dw_chat_message',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _i2.ForeignKeyAction.noAction,
          onDelete: _i2.ForeignKeyAction.noAction,
          matchType: null,
        ),
        _i2.ForeignKeyDefinition(
          constraintName: 'dw_chat_participant_fk_2',
          columns: ['lastReadMessageId'],
          referenceTable: 'dw_chat_message',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _i2.ForeignKeyAction.noAction,
          onDelete: _i2.ForeignKeyAction.noAction,
          matchType: null,
        ),
      ],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'dw_chat_participant_pkey',
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
          indexName: 'dw_chat_participants_idx',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'userId',
            ),
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'chatChannelId',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    ..._i3.Protocol.targetTableDefinitions,
  ];

  @override
  T deserialize<T>(dynamic data, [Type? t]) {
    t ??= T;
    if (t == _i4.DwChatChannel) {
      return _i4.DwChatChannel.fromJson(data) as T;
    }
    if (t == _i5.DwChatCustomMessageType) {
      return _i5.DwChatCustomMessageType.fromJson(data) as T;
    }
    if (t == _i6.DwChatInitialData) {
      return _i6.DwChatInitialData.fromJson(data) as T;
    }
    if (t == _i7.DwChatMessage) {
      return _i7.DwChatMessage.fromJson(data) as T;
    }
    if (t == _i8.DwChatParticipant) {
      return _i8.DwChatParticipant.fromJson(data) as T;
    }
    if (t == _i9.DwChatReadMessageEvent) {
      return _i9.DwChatReadMessageEvent.fromJson(data) as T;
    }
    if (t == _i10.DwChatTypingMessageEvent) {
      return _i10.DwChatTypingMessageEvent.fromJson(data) as T;
    }
    if (t == _i1.getType<_i4.DwChatChannel?>()) {
      return (data != null ? _i4.DwChatChannel.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i5.DwChatCustomMessageType?>()) {
      return (data != null ? _i5.DwChatCustomMessageType.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i6.DwChatInitialData?>()) {
      return (data != null ? _i6.DwChatInitialData.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i7.DwChatMessage?>()) {
      return (data != null ? _i7.DwChatMessage.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i8.DwChatParticipant?>()) {
      return (data != null ? _i8.DwChatParticipant.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i9.DwChatReadMessageEvent?>()) {
      return (data != null ? _i9.DwChatReadMessageEvent.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i10.DwChatTypingMessageEvent?>()) {
      return (data != null
              ? _i10.DwChatTypingMessageEvent.fromJson(data)
              : null)
          as T;
    }
    if (t == _i1.getType<List<_i8.DwChatParticipant>?>()) {
      return (data != null
              ? (data as List)
                  .map((e) => deserialize<_i8.DwChatParticipant>(e))
                  .toList()
              : null)
          as T;
    }
    if (t == List<_i7.DwChatMessage>) {
      return (data as List)
              .map((e) => deserialize<_i7.DwChatMessage>(e))
              .toList()
          as T;
    }
    if (t == List<int>) {
      return (data as List).map((e) => deserialize<int>(e)).toList() as T;
    }
    if (t == _i1.getType<List<int>?>()) {
      return (data != null
              ? (data as List).map((e) => deserialize<int>(e)).toList()
              : null)
          as T;
    }
    if (t == List<int>) {
      return (data as List).map((e) => deserialize<int>(e)).toList() as T;
    }
    try {
      return _i3.Protocol().deserialize<T>(data, t);
    } on _i1.DeserializationTypeNotFoundException catch (_) {}
    try {
      return _i2.Protocol().deserialize<T>(data, t);
    } on _i1.DeserializationTypeNotFoundException catch (_) {}
    return super.deserialize<T>(data, t);
  }

  @override
  String? getClassNameForObject(Object? data) {
    String? className = super.getClassNameForObject(data);
    if (className != null) return className;
    if (data is _i4.DwChatChannel) {
      return 'DwChatChannel';
    }
    if (data is _i5.DwChatCustomMessageType) {
      return 'DwChatCustomMessageType';
    }
    if (data is _i6.DwChatInitialData) {
      return 'DwChatInitialData';
    }
    if (data is _i7.DwChatMessage) {
      return 'DwChatMessage';
    }
    if (data is _i8.DwChatParticipant) {
      return 'DwChatParticipant';
    }
    if (data is _i9.DwChatReadMessageEvent) {
      return 'DwChatReadMessageEvent';
    }
    if (data is _i10.DwChatTypingMessageEvent) {
      return 'DwChatTypingMessageEvent';
    }
    className = _i2.Protocol().getClassNameForObject(data);
    if (className != null) {
      return 'serverpod.$className';
    }
    className = _i3.Protocol().getClassNameForObject(data);
    if (className != null) {
      return 'dartway_serverpod_core.$className';
    }
    return null;
  }

  @override
  dynamic deserializeByClassName(Map<String, dynamic> data) {
    var dataClassName = data['className'];
    if (dataClassName is! String) {
      return super.deserializeByClassName(data);
    }
    if (dataClassName == 'DwChatChannel') {
      return deserialize<_i4.DwChatChannel>(data['data']);
    }
    if (dataClassName == 'DwChatCustomMessageType') {
      return deserialize<_i5.DwChatCustomMessageType>(data['data']);
    }
    if (dataClassName == 'DwChatInitialData') {
      return deserialize<_i6.DwChatInitialData>(data['data']);
    }
    if (dataClassName == 'DwChatMessage') {
      return deserialize<_i7.DwChatMessage>(data['data']);
    }
    if (dataClassName == 'DwChatParticipant') {
      return deserialize<_i8.DwChatParticipant>(data['data']);
    }
    if (dataClassName == 'DwChatReadMessageEvent') {
      return deserialize<_i9.DwChatReadMessageEvent>(data['data']);
    }
    if (dataClassName == 'DwChatTypingMessageEvent') {
      return deserialize<_i10.DwChatTypingMessageEvent>(data['data']);
    }
    if (dataClassName.startsWith('serverpod.')) {
      data['className'] = dataClassName.substring(10);
      return _i2.Protocol().deserializeByClassName(data);
    }
    if (dataClassName.startsWith('dartway_serverpod_core.')) {
      data['className'] = dataClassName.substring(23);
      return _i3.Protocol().deserializeByClassName(data);
    }
    return super.deserializeByClassName(data);
  }

  @override
  _i1.Table? getTableForType(Type t) {
    {
      var table = _i3.Protocol().getTableForType(t);
      if (table != null) {
        return table;
      }
    }
    {
      var table = _i2.Protocol().getTableForType(t);
      if (table != null) {
        return table;
      }
    }
    switch (t) {
      case _i4.DwChatChannel:
        return _i4.DwChatChannel.t;
      case _i7.DwChatMessage:
        return _i7.DwChatMessage.t;
      case _i8.DwChatParticipant:
        return _i8.DwChatParticipant.t;
    }
    return null;
  }

  @override
  List<_i2.TableDefinition> getTargetTableDefinitions() =>
      targetTableDefinitions;

  @override
  String getModuleName() => 'dartway_serverpod_chat';
}
