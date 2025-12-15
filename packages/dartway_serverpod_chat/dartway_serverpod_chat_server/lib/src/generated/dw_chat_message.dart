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
import 'dw_chat_custom_message_type.dart' as _i2;

abstract class DwChatMessage
    implements _i1.TableRow<int?>, _i1.ProtocolSerialization {
  DwChatMessage._({
    this.id,
    required this.userId,
    required this.chatChannelId,
    required this.sentAt,
    this.text,
    this.attachmentIds,
    this.customMessageType,
    this.replyMessageId,
    bool? isDeleted,
  }) : isDeleted = isDeleted ?? false;

  factory DwChatMessage({
    int? id,
    required int userId,
    required int chatChannelId,
    required DateTime sentAt,
    String? text,
    List<int>? attachmentIds,
    _i2.DwChatCustomMessageType? customMessageType,
    int? replyMessageId,
    bool? isDeleted,
  }) = _DwChatMessageImpl;

  factory DwChatMessage.fromJson(Map<String, dynamic> jsonSerialization) {
    return DwChatMessage(
      id: jsonSerialization['id'] as int?,
      userId: jsonSerialization['userId'] as int,
      chatChannelId: jsonSerialization['chatChannelId'] as int,
      sentAt: _i1.DateTimeJsonExtension.fromJson(jsonSerialization['sentAt']),
      text: jsonSerialization['text'] as String?,
      attachmentIds: (jsonSerialization['attachmentIds'] as List?)
          ?.map((e) => e as int)
          .toList(),
      customMessageType: jsonSerialization['customMessageType'] == null
          ? null
          : _i2.DwChatCustomMessageType.fromJson(
              (jsonSerialization['customMessageType'] as Map<String, dynamic>)),
      replyMessageId: jsonSerialization['replyMessageId'] as int?,
      isDeleted: jsonSerialization['isDeleted'] as bool,
    );
  }

  static final t = DwChatMessageTable();

  static const db = DwChatMessageRepository._();

  @override
  int? id;

  int userId;

  int chatChannelId;

  DateTime sentAt;

  String? text;

  List<int>? attachmentIds;

  _i2.DwChatCustomMessageType? customMessageType;

  int? replyMessageId;

  bool isDeleted;

  @override
  _i1.Table<int?> get table => t;

  /// Returns a shallow copy of this [DwChatMessage]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  DwChatMessage copyWith({
    int? id,
    int? userId,
    int? chatChannelId,
    DateTime? sentAt,
    String? text,
    List<int>? attachmentIds,
    _i2.DwChatCustomMessageType? customMessageType,
    int? replyMessageId,
    bool? isDeleted,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'userId': userId,
      'chatChannelId': chatChannelId,
      'sentAt': sentAt.toJson(),
      if (text != null) 'text': text,
      if (attachmentIds != null) 'attachmentIds': attachmentIds?.toJson(),
      if (customMessageType != null)
        'customMessageType': customMessageType?.toJson(),
      if (replyMessageId != null) 'replyMessageId': replyMessageId,
      'isDeleted': isDeleted,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      if (id != null) 'id': id,
      'userId': userId,
      'chatChannelId': chatChannelId,
      'sentAt': sentAt.toJson(),
      if (text != null) 'text': text,
      if (attachmentIds != null) 'attachmentIds': attachmentIds?.toJson(),
      if (customMessageType != null)
        'customMessageType': customMessageType?.toJsonForProtocol(),
      if (replyMessageId != null) 'replyMessageId': replyMessageId,
      'isDeleted': isDeleted,
    };
  }

  static DwChatMessageInclude include() {
    return DwChatMessageInclude._();
  }

  static DwChatMessageIncludeList includeList({
    _i1.WhereExpressionBuilder<DwChatMessageTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<DwChatMessageTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<DwChatMessageTable>? orderByList,
    DwChatMessageInclude? include,
  }) {
    return DwChatMessageIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(DwChatMessage.t),
      orderDescending: orderDescending,
      orderByList: orderByList?.call(DwChatMessage.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _DwChatMessageImpl extends DwChatMessage {
  _DwChatMessageImpl({
    int? id,
    required int userId,
    required int chatChannelId,
    required DateTime sentAt,
    String? text,
    List<int>? attachmentIds,
    _i2.DwChatCustomMessageType? customMessageType,
    int? replyMessageId,
    bool? isDeleted,
  }) : super._(
          id: id,
          userId: userId,
          chatChannelId: chatChannelId,
          sentAt: sentAt,
          text: text,
          attachmentIds: attachmentIds,
          customMessageType: customMessageType,
          replyMessageId: replyMessageId,
          isDeleted: isDeleted,
        );

  /// Returns a shallow copy of this [DwChatMessage]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  DwChatMessage copyWith({
    Object? id = _Undefined,
    int? userId,
    int? chatChannelId,
    DateTime? sentAt,
    Object? text = _Undefined,
    Object? attachmentIds = _Undefined,
    Object? customMessageType = _Undefined,
    Object? replyMessageId = _Undefined,
    bool? isDeleted,
  }) {
    return DwChatMessage(
      id: id is int? ? id : this.id,
      userId: userId ?? this.userId,
      chatChannelId: chatChannelId ?? this.chatChannelId,
      sentAt: sentAt ?? this.sentAt,
      text: text is String? ? text : this.text,
      attachmentIds: attachmentIds is List<int>?
          ? attachmentIds
          : this.attachmentIds?.map((e0) => e0).toList(),
      customMessageType: customMessageType is _i2.DwChatCustomMessageType?
          ? customMessageType
          : this.customMessageType?.copyWith(),
      replyMessageId:
          replyMessageId is int? ? replyMessageId : this.replyMessageId,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}

class DwChatMessageTable extends _i1.Table<int?> {
  DwChatMessageTable({super.tableRelation})
      : super(tableName: 'dw_chat_message') {
    userId = _i1.ColumnInt(
      'userId',
      this,
    );
    chatChannelId = _i1.ColumnInt(
      'chatChannelId',
      this,
    );
    sentAt = _i1.ColumnDateTime(
      'sentAt',
      this,
    );
    text = _i1.ColumnString(
      'text',
      this,
    );
    attachmentIds = _i1.ColumnSerializable(
      'attachmentIds',
      this,
    );
    customMessageType = _i1.ColumnSerializable(
      'customMessageType',
      this,
    );
    replyMessageId = _i1.ColumnInt(
      'replyMessageId',
      this,
    );
    isDeleted = _i1.ColumnBool(
      'isDeleted',
      this,
      hasDefault: true,
    );
  }

  late final _i1.ColumnInt userId;

  late final _i1.ColumnInt chatChannelId;

  late final _i1.ColumnDateTime sentAt;

  late final _i1.ColumnString text;

  late final _i1.ColumnSerializable attachmentIds;

  late final _i1.ColumnSerializable customMessageType;

  late final _i1.ColumnInt replyMessageId;

  late final _i1.ColumnBool isDeleted;

  @override
  List<_i1.Column> get columns => [
        id,
        userId,
        chatChannelId,
        sentAt,
        text,
        attachmentIds,
        customMessageType,
        replyMessageId,
        isDeleted,
      ];
}

class DwChatMessageInclude extends _i1.IncludeObject {
  DwChatMessageInclude._();

  @override
  Map<String, _i1.Include?> get includes => {};

  @override
  _i1.Table<int?> get table => DwChatMessage.t;
}

class DwChatMessageIncludeList extends _i1.IncludeList {
  DwChatMessageIncludeList._({
    _i1.WhereExpressionBuilder<DwChatMessageTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(DwChatMessage.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<int?> get table => DwChatMessage.t;
}

class DwChatMessageRepository {
  const DwChatMessageRepository._();

  /// Returns a list of [DwChatMessage]s matching the given query parameters.
  ///
  /// Use [where] to specify which items to include in the return value.
  /// If none is specified, all items will be returned.
  ///
  /// To specify the order of the items use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// The maximum number of items can be set by [limit]. If no limit is set,
  /// all items matching the query will be returned.
  ///
  /// [offset] defines how many items to skip, after which [limit] (or all)
  /// items are read from the database.
  ///
  /// ```dart
  /// var persons = await Persons.db.find(
  ///   session,
  ///   where: (t) => t.lastName.equals('Jones'),
  ///   orderBy: (t) => t.firstName,
  ///   limit: 100,
  /// );
  /// ```
  Future<List<DwChatMessage>> find(
    _i1.Session session, {
    _i1.WhereExpressionBuilder<DwChatMessageTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<DwChatMessageTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<DwChatMessageTable>? orderByList,
    _i1.Transaction? transaction,
  }) async {
    return session.db.find<DwChatMessage>(
      where: where?.call(DwChatMessage.t),
      orderBy: orderBy?.call(DwChatMessage.t),
      orderByList: orderByList?.call(DwChatMessage.t),
      orderDescending: orderDescending,
      limit: limit,
      offset: offset,
      transaction: transaction,
    );
  }

  /// Returns the first matching [DwChatMessage] matching the given query parameters.
  ///
  /// Use [where] to specify which items to include in the return value.
  /// If none is specified, all items will be returned.
  ///
  /// To specify the order use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// [offset] defines how many items to skip, after which the next one will be picked.
  ///
  /// ```dart
  /// var youngestPerson = await Persons.db.findFirstRow(
  ///   session,
  ///   where: (t) => t.lastName.equals('Jones'),
  ///   orderBy: (t) => t.age,
  /// );
  /// ```
  Future<DwChatMessage?> findFirstRow(
    _i1.Session session, {
    _i1.WhereExpressionBuilder<DwChatMessageTable>? where,
    int? offset,
    _i1.OrderByBuilder<DwChatMessageTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<DwChatMessageTable>? orderByList,
    _i1.Transaction? transaction,
  }) async {
    return session.db.findFirstRow<DwChatMessage>(
      where: where?.call(DwChatMessage.t),
      orderBy: orderBy?.call(DwChatMessage.t),
      orderByList: orderByList?.call(DwChatMessage.t),
      orderDescending: orderDescending,
      offset: offset,
      transaction: transaction,
    );
  }

  /// Finds a single [DwChatMessage] by its [id] or null if no such row exists.
  Future<DwChatMessage?> findById(
    _i1.Session session,
    int id, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.findById<DwChatMessage>(
      id,
      transaction: transaction,
    );
  }

  /// Inserts all [DwChatMessage]s in the list and returns the inserted rows.
  ///
  /// The returned [DwChatMessage]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  Future<List<DwChatMessage>> insert(
    _i1.Session session,
    List<DwChatMessage> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insert<DwChatMessage>(
      rows,
      transaction: transaction,
    );
  }

  /// Inserts a single [DwChatMessage] and returns the inserted row.
  ///
  /// The returned [DwChatMessage] will have its `id` field set.
  Future<DwChatMessage> insertRow(
    _i1.Session session,
    DwChatMessage row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<DwChatMessage>(
      row,
      transaction: transaction,
    );
  }

  /// Updates all [DwChatMessage]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  Future<List<DwChatMessage>> update(
    _i1.Session session,
    List<DwChatMessage> rows, {
    _i1.ColumnSelections<DwChatMessageTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.update<DwChatMessage>(
      rows,
      columns: columns?.call(DwChatMessage.t),
      transaction: transaction,
    );
  }

  /// Updates a single [DwChatMessage]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<DwChatMessage> updateRow(
    _i1.Session session,
    DwChatMessage row, {
    _i1.ColumnSelections<DwChatMessageTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<DwChatMessage>(
      row,
      columns: columns?.call(DwChatMessage.t),
      transaction: transaction,
    );
  }

  /// Deletes all [DwChatMessage]s in the list and returns the deleted rows.
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  Future<List<DwChatMessage>> delete(
    _i1.Session session,
    List<DwChatMessage> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<DwChatMessage>(
      rows,
      transaction: transaction,
    );
  }

  /// Deletes a single [DwChatMessage].
  Future<DwChatMessage> deleteRow(
    _i1.Session session,
    DwChatMessage row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<DwChatMessage>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  Future<List<DwChatMessage>> deleteWhere(
    _i1.Session session, {
    required _i1.WhereExpressionBuilder<DwChatMessageTable> where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteWhere<DwChatMessage>(
      where: where(DwChatMessage.t),
      transaction: transaction,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.Session session, {
    _i1.WhereExpressionBuilder<DwChatMessageTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<DwChatMessage>(
      where: where?.call(DwChatMessage.t),
      limit: limit,
      transaction: transaction,
    );
  }
}
