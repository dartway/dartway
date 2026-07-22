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
import 'package:dartway_push_server/src/generated/protocol.dart' as _i2;

/// Generic bounded state for per-recipient throttling and aggregation leases.
abstract class DwPushRecipientState
    implements _i1.TableRow<int?>, _i1.ProtocolSerialization {
  DwPushRecipientState._({
    this.id,
    required this.recipientId,
    required this.stateKey,
    required this.nextAllowedAt,
    this.metadata,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  factory DwPushRecipientState({
    int? id,
    required int recipientId,
    required String stateKey,
    required DateTime nextAllowedAt,
    Map<String, String>? metadata,
    DateTime? updatedAt,
  }) = _DwPushRecipientStateImpl;

  factory DwPushRecipientState.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return DwPushRecipientState(
      id: jsonSerialization['id'] as int?,
      recipientId: jsonSerialization['recipientId'] as int,
      stateKey: jsonSerialization['stateKey'] as String,
      nextAllowedAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['nextAllowedAt'],
      ),
      metadata: jsonSerialization['metadata'] == null
          ? null
          : _i2.Protocol().deserialize<Map<String, String>>(
              jsonSerialization['metadata'],
            ),
      updatedAt: jsonSerialization['updatedAt'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(jsonSerialization['updatedAt']),
    );
  }

  static final t = DwPushRecipientStateTable();

  static const db = DwPushRecipientStateRepository._();

  @override
  int? id;

  int recipientId;

  String stateKey;

  DateTime nextAllowedAt;

  Map<String, String>? metadata;

  DateTime updatedAt;

  @override
  _i1.Table<int?> get table => t;

  /// Returns a shallow copy of this [DwPushRecipientState]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  DwPushRecipientState copyWith({
    int? id,
    int? recipientId,
    String? stateKey,
    DateTime? nextAllowedAt,
    Map<String, String>? metadata,
    DateTime? updatedAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'dartway_push.DwPushRecipientState',
      if (id != null) 'id': id,
      'recipientId': recipientId,
      'stateKey': stateKey,
      'nextAllowedAt': nextAllowedAt.toJson(),
      if (metadata != null) 'metadata': metadata?.toJson(),
      'updatedAt': updatedAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static DwPushRecipientStateInclude include() {
    return DwPushRecipientStateInclude._();
  }

  static DwPushRecipientStateIncludeList includeList({
    _i1.WhereExpressionBuilder<DwPushRecipientStateTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<DwPushRecipientStateTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<DwPushRecipientStateTable>? orderByList,
    DwPushRecipientStateInclude? include,
  }) {
    return DwPushRecipientStateIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(DwPushRecipientState.t),
      orderDescending: orderDescending,
      orderByList: orderByList?.call(DwPushRecipientState.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _DwPushRecipientStateImpl extends DwPushRecipientState {
  _DwPushRecipientStateImpl({
    int? id,
    required int recipientId,
    required String stateKey,
    required DateTime nextAllowedAt,
    Map<String, String>? metadata,
    DateTime? updatedAt,
  }) : super._(
         id: id,
         recipientId: recipientId,
         stateKey: stateKey,
         nextAllowedAt: nextAllowedAt,
         metadata: metadata,
         updatedAt: updatedAt,
       );

  /// Returns a shallow copy of this [DwPushRecipientState]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  DwPushRecipientState copyWith({
    Object? id = _Undefined,
    int? recipientId,
    String? stateKey,
    DateTime? nextAllowedAt,
    Object? metadata = _Undefined,
    DateTime? updatedAt,
  }) {
    return DwPushRecipientState(
      id: id is int? ? id : this.id,
      recipientId: recipientId ?? this.recipientId,
      stateKey: stateKey ?? this.stateKey,
      nextAllowedAt: nextAllowedAt ?? this.nextAllowedAt,
      metadata: metadata is Map<String, String>?
          ? metadata
          : this.metadata?.map(
              (
                key0,
                value0,
              ) => MapEntry(
                key0,
                value0,
              ),
            ),
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class DwPushRecipientStateUpdateTable
    extends _i1.UpdateTable<DwPushRecipientStateTable> {
  DwPushRecipientStateUpdateTable(super.table);

  _i1.ColumnValue<int, int> recipientId(int value) => _i1.ColumnValue(
    table.recipientId,
    value,
  );

  _i1.ColumnValue<String, String> stateKey(String value) => _i1.ColumnValue(
    table.stateKey,
    value,
  );

  _i1.ColumnValue<DateTime, DateTime> nextAllowedAt(DateTime value) =>
      _i1.ColumnValue(
        table.nextAllowedAt,
        value,
      );

  _i1.ColumnValue<Map<String, String>, Map<String, String>> metadata(
    Map<String, String>? value,
  ) => _i1.ColumnValue(
    table.metadata,
    value,
  );

  _i1.ColumnValue<DateTime, DateTime> updatedAt(DateTime value) =>
      _i1.ColumnValue(
        table.updatedAt,
        value,
      );
}

class DwPushRecipientStateTable extends _i1.Table<int?> {
  DwPushRecipientStateTable({super.tableRelation})
    : super(tableName: 'dw_push_recipient_state') {
    updateTable = DwPushRecipientStateUpdateTable(this);
    recipientId = _i1.ColumnInt(
      'recipientId',
      this,
    );
    stateKey = _i1.ColumnString(
      'stateKey',
      this,
    );
    nextAllowedAt = _i1.ColumnDateTime(
      'nextAllowedAt',
      this,
    );
    metadata = _i1.ColumnSerializable<Map<String, String>>(
      'metadata',
      this,
    );
    updatedAt = _i1.ColumnDateTime(
      'updatedAt',
      this,
      hasDefault: true,
    );
  }

  late final DwPushRecipientStateUpdateTable updateTable;

  late final _i1.ColumnInt recipientId;

  late final _i1.ColumnString stateKey;

  late final _i1.ColumnDateTime nextAllowedAt;

  late final _i1.ColumnSerializable<Map<String, String>> metadata;

  late final _i1.ColumnDateTime updatedAt;

  @override
  List<_i1.Column> get columns => [
    id,
    recipientId,
    stateKey,
    nextAllowedAt,
    metadata,
    updatedAt,
  ];
}

class DwPushRecipientStateInclude extends _i1.IncludeObject {
  DwPushRecipientStateInclude._();

  @override
  Map<String, _i1.Include?> get includes => {};

  @override
  _i1.Table<int?> get table => DwPushRecipientState.t;
}

class DwPushRecipientStateIncludeList extends _i1.IncludeList {
  DwPushRecipientStateIncludeList._({
    _i1.WhereExpressionBuilder<DwPushRecipientStateTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(DwPushRecipientState.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<int?> get table => DwPushRecipientState.t;
}

class DwPushRecipientStateRepository {
  const DwPushRecipientStateRepository._();

  /// Returns a list of [DwPushRecipientState]s matching the given query parameters.
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
  Future<List<DwPushRecipientState>> find(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<DwPushRecipientStateTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<DwPushRecipientStateTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<DwPushRecipientStateTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<DwPushRecipientState>(
      where: where?.call(DwPushRecipientState.t),
      orderBy: orderBy?.call(DwPushRecipientState.t),
      orderByList: orderByList?.call(DwPushRecipientState.t),
      orderDescending: orderDescending,
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [DwPushRecipientState] matching the given query parameters.
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
  Future<DwPushRecipientState?> findFirstRow(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<DwPushRecipientStateTable>? where,
    int? offset,
    _i1.OrderByBuilder<DwPushRecipientStateTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<DwPushRecipientStateTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<DwPushRecipientState>(
      where: where?.call(DwPushRecipientState.t),
      orderBy: orderBy?.call(DwPushRecipientState.t),
      orderByList: orderByList?.call(DwPushRecipientState.t),
      orderDescending: orderDescending,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [DwPushRecipientState] by its [id] or null if no such row exists.
  Future<DwPushRecipientState?> findById(
    _i1.DatabaseSession session,
    int id, {
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<DwPushRecipientState>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [DwPushRecipientState]s in the list and returns the inserted rows.
  ///
  /// The returned [DwPushRecipientState]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  ///
  /// If [ignoreConflicts] is set to `true`, rows that conflict with existing
  /// rows are silently skipped, and only the successfully inserted rows are
  /// returned.
  Future<List<DwPushRecipientState>> insert(
    _i1.DatabaseSession session,
    List<DwPushRecipientState> rows, {
    _i1.Transaction? transaction,
    bool ignoreConflicts = false,
  }) async {
    return session.db.insert<DwPushRecipientState>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
    );
  }

  /// Inserts a single [DwPushRecipientState] and returns the inserted row.
  ///
  /// The returned [DwPushRecipientState] will have its `id` field set.
  Future<DwPushRecipientState> insertRow(
    _i1.DatabaseSession session,
    DwPushRecipientState row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<DwPushRecipientState>(
      row,
      transaction: transaction,
    );
  }

  /// Updates all [DwPushRecipientState]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  Future<List<DwPushRecipientState>> update(
    _i1.DatabaseSession session,
    List<DwPushRecipientState> rows, {
    _i1.ColumnSelections<DwPushRecipientStateTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.update<DwPushRecipientState>(
      rows,
      columns: columns?.call(DwPushRecipientState.t),
      transaction: transaction,
    );
  }

  /// Updates a single [DwPushRecipientState]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<DwPushRecipientState> updateRow(
    _i1.DatabaseSession session,
    DwPushRecipientState row, {
    _i1.ColumnSelections<DwPushRecipientStateTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<DwPushRecipientState>(
      row,
      columns: columns?.call(DwPushRecipientState.t),
      transaction: transaction,
    );
  }

  /// Updates a single [DwPushRecipientState] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<DwPushRecipientState?> updateById(
    _i1.DatabaseSession session,
    int id, {
    required _i1.ColumnValueListBuilder<DwPushRecipientStateUpdateTable>
    columnValues,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateById<DwPushRecipientState>(
      id,
      columnValues: columnValues(DwPushRecipientState.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [DwPushRecipientState]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  Future<List<DwPushRecipientState>> updateWhere(
    _i1.DatabaseSession session, {
    required _i1.ColumnValueListBuilder<DwPushRecipientStateUpdateTable>
    columnValues,
    required _i1.WhereExpressionBuilder<DwPushRecipientStateTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<DwPushRecipientStateTable>? orderBy,
    _i1.OrderByListBuilder<DwPushRecipientStateTable>? orderByList,
    bool orderDescending = false,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateWhere<DwPushRecipientState>(
      columnValues: columnValues(DwPushRecipientState.t.updateTable),
      where: where(DwPushRecipientState.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(DwPushRecipientState.t),
      orderByList: orderByList?.call(DwPushRecipientState.t),
      orderDescending: orderDescending,
      transaction: transaction,
    );
  }

  /// Deletes all [DwPushRecipientState]s in the list and returns the deleted rows.
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  Future<List<DwPushRecipientState>> delete(
    _i1.DatabaseSession session,
    List<DwPushRecipientState> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<DwPushRecipientState>(
      rows,
      transaction: transaction,
    );
  }

  /// Deletes a single [DwPushRecipientState].
  Future<DwPushRecipientState> deleteRow(
    _i1.DatabaseSession session,
    DwPushRecipientState row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<DwPushRecipientState>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  Future<List<DwPushRecipientState>> deleteWhere(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<DwPushRecipientStateTable> where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteWhere<DwPushRecipientState>(
      where: where(DwPushRecipientState.t),
      transaction: transaction,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<DwPushRecipientStateTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<DwPushRecipientState>(
      where: where?.call(DwPushRecipientState.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [DwPushRecipientState] rows matching the [where] expression.
  Future<void> lockRows(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<DwPushRecipientStateTable> where,
    required _i1.LockMode lockMode,
    required _i1.Transaction transaction,
    _i1.LockBehavior lockBehavior = _i1.LockBehavior.wait,
  }) async {
    return session.db.lockRows<DwPushRecipientState>(
      where: where(DwPushRecipientState.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
