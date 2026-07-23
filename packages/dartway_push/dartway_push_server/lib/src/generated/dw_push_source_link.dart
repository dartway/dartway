/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member
// ignore_for_file: unnecessary_null_comparison

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod/serverpod.dart' as _i1;
import 'dw_push_message.dart' as _i2;
import 'package:dartway_push_server/src/generated/protocol.dart' as _i3;

/// Maps an arbitrary business source (sourceType, sourceId) to a queued
/// DwPushMessage, so the app can cancel the message when its source disappears
/// (e.g. a post is deleted before its notification is sent). A message payload
/// is immutable and may aggregate several sources. Server-only.
abstract class DwPushSourceLink
    implements _i1.TableRow<int?>, _i1.ProtocolSerialization {
  DwPushSourceLink._({
    this.id,
    required this.sourceType,
    required this.sourceId,
    required this.messageId,
    this.message,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory DwPushSourceLink({
    int? id,
    required String sourceType,
    required String sourceId,
    required int messageId,
    _i2.DwPushMessage? message,
    DateTime? createdAt,
  }) = _DwPushSourceLinkImpl;

  factory DwPushSourceLink.fromJson(Map<String, dynamic> jsonSerialization) {
    return DwPushSourceLink(
      id: jsonSerialization['id'] as int?,
      sourceType: jsonSerialization['sourceType'] as String,
      sourceId: jsonSerialization['sourceId'] as String,
      messageId: jsonSerialization['messageId'] as int,
      message: jsonSerialization['message'] == null
          ? null
          : _i3.Protocol().deserialize<_i2.DwPushMessage>(
              jsonSerialization['message'],
            ),
      createdAt: jsonSerialization['createdAt'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(jsonSerialization['createdAt']),
    );
  }

  static final t = DwPushSourceLinkTable();

  static const db = DwPushSourceLinkRepository._();

  @override
  int? id;

  String sourceType;

  String sourceId;

  int messageId;

  _i2.DwPushMessage? message;

  DateTime createdAt;

  @override
  _i1.Table<int?> get table => t;

  /// Returns a shallow copy of this [DwPushSourceLink]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  DwPushSourceLink copyWith({
    int? id,
    String? sourceType,
    String? sourceId,
    int? messageId,
    _i2.DwPushMessage? message,
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'dartway_push.DwPushSourceLink',
      if (id != null) 'id': id,
      'sourceType': sourceType,
      'sourceId': sourceId,
      'messageId': messageId,
      if (message != null) 'message': message?.toJson(),
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static DwPushSourceLinkInclude include({_i2.DwPushMessageInclude? message}) {
    return DwPushSourceLinkInclude._(message: message);
  }

  static DwPushSourceLinkIncludeList includeList({
    _i1.WhereExpressionBuilder<DwPushSourceLinkTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<DwPushSourceLinkTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<DwPushSourceLinkTable>? orderByList,
    DwPushSourceLinkInclude? include,
  }) {
    return DwPushSourceLinkIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(DwPushSourceLink.t),
      orderDescending: orderDescending,
      orderByList: orderByList?.call(DwPushSourceLink.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _DwPushSourceLinkImpl extends DwPushSourceLink {
  _DwPushSourceLinkImpl({
    int? id,
    required String sourceType,
    required String sourceId,
    required int messageId,
    _i2.DwPushMessage? message,
    DateTime? createdAt,
  }) : super._(
         id: id,
         sourceType: sourceType,
         sourceId: sourceId,
         messageId: messageId,
         message: message,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [DwPushSourceLink]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  DwPushSourceLink copyWith({
    Object? id = _Undefined,
    String? sourceType,
    String? sourceId,
    int? messageId,
    Object? message = _Undefined,
    DateTime? createdAt,
  }) {
    return DwPushSourceLink(
      id: id is int? ? id : this.id,
      sourceType: sourceType ?? this.sourceType,
      sourceId: sourceId ?? this.sourceId,
      messageId: messageId ?? this.messageId,
      message: message is _i2.DwPushMessage?
          ? message
          : this.message?.copyWith(),
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class DwPushSourceLinkUpdateTable
    extends _i1.UpdateTable<DwPushSourceLinkTable> {
  DwPushSourceLinkUpdateTable(super.table);

  _i1.ColumnValue<String, String> sourceType(String value) => _i1.ColumnValue(
    table.sourceType,
    value,
  );

  _i1.ColumnValue<String, String> sourceId(String value) => _i1.ColumnValue(
    table.sourceId,
    value,
  );

  _i1.ColumnValue<int, int> messageId(int value) => _i1.ColumnValue(
    table.messageId,
    value,
  );

  _i1.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _i1.ColumnValue(
        table.createdAt,
        value,
      );
}

class DwPushSourceLinkTable extends _i1.Table<int?> {
  DwPushSourceLinkTable({super.tableRelation})
    : super(tableName: 'dw_push_source_link') {
    updateTable = DwPushSourceLinkUpdateTable(this);
    sourceType = _i1.ColumnString(
      'sourceType',
      this,
    );
    sourceId = _i1.ColumnString(
      'sourceId',
      this,
    );
    messageId = _i1.ColumnInt(
      'messageId',
      this,
    );
    createdAt = _i1.ColumnDateTime(
      'createdAt',
      this,
      hasDefault: true,
    );
  }

  late final DwPushSourceLinkUpdateTable updateTable;

  late final _i1.ColumnString sourceType;

  late final _i1.ColumnString sourceId;

  late final _i1.ColumnInt messageId;

  _i2.DwPushMessageTable? _message;

  late final _i1.ColumnDateTime createdAt;

  _i2.DwPushMessageTable get message {
    if (_message != null) return _message!;
    _message = _i1.createRelationTable(
      relationFieldName: 'message',
      field: DwPushSourceLink.t.messageId,
      foreignField: _i2.DwPushMessage.t.id,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _i2.DwPushMessageTable(tableRelation: foreignTableRelation),
    );
    return _message!;
  }

  @override
  List<_i1.Column> get columns => [
    id,
    sourceType,
    sourceId,
    messageId,
    createdAt,
  ];

  @override
  _i1.Table? getRelationTable(String relationField) {
    if (relationField == 'message') {
      return message;
    }
    return null;
  }
}

class DwPushSourceLinkInclude extends _i1.IncludeObject {
  DwPushSourceLinkInclude._({_i2.DwPushMessageInclude? message}) {
    _message = message;
  }

  _i2.DwPushMessageInclude? _message;

  @override
  Map<String, _i1.Include?> get includes => {'message': _message};

  @override
  _i1.Table<int?> get table => DwPushSourceLink.t;
}

class DwPushSourceLinkIncludeList extends _i1.IncludeList {
  DwPushSourceLinkIncludeList._({
    _i1.WhereExpressionBuilder<DwPushSourceLinkTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(DwPushSourceLink.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<int?> get table => DwPushSourceLink.t;
}

class DwPushSourceLinkRepository {
  const DwPushSourceLinkRepository._();

  final attachRow = const DwPushSourceLinkAttachRowRepository._();

  /// Returns a list of [DwPushSourceLink]s matching the given query parameters.
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
  Future<List<DwPushSourceLink>> find(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<DwPushSourceLinkTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<DwPushSourceLinkTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<DwPushSourceLinkTable>? orderByList,
    _i1.Transaction? transaction,
    DwPushSourceLinkInclude? include,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<DwPushSourceLink>(
      where: where?.call(DwPushSourceLink.t),
      orderBy: orderBy?.call(DwPushSourceLink.t),
      orderByList: orderByList?.call(DwPushSourceLink.t),
      orderDescending: orderDescending,
      limit: limit,
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [DwPushSourceLink] matching the given query parameters.
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
  Future<DwPushSourceLink?> findFirstRow(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<DwPushSourceLinkTable>? where,
    int? offset,
    _i1.OrderByBuilder<DwPushSourceLinkTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<DwPushSourceLinkTable>? orderByList,
    _i1.Transaction? transaction,
    DwPushSourceLinkInclude? include,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<DwPushSourceLink>(
      where: where?.call(DwPushSourceLink.t),
      orderBy: orderBy?.call(DwPushSourceLink.t),
      orderByList: orderByList?.call(DwPushSourceLink.t),
      orderDescending: orderDescending,
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [DwPushSourceLink] by its [id] or null if no such row exists.
  Future<DwPushSourceLink?> findById(
    _i1.DatabaseSession session,
    int id, {
    _i1.Transaction? transaction,
    DwPushSourceLinkInclude? include,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<DwPushSourceLink>(
      id,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [DwPushSourceLink]s in the list and returns the inserted rows.
  ///
  /// The returned [DwPushSourceLink]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  ///
  /// If [ignoreConflicts] is set to `true`, rows that conflict with existing
  /// rows are silently skipped, and only the successfully inserted rows are
  /// returned.
  Future<List<DwPushSourceLink>> insert(
    _i1.DatabaseSession session,
    List<DwPushSourceLink> rows, {
    _i1.Transaction? transaction,
    bool ignoreConflicts = false,
  }) async {
    return session.db.insert<DwPushSourceLink>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
    );
  }

  /// Inserts a single [DwPushSourceLink] and returns the inserted row.
  ///
  /// The returned [DwPushSourceLink] will have its `id` field set.
  Future<DwPushSourceLink> insertRow(
    _i1.DatabaseSession session,
    DwPushSourceLink row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<DwPushSourceLink>(
      row,
      transaction: transaction,
    );
  }

  /// Updates all [DwPushSourceLink]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  Future<List<DwPushSourceLink>> update(
    _i1.DatabaseSession session,
    List<DwPushSourceLink> rows, {
    _i1.ColumnSelections<DwPushSourceLinkTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.update<DwPushSourceLink>(
      rows,
      columns: columns?.call(DwPushSourceLink.t),
      transaction: transaction,
    );
  }

  /// Updates a single [DwPushSourceLink]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<DwPushSourceLink> updateRow(
    _i1.DatabaseSession session,
    DwPushSourceLink row, {
    _i1.ColumnSelections<DwPushSourceLinkTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<DwPushSourceLink>(
      row,
      columns: columns?.call(DwPushSourceLink.t),
      transaction: transaction,
    );
  }

  /// Updates a single [DwPushSourceLink] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<DwPushSourceLink?> updateById(
    _i1.DatabaseSession session,
    int id, {
    required _i1.ColumnValueListBuilder<DwPushSourceLinkUpdateTable>
    columnValues,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateById<DwPushSourceLink>(
      id,
      columnValues: columnValues(DwPushSourceLink.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [DwPushSourceLink]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  Future<List<DwPushSourceLink>> updateWhere(
    _i1.DatabaseSession session, {
    required _i1.ColumnValueListBuilder<DwPushSourceLinkUpdateTable>
    columnValues,
    required _i1.WhereExpressionBuilder<DwPushSourceLinkTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<DwPushSourceLinkTable>? orderBy,
    _i1.OrderByListBuilder<DwPushSourceLinkTable>? orderByList,
    bool orderDescending = false,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateWhere<DwPushSourceLink>(
      columnValues: columnValues(DwPushSourceLink.t.updateTable),
      where: where(DwPushSourceLink.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(DwPushSourceLink.t),
      orderByList: orderByList?.call(DwPushSourceLink.t),
      orderDescending: orderDescending,
      transaction: transaction,
    );
  }

  /// Deletes all [DwPushSourceLink]s in the list and returns the deleted rows.
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  Future<List<DwPushSourceLink>> delete(
    _i1.DatabaseSession session,
    List<DwPushSourceLink> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<DwPushSourceLink>(
      rows,
      transaction: transaction,
    );
  }

  /// Deletes a single [DwPushSourceLink].
  Future<DwPushSourceLink> deleteRow(
    _i1.DatabaseSession session,
    DwPushSourceLink row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<DwPushSourceLink>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  Future<List<DwPushSourceLink>> deleteWhere(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<DwPushSourceLinkTable> where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteWhere<DwPushSourceLink>(
      where: where(DwPushSourceLink.t),
      transaction: transaction,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<DwPushSourceLinkTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<DwPushSourceLink>(
      where: where?.call(DwPushSourceLink.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [DwPushSourceLink] rows matching the [where] expression.
  Future<void> lockRows(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<DwPushSourceLinkTable> where,
    required _i1.LockMode lockMode,
    required _i1.Transaction transaction,
    _i1.LockBehavior lockBehavior = _i1.LockBehavior.wait,
  }) async {
    return session.db.lockRows<DwPushSourceLink>(
      where: where(DwPushSourceLink.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

class DwPushSourceLinkAttachRowRepository {
  const DwPushSourceLinkAttachRowRepository._();

  /// Creates a relation between the given [DwPushSourceLink] and [DwPushMessage]
  /// by setting the [DwPushSourceLink]'s foreign key `messageId` to refer to the [DwPushMessage].
  Future<void> message(
    _i1.DatabaseSession session,
    DwPushSourceLink dwPushSourceLink,
    _i2.DwPushMessage message, {
    _i1.Transaction? transaction,
  }) async {
    if (dwPushSourceLink.id == null) {
      throw ArgumentError.notNull('dwPushSourceLink.id');
    }
    if (message.id == null) {
      throw ArgumentError.notNull('message.id');
    }

    var $dwPushSourceLink = dwPushSourceLink.copyWith(messageId: message.id);
    await session.db.updateRow<DwPushSourceLink>(
      $dwPushSourceLink,
      columns: [DwPushSourceLink.t.messageId],
      transaction: transaction,
    );
  }
}
