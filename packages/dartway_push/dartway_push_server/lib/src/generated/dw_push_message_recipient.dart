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

/// Compact recipient membership retained after terminal delivery until the
/// message expires or its whole audience is cancelled and no deliveries remain.
abstract class DwPushMessageRecipient
    implements _i1.TableRow<int?>, _i1.ProtocolSerialization {
  DwPushMessageRecipient._({
    this.id,
    required this.messageId,
    this.message,
    required this.recipientId,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory DwPushMessageRecipient({
    int? id,
    required int messageId,
    _i2.DwPushMessage? message,
    required int recipientId,
    DateTime? createdAt,
  }) = _DwPushMessageRecipientImpl;

  factory DwPushMessageRecipient.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return DwPushMessageRecipient(
      id: jsonSerialization['id'] as int?,
      messageId: jsonSerialization['messageId'] as int,
      message: jsonSerialization['message'] == null
          ? null
          : _i3.Protocol().deserialize<_i2.DwPushMessage>(
              jsonSerialization['message'],
            ),
      recipientId: jsonSerialization['recipientId'] as int,
      createdAt: jsonSerialization['createdAt'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(jsonSerialization['createdAt']),
    );
  }

  static final t = DwPushMessageRecipientTable();

  static const db = DwPushMessageRecipientRepository._();

  @override
  int? id;

  int messageId;

  _i2.DwPushMessage? message;

  int recipientId;

  DateTime createdAt;

  @override
  _i1.Table<int?> get table => t;

  /// Returns a shallow copy of this [DwPushMessageRecipient]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  DwPushMessageRecipient copyWith({
    int? id,
    int? messageId,
    _i2.DwPushMessage? message,
    int? recipientId,
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'dartway_push.DwPushMessageRecipient',
      if (id != null) 'id': id,
      'messageId': messageId,
      if (message != null) 'message': message?.toJson(),
      'recipientId': recipientId,
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static DwPushMessageRecipientInclude include({
    _i2.DwPushMessageInclude? message,
  }) {
    return DwPushMessageRecipientInclude._(message: message);
  }

  static DwPushMessageRecipientIncludeList includeList({
    _i1.WhereExpressionBuilder<DwPushMessageRecipientTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<DwPushMessageRecipientTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<DwPushMessageRecipientTable>? orderByList,
    DwPushMessageRecipientInclude? include,
  }) {
    return DwPushMessageRecipientIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(DwPushMessageRecipient.t),
      orderDescending: orderDescending,
      orderByList: orderByList?.call(DwPushMessageRecipient.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _DwPushMessageRecipientImpl extends DwPushMessageRecipient {
  _DwPushMessageRecipientImpl({
    int? id,
    required int messageId,
    _i2.DwPushMessage? message,
    required int recipientId,
    DateTime? createdAt,
  }) : super._(
         id: id,
         messageId: messageId,
         message: message,
         recipientId: recipientId,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [DwPushMessageRecipient]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  DwPushMessageRecipient copyWith({
    Object? id = _Undefined,
    int? messageId,
    Object? message = _Undefined,
    int? recipientId,
    DateTime? createdAt,
  }) {
    return DwPushMessageRecipient(
      id: id is int? ? id : this.id,
      messageId: messageId ?? this.messageId,
      message: message is _i2.DwPushMessage?
          ? message
          : this.message?.copyWith(),
      recipientId: recipientId ?? this.recipientId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class DwPushMessageRecipientUpdateTable
    extends _i1.UpdateTable<DwPushMessageRecipientTable> {
  DwPushMessageRecipientUpdateTable(super.table);

  _i1.ColumnValue<int, int> messageId(int value) => _i1.ColumnValue(
    table.messageId,
    value,
  );

  _i1.ColumnValue<int, int> recipientId(int value) => _i1.ColumnValue(
    table.recipientId,
    value,
  );

  _i1.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _i1.ColumnValue(
        table.createdAt,
        value,
      );
}

class DwPushMessageRecipientTable extends _i1.Table<int?> {
  DwPushMessageRecipientTable({super.tableRelation})
    : super(tableName: 'dw_push_message_recipient') {
    updateTable = DwPushMessageRecipientUpdateTable(this);
    messageId = _i1.ColumnInt(
      'messageId',
      this,
    );
    recipientId = _i1.ColumnInt(
      'recipientId',
      this,
    );
    createdAt = _i1.ColumnDateTime(
      'createdAt',
      this,
      hasDefault: true,
    );
  }

  late final DwPushMessageRecipientUpdateTable updateTable;

  late final _i1.ColumnInt messageId;

  _i2.DwPushMessageTable? _message;

  late final _i1.ColumnInt recipientId;

  late final _i1.ColumnDateTime createdAt;

  _i2.DwPushMessageTable get message {
    if (_message != null) return _message!;
    _message = _i1.createRelationTable(
      relationFieldName: 'message',
      field: DwPushMessageRecipient.t.messageId,
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
    messageId,
    recipientId,
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

class DwPushMessageRecipientInclude extends _i1.IncludeObject {
  DwPushMessageRecipientInclude._({_i2.DwPushMessageInclude? message}) {
    _message = message;
  }

  _i2.DwPushMessageInclude? _message;

  @override
  Map<String, _i1.Include?> get includes => {'message': _message};

  @override
  _i1.Table<int?> get table => DwPushMessageRecipient.t;
}

class DwPushMessageRecipientIncludeList extends _i1.IncludeList {
  DwPushMessageRecipientIncludeList._({
    _i1.WhereExpressionBuilder<DwPushMessageRecipientTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(DwPushMessageRecipient.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<int?> get table => DwPushMessageRecipient.t;
}

class DwPushMessageRecipientRepository {
  const DwPushMessageRecipientRepository._();

  final attachRow = const DwPushMessageRecipientAttachRowRepository._();

  /// Returns a list of [DwPushMessageRecipient]s matching the given query parameters.
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
  Future<List<DwPushMessageRecipient>> find(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<DwPushMessageRecipientTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<DwPushMessageRecipientTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<DwPushMessageRecipientTable>? orderByList,
    _i1.Transaction? transaction,
    DwPushMessageRecipientInclude? include,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<DwPushMessageRecipient>(
      where: where?.call(DwPushMessageRecipient.t),
      orderBy: orderBy?.call(DwPushMessageRecipient.t),
      orderByList: orderByList?.call(DwPushMessageRecipient.t),
      orderDescending: orderDescending,
      limit: limit,
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [DwPushMessageRecipient] matching the given query parameters.
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
  Future<DwPushMessageRecipient?> findFirstRow(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<DwPushMessageRecipientTable>? where,
    int? offset,
    _i1.OrderByBuilder<DwPushMessageRecipientTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<DwPushMessageRecipientTable>? orderByList,
    _i1.Transaction? transaction,
    DwPushMessageRecipientInclude? include,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<DwPushMessageRecipient>(
      where: where?.call(DwPushMessageRecipient.t),
      orderBy: orderBy?.call(DwPushMessageRecipient.t),
      orderByList: orderByList?.call(DwPushMessageRecipient.t),
      orderDescending: orderDescending,
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [DwPushMessageRecipient] by its [id] or null if no such row exists.
  Future<DwPushMessageRecipient?> findById(
    _i1.DatabaseSession session,
    int id, {
    _i1.Transaction? transaction,
    DwPushMessageRecipientInclude? include,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<DwPushMessageRecipient>(
      id,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [DwPushMessageRecipient]s in the list and returns the inserted rows.
  ///
  /// The returned [DwPushMessageRecipient]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  ///
  /// If [ignoreConflicts] is set to `true`, rows that conflict with existing
  /// rows are silently skipped, and only the successfully inserted rows are
  /// returned.
  Future<List<DwPushMessageRecipient>> insert(
    _i1.DatabaseSession session,
    List<DwPushMessageRecipient> rows, {
    _i1.Transaction? transaction,
    bool ignoreConflicts = false,
  }) async {
    return session.db.insert<DwPushMessageRecipient>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
    );
  }

  /// Inserts a single [DwPushMessageRecipient] and returns the inserted row.
  ///
  /// The returned [DwPushMessageRecipient] will have its `id` field set.
  Future<DwPushMessageRecipient> insertRow(
    _i1.DatabaseSession session,
    DwPushMessageRecipient row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<DwPushMessageRecipient>(
      row,
      transaction: transaction,
    );
  }

  /// Updates all [DwPushMessageRecipient]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  Future<List<DwPushMessageRecipient>> update(
    _i1.DatabaseSession session,
    List<DwPushMessageRecipient> rows, {
    _i1.ColumnSelections<DwPushMessageRecipientTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.update<DwPushMessageRecipient>(
      rows,
      columns: columns?.call(DwPushMessageRecipient.t),
      transaction: transaction,
    );
  }

  /// Updates a single [DwPushMessageRecipient]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<DwPushMessageRecipient> updateRow(
    _i1.DatabaseSession session,
    DwPushMessageRecipient row, {
    _i1.ColumnSelections<DwPushMessageRecipientTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<DwPushMessageRecipient>(
      row,
      columns: columns?.call(DwPushMessageRecipient.t),
      transaction: transaction,
    );
  }

  /// Updates a single [DwPushMessageRecipient] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<DwPushMessageRecipient?> updateById(
    _i1.DatabaseSession session,
    int id, {
    required _i1.ColumnValueListBuilder<DwPushMessageRecipientUpdateTable>
    columnValues,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateById<DwPushMessageRecipient>(
      id,
      columnValues: columnValues(DwPushMessageRecipient.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [DwPushMessageRecipient]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  Future<List<DwPushMessageRecipient>> updateWhere(
    _i1.DatabaseSession session, {
    required _i1.ColumnValueListBuilder<DwPushMessageRecipientUpdateTable>
    columnValues,
    required _i1.WhereExpressionBuilder<DwPushMessageRecipientTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<DwPushMessageRecipientTable>? orderBy,
    _i1.OrderByListBuilder<DwPushMessageRecipientTable>? orderByList,
    bool orderDescending = false,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateWhere<DwPushMessageRecipient>(
      columnValues: columnValues(DwPushMessageRecipient.t.updateTable),
      where: where(DwPushMessageRecipient.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(DwPushMessageRecipient.t),
      orderByList: orderByList?.call(DwPushMessageRecipient.t),
      orderDescending: orderDescending,
      transaction: transaction,
    );
  }

  /// Deletes all [DwPushMessageRecipient]s in the list and returns the deleted rows.
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  Future<List<DwPushMessageRecipient>> delete(
    _i1.DatabaseSession session,
    List<DwPushMessageRecipient> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<DwPushMessageRecipient>(
      rows,
      transaction: transaction,
    );
  }

  /// Deletes a single [DwPushMessageRecipient].
  Future<DwPushMessageRecipient> deleteRow(
    _i1.DatabaseSession session,
    DwPushMessageRecipient row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<DwPushMessageRecipient>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  Future<List<DwPushMessageRecipient>> deleteWhere(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<DwPushMessageRecipientTable> where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteWhere<DwPushMessageRecipient>(
      where: where(DwPushMessageRecipient.t),
      transaction: transaction,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<DwPushMessageRecipientTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<DwPushMessageRecipient>(
      where: where?.call(DwPushMessageRecipient.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [DwPushMessageRecipient] rows matching the [where] expression.
  Future<void> lockRows(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<DwPushMessageRecipientTable> where,
    required _i1.LockMode lockMode,
    required _i1.Transaction transaction,
    _i1.LockBehavior lockBehavior = _i1.LockBehavior.wait,
  }) async {
    return session.db.lockRows<DwPushMessageRecipient>(
      where: where(DwPushMessageRecipient.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

class DwPushMessageRecipientAttachRowRepository {
  const DwPushMessageRecipientAttachRowRepository._();

  /// Creates a relation between the given [DwPushMessageRecipient] and [DwPushMessage]
  /// by setting the [DwPushMessageRecipient]'s foreign key `messageId` to refer to the [DwPushMessage].
  Future<void> message(
    _i1.DatabaseSession session,
    DwPushMessageRecipient dwPushMessageRecipient,
    _i2.DwPushMessage message, {
    _i1.Transaction? transaction,
  }) async {
    if (dwPushMessageRecipient.id == null) {
      throw ArgumentError.notNull('dwPushMessageRecipient.id');
    }
    if (message.id == null) {
      throw ArgumentError.notNull('message.id');
    }

    var $dwPushMessageRecipient = dwPushMessageRecipient.copyWith(
      messageId: message.id,
    );
    await session.db.updateRow<DwPushMessageRecipient>(
      $dwPushMessageRecipient,
      columns: [DwPushMessageRecipient.t.messageId],
      transaction: transaction,
    );
  }
}
