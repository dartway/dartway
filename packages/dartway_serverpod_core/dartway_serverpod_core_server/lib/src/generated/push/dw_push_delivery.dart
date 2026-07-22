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
import '../push/dw_push_message.dart' as _i2;
import 'package:dartway_serverpod_core_server/src/generated/protocol.dart'
    as _i3;

/// Short-lived queue row. Terminal rows are deleted, never archived here.
abstract class DwPushDelivery
    implements _i1.TableRow<int?>, _i1.ProtocolSerialization {
  DwPushDelivery._({
    this.id,
    required this.messageId,
    this.message,
    required this.recipientId,
    required this.availableAt,
    int? attemptCount,
    this.leaseId,
    this.leaseExpiresAt,
    this.lastError,
    DateTime? createdAt,
  }) : attemptCount = attemptCount ?? 0,
       createdAt = createdAt ?? DateTime.now();

  factory DwPushDelivery({
    int? id,
    required int messageId,
    _i2.DwPushMessage? message,
    required int recipientId,
    required DateTime availableAt,
    int? attemptCount,
    String? leaseId,
    DateTime? leaseExpiresAt,
    String? lastError,
    DateTime? createdAt,
  }) = _DwPushDeliveryImpl;

  factory DwPushDelivery.fromJson(Map<String, dynamic> jsonSerialization) {
    return DwPushDelivery(
      id: jsonSerialization['id'] as int?,
      messageId: jsonSerialization['messageId'] as int,
      message: jsonSerialization['message'] == null
          ? null
          : _i3.Protocol().deserialize<_i2.DwPushMessage>(
              jsonSerialization['message'],
            ),
      recipientId: jsonSerialization['recipientId'] as int,
      availableAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['availableAt'],
      ),
      attemptCount: jsonSerialization['attemptCount'] as int?,
      leaseId: jsonSerialization['leaseId'] as String?,
      leaseExpiresAt: jsonSerialization['leaseExpiresAt'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(
              jsonSerialization['leaseExpiresAt'],
            ),
      lastError: jsonSerialization['lastError'] as String?,
      createdAt: jsonSerialization['createdAt'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(jsonSerialization['createdAt']),
    );
  }

  static final t = DwPushDeliveryTable();

  static const db = DwPushDeliveryRepository._();

  @override
  int? id;

  int messageId;

  _i2.DwPushMessage? message;

  int recipientId;

  DateTime availableAt;

  int attemptCount;

  String? leaseId;

  DateTime? leaseExpiresAt;

  String? lastError;

  DateTime createdAt;

  @override
  _i1.Table<int?> get table => t;

  /// Returns a shallow copy of this [DwPushDelivery]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  DwPushDelivery copyWith({
    int? id,
    int? messageId,
    _i2.DwPushMessage? message,
    int? recipientId,
    DateTime? availableAt,
    int? attemptCount,
    String? leaseId,
    DateTime? leaseExpiresAt,
    String? lastError,
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'dartway_serverpod_core.DwPushDelivery',
      if (id != null) 'id': id,
      'messageId': messageId,
      if (message != null) 'message': message?.toJson(),
      'recipientId': recipientId,
      'availableAt': availableAt.toJson(),
      'attemptCount': attemptCount,
      if (leaseId != null) 'leaseId': leaseId,
      if (leaseExpiresAt != null) 'leaseExpiresAt': leaseExpiresAt?.toJson(),
      if (lastError != null) 'lastError': lastError,
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static DwPushDeliveryInclude include({_i2.DwPushMessageInclude? message}) {
    return DwPushDeliveryInclude._(message: message);
  }

  static DwPushDeliveryIncludeList includeList({
    _i1.WhereExpressionBuilder<DwPushDeliveryTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<DwPushDeliveryTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<DwPushDeliveryTable>? orderByList,
    DwPushDeliveryInclude? include,
  }) {
    return DwPushDeliveryIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(DwPushDelivery.t),
      orderDescending: orderDescending,
      orderByList: orderByList?.call(DwPushDelivery.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _DwPushDeliveryImpl extends DwPushDelivery {
  _DwPushDeliveryImpl({
    int? id,
    required int messageId,
    _i2.DwPushMessage? message,
    required int recipientId,
    required DateTime availableAt,
    int? attemptCount,
    String? leaseId,
    DateTime? leaseExpiresAt,
    String? lastError,
    DateTime? createdAt,
  }) : super._(
         id: id,
         messageId: messageId,
         message: message,
         recipientId: recipientId,
         availableAt: availableAt,
         attemptCount: attemptCount,
         leaseId: leaseId,
         leaseExpiresAt: leaseExpiresAt,
         lastError: lastError,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [DwPushDelivery]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  DwPushDelivery copyWith({
    Object? id = _Undefined,
    int? messageId,
    Object? message = _Undefined,
    int? recipientId,
    DateTime? availableAt,
    int? attemptCount,
    Object? leaseId = _Undefined,
    Object? leaseExpiresAt = _Undefined,
    Object? lastError = _Undefined,
    DateTime? createdAt,
  }) {
    return DwPushDelivery(
      id: id is int? ? id : this.id,
      messageId: messageId ?? this.messageId,
      message: message is _i2.DwPushMessage?
          ? message
          : this.message?.copyWith(),
      recipientId: recipientId ?? this.recipientId,
      availableAt: availableAt ?? this.availableAt,
      attemptCount: attemptCount ?? this.attemptCount,
      leaseId: leaseId is String? ? leaseId : this.leaseId,
      leaseExpiresAt: leaseExpiresAt is DateTime?
          ? leaseExpiresAt
          : this.leaseExpiresAt,
      lastError: lastError is String? ? lastError : this.lastError,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class DwPushDeliveryUpdateTable extends _i1.UpdateTable<DwPushDeliveryTable> {
  DwPushDeliveryUpdateTable(super.table);

  _i1.ColumnValue<int, int> messageId(int value) => _i1.ColumnValue(
    table.messageId,
    value,
  );

  _i1.ColumnValue<int, int> recipientId(int value) => _i1.ColumnValue(
    table.recipientId,
    value,
  );

  _i1.ColumnValue<DateTime, DateTime> availableAt(DateTime value) =>
      _i1.ColumnValue(
        table.availableAt,
        value,
      );

  _i1.ColumnValue<int, int> attemptCount(int value) => _i1.ColumnValue(
    table.attemptCount,
    value,
  );

  _i1.ColumnValue<String, String> leaseId(String? value) => _i1.ColumnValue(
    table.leaseId,
    value,
  );

  _i1.ColumnValue<DateTime, DateTime> leaseExpiresAt(DateTime? value) =>
      _i1.ColumnValue(
        table.leaseExpiresAt,
        value,
      );

  _i1.ColumnValue<String, String> lastError(String? value) => _i1.ColumnValue(
    table.lastError,
    value,
  );

  _i1.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _i1.ColumnValue(
        table.createdAt,
        value,
      );
}

class DwPushDeliveryTable extends _i1.Table<int?> {
  DwPushDeliveryTable({super.tableRelation})
    : super(tableName: 'dw_push_delivery') {
    updateTable = DwPushDeliveryUpdateTable(this);
    messageId = _i1.ColumnInt(
      'messageId',
      this,
    );
    recipientId = _i1.ColumnInt(
      'recipientId',
      this,
    );
    availableAt = _i1.ColumnDateTime(
      'availableAt',
      this,
    );
    attemptCount = _i1.ColumnInt(
      'attemptCount',
      this,
      hasDefault: true,
    );
    leaseId = _i1.ColumnString(
      'leaseId',
      this,
    );
    leaseExpiresAt = _i1.ColumnDateTime(
      'leaseExpiresAt',
      this,
    );
    lastError = _i1.ColumnString(
      'lastError',
      this,
    );
    createdAt = _i1.ColumnDateTime(
      'createdAt',
      this,
      hasDefault: true,
    );
  }

  late final DwPushDeliveryUpdateTable updateTable;

  late final _i1.ColumnInt messageId;

  _i2.DwPushMessageTable? _message;

  late final _i1.ColumnInt recipientId;

  late final _i1.ColumnDateTime availableAt;

  late final _i1.ColumnInt attemptCount;

  late final _i1.ColumnString leaseId;

  late final _i1.ColumnDateTime leaseExpiresAt;

  late final _i1.ColumnString lastError;

  late final _i1.ColumnDateTime createdAt;

  _i2.DwPushMessageTable get message {
    if (_message != null) return _message!;
    _message = _i1.createRelationTable(
      relationFieldName: 'message',
      field: DwPushDelivery.t.messageId,
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
    availableAt,
    attemptCount,
    leaseId,
    leaseExpiresAt,
    lastError,
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

class DwPushDeliveryInclude extends _i1.IncludeObject {
  DwPushDeliveryInclude._({_i2.DwPushMessageInclude? message}) {
    _message = message;
  }

  _i2.DwPushMessageInclude? _message;

  @override
  Map<String, _i1.Include?> get includes => {'message': _message};

  @override
  _i1.Table<int?> get table => DwPushDelivery.t;
}

class DwPushDeliveryIncludeList extends _i1.IncludeList {
  DwPushDeliveryIncludeList._({
    _i1.WhereExpressionBuilder<DwPushDeliveryTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(DwPushDelivery.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<int?> get table => DwPushDelivery.t;
}

class DwPushDeliveryRepository {
  const DwPushDeliveryRepository._();

  final attachRow = const DwPushDeliveryAttachRowRepository._();

  /// Returns a list of [DwPushDelivery]s matching the given query parameters.
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
  Future<List<DwPushDelivery>> find(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<DwPushDeliveryTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<DwPushDeliveryTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<DwPushDeliveryTable>? orderByList,
    _i1.Transaction? transaction,
    DwPushDeliveryInclude? include,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<DwPushDelivery>(
      where: where?.call(DwPushDelivery.t),
      orderBy: orderBy?.call(DwPushDelivery.t),
      orderByList: orderByList?.call(DwPushDelivery.t),
      orderDescending: orderDescending,
      limit: limit,
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [DwPushDelivery] matching the given query parameters.
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
  Future<DwPushDelivery?> findFirstRow(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<DwPushDeliveryTable>? where,
    int? offset,
    _i1.OrderByBuilder<DwPushDeliveryTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<DwPushDeliveryTable>? orderByList,
    _i1.Transaction? transaction,
    DwPushDeliveryInclude? include,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<DwPushDelivery>(
      where: where?.call(DwPushDelivery.t),
      orderBy: orderBy?.call(DwPushDelivery.t),
      orderByList: orderByList?.call(DwPushDelivery.t),
      orderDescending: orderDescending,
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [DwPushDelivery] by its [id] or null if no such row exists.
  Future<DwPushDelivery?> findById(
    _i1.DatabaseSession session,
    int id, {
    _i1.Transaction? transaction,
    DwPushDeliveryInclude? include,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<DwPushDelivery>(
      id,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [DwPushDelivery]s in the list and returns the inserted rows.
  ///
  /// The returned [DwPushDelivery]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  ///
  /// If [ignoreConflicts] is set to `true`, rows that conflict with existing
  /// rows are silently skipped, and only the successfully inserted rows are
  /// returned.
  Future<List<DwPushDelivery>> insert(
    _i1.DatabaseSession session,
    List<DwPushDelivery> rows, {
    _i1.Transaction? transaction,
    bool ignoreConflicts = false,
  }) async {
    return session.db.insert<DwPushDelivery>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
    );
  }

  /// Inserts a single [DwPushDelivery] and returns the inserted row.
  ///
  /// The returned [DwPushDelivery] will have its `id` field set.
  Future<DwPushDelivery> insertRow(
    _i1.DatabaseSession session,
    DwPushDelivery row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<DwPushDelivery>(
      row,
      transaction: transaction,
    );
  }

  /// Updates all [DwPushDelivery]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  Future<List<DwPushDelivery>> update(
    _i1.DatabaseSession session,
    List<DwPushDelivery> rows, {
    _i1.ColumnSelections<DwPushDeliveryTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.update<DwPushDelivery>(
      rows,
      columns: columns?.call(DwPushDelivery.t),
      transaction: transaction,
    );
  }

  /// Updates a single [DwPushDelivery]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<DwPushDelivery> updateRow(
    _i1.DatabaseSession session,
    DwPushDelivery row, {
    _i1.ColumnSelections<DwPushDeliveryTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<DwPushDelivery>(
      row,
      columns: columns?.call(DwPushDelivery.t),
      transaction: transaction,
    );
  }

  /// Updates a single [DwPushDelivery] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<DwPushDelivery?> updateById(
    _i1.DatabaseSession session,
    int id, {
    required _i1.ColumnValueListBuilder<DwPushDeliveryUpdateTable> columnValues,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateById<DwPushDelivery>(
      id,
      columnValues: columnValues(DwPushDelivery.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [DwPushDelivery]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  Future<List<DwPushDelivery>> updateWhere(
    _i1.DatabaseSession session, {
    required _i1.ColumnValueListBuilder<DwPushDeliveryUpdateTable> columnValues,
    required _i1.WhereExpressionBuilder<DwPushDeliveryTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<DwPushDeliveryTable>? orderBy,
    _i1.OrderByListBuilder<DwPushDeliveryTable>? orderByList,
    bool orderDescending = false,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateWhere<DwPushDelivery>(
      columnValues: columnValues(DwPushDelivery.t.updateTable),
      where: where(DwPushDelivery.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(DwPushDelivery.t),
      orderByList: orderByList?.call(DwPushDelivery.t),
      orderDescending: orderDescending,
      transaction: transaction,
    );
  }

  /// Deletes all [DwPushDelivery]s in the list and returns the deleted rows.
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  Future<List<DwPushDelivery>> delete(
    _i1.DatabaseSession session,
    List<DwPushDelivery> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<DwPushDelivery>(
      rows,
      transaction: transaction,
    );
  }

  /// Deletes a single [DwPushDelivery].
  Future<DwPushDelivery> deleteRow(
    _i1.DatabaseSession session,
    DwPushDelivery row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<DwPushDelivery>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  Future<List<DwPushDelivery>> deleteWhere(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<DwPushDeliveryTable> where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteWhere<DwPushDelivery>(
      where: where(DwPushDelivery.t),
      transaction: transaction,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<DwPushDeliveryTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<DwPushDelivery>(
      where: where?.call(DwPushDelivery.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [DwPushDelivery] rows matching the [where] expression.
  Future<void> lockRows(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<DwPushDeliveryTable> where,
    required _i1.LockMode lockMode,
    required _i1.Transaction transaction,
    _i1.LockBehavior lockBehavior = _i1.LockBehavior.wait,
  }) async {
    return session.db.lockRows<DwPushDelivery>(
      where: where(DwPushDelivery.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

class DwPushDeliveryAttachRowRepository {
  const DwPushDeliveryAttachRowRepository._();

  /// Creates a relation between the given [DwPushDelivery] and [DwPushMessage]
  /// by setting the [DwPushDelivery]'s foreign key `messageId` to refer to the [DwPushMessage].
  Future<void> message(
    _i1.DatabaseSession session,
    DwPushDelivery dwPushDelivery,
    _i2.DwPushMessage message, {
    _i1.Transaction? transaction,
  }) async {
    if (dwPushDelivery.id == null) {
      throw ArgumentError.notNull('dwPushDelivery.id');
    }
    if (message.id == null) {
      throw ArgumentError.notNull('message.id');
    }

    var $dwPushDelivery = dwPushDelivery.copyWith(messageId: message.id);
    await session.db.updateRow<DwPushDelivery>(
      $dwPushDelivery,
      columns: [DwPushDelivery.t.messageId],
      transaction: transaction,
    );
  }
}
