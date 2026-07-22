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

/// Operational state for pausing and monitoring one logical worker.
abstract class DwPushRuntimeState
    implements _i1.TableRow<int?>, _i1.ProtocolSerialization {
  DwPushRuntimeState._({
    this.id,
    required this.workerName,
    bool? isPaused,
    this.pausedUntil,
    this.lastClaimedAt,
    this.lastCompletedAt,
    this.lastErrorAt,
    this.lastError,
    DateTime? updatedAt,
  }) : isPaused = isPaused ?? false,
       updatedAt = updatedAt ?? DateTime.now();

  factory DwPushRuntimeState({
    int? id,
    required String workerName,
    bool? isPaused,
    DateTime? pausedUntil,
    DateTime? lastClaimedAt,
    DateTime? lastCompletedAt,
    DateTime? lastErrorAt,
    String? lastError,
    DateTime? updatedAt,
  }) = _DwPushRuntimeStateImpl;

  factory DwPushRuntimeState.fromJson(Map<String, dynamic> jsonSerialization) {
    return DwPushRuntimeState(
      id: jsonSerialization['id'] as int?,
      workerName: jsonSerialization['workerName'] as String,
      isPaused: jsonSerialization['isPaused'] == null
          ? null
          : _i1.BoolJsonExtension.fromJson(jsonSerialization['isPaused']),
      pausedUntil: jsonSerialization['pausedUntil'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(
              jsonSerialization['pausedUntil'],
            ),
      lastClaimedAt: jsonSerialization['lastClaimedAt'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(
              jsonSerialization['lastClaimedAt'],
            ),
      lastCompletedAt: jsonSerialization['lastCompletedAt'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(
              jsonSerialization['lastCompletedAt'],
            ),
      lastErrorAt: jsonSerialization['lastErrorAt'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(
              jsonSerialization['lastErrorAt'],
            ),
      lastError: jsonSerialization['lastError'] as String?,
      updatedAt: jsonSerialization['updatedAt'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(jsonSerialization['updatedAt']),
    );
  }

  static final t = DwPushRuntimeStateTable();

  static const db = DwPushRuntimeStateRepository._();

  @override
  int? id;

  String workerName;

  bool isPaused;

  DateTime? pausedUntil;

  DateTime? lastClaimedAt;

  DateTime? lastCompletedAt;

  DateTime? lastErrorAt;

  String? lastError;

  DateTime updatedAt;

  @override
  _i1.Table<int?> get table => t;

  /// Returns a shallow copy of this [DwPushRuntimeState]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  DwPushRuntimeState copyWith({
    int? id,
    String? workerName,
    bool? isPaused,
    DateTime? pausedUntil,
    DateTime? lastClaimedAt,
    DateTime? lastCompletedAt,
    DateTime? lastErrorAt,
    String? lastError,
    DateTime? updatedAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'dartway_push.DwPushRuntimeState',
      if (id != null) 'id': id,
      'workerName': workerName,
      'isPaused': isPaused,
      if (pausedUntil != null) 'pausedUntil': pausedUntil?.toJson(),
      if (lastClaimedAt != null) 'lastClaimedAt': lastClaimedAt?.toJson(),
      if (lastCompletedAt != null) 'lastCompletedAt': lastCompletedAt?.toJson(),
      if (lastErrorAt != null) 'lastErrorAt': lastErrorAt?.toJson(),
      if (lastError != null) 'lastError': lastError,
      'updatedAt': updatedAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static DwPushRuntimeStateInclude include() {
    return DwPushRuntimeStateInclude._();
  }

  static DwPushRuntimeStateIncludeList includeList({
    _i1.WhereExpressionBuilder<DwPushRuntimeStateTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<DwPushRuntimeStateTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<DwPushRuntimeStateTable>? orderByList,
    DwPushRuntimeStateInclude? include,
  }) {
    return DwPushRuntimeStateIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(DwPushRuntimeState.t),
      orderDescending: orderDescending,
      orderByList: orderByList?.call(DwPushRuntimeState.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _DwPushRuntimeStateImpl extends DwPushRuntimeState {
  _DwPushRuntimeStateImpl({
    int? id,
    required String workerName,
    bool? isPaused,
    DateTime? pausedUntil,
    DateTime? lastClaimedAt,
    DateTime? lastCompletedAt,
    DateTime? lastErrorAt,
    String? lastError,
    DateTime? updatedAt,
  }) : super._(
         id: id,
         workerName: workerName,
         isPaused: isPaused,
         pausedUntil: pausedUntil,
         lastClaimedAt: lastClaimedAt,
         lastCompletedAt: lastCompletedAt,
         lastErrorAt: lastErrorAt,
         lastError: lastError,
         updatedAt: updatedAt,
       );

  /// Returns a shallow copy of this [DwPushRuntimeState]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  DwPushRuntimeState copyWith({
    Object? id = _Undefined,
    String? workerName,
    bool? isPaused,
    Object? pausedUntil = _Undefined,
    Object? lastClaimedAt = _Undefined,
    Object? lastCompletedAt = _Undefined,
    Object? lastErrorAt = _Undefined,
    Object? lastError = _Undefined,
    DateTime? updatedAt,
  }) {
    return DwPushRuntimeState(
      id: id is int? ? id : this.id,
      workerName: workerName ?? this.workerName,
      isPaused: isPaused ?? this.isPaused,
      pausedUntil: pausedUntil is DateTime? ? pausedUntil : this.pausedUntil,
      lastClaimedAt: lastClaimedAt is DateTime?
          ? lastClaimedAt
          : this.lastClaimedAt,
      lastCompletedAt: lastCompletedAt is DateTime?
          ? lastCompletedAt
          : this.lastCompletedAt,
      lastErrorAt: lastErrorAt is DateTime? ? lastErrorAt : this.lastErrorAt,
      lastError: lastError is String? ? lastError : this.lastError,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class DwPushRuntimeStateUpdateTable
    extends _i1.UpdateTable<DwPushRuntimeStateTable> {
  DwPushRuntimeStateUpdateTable(super.table);

  _i1.ColumnValue<String, String> workerName(String value) => _i1.ColumnValue(
    table.workerName,
    value,
  );

  _i1.ColumnValue<bool, bool> isPaused(bool value) => _i1.ColumnValue(
    table.isPaused,
    value,
  );

  _i1.ColumnValue<DateTime, DateTime> pausedUntil(DateTime? value) =>
      _i1.ColumnValue(
        table.pausedUntil,
        value,
      );

  _i1.ColumnValue<DateTime, DateTime> lastClaimedAt(DateTime? value) =>
      _i1.ColumnValue(
        table.lastClaimedAt,
        value,
      );

  _i1.ColumnValue<DateTime, DateTime> lastCompletedAt(DateTime? value) =>
      _i1.ColumnValue(
        table.lastCompletedAt,
        value,
      );

  _i1.ColumnValue<DateTime, DateTime> lastErrorAt(DateTime? value) =>
      _i1.ColumnValue(
        table.lastErrorAt,
        value,
      );

  _i1.ColumnValue<String, String> lastError(String? value) => _i1.ColumnValue(
    table.lastError,
    value,
  );

  _i1.ColumnValue<DateTime, DateTime> updatedAt(DateTime value) =>
      _i1.ColumnValue(
        table.updatedAt,
        value,
      );
}

class DwPushRuntimeStateTable extends _i1.Table<int?> {
  DwPushRuntimeStateTable({super.tableRelation})
    : super(tableName: 'dw_push_runtime_state') {
    updateTable = DwPushRuntimeStateUpdateTable(this);
    workerName = _i1.ColumnString(
      'workerName',
      this,
    );
    isPaused = _i1.ColumnBool(
      'isPaused',
      this,
      hasDefault: true,
    );
    pausedUntil = _i1.ColumnDateTime(
      'pausedUntil',
      this,
    );
    lastClaimedAt = _i1.ColumnDateTime(
      'lastClaimedAt',
      this,
    );
    lastCompletedAt = _i1.ColumnDateTime(
      'lastCompletedAt',
      this,
    );
    lastErrorAt = _i1.ColumnDateTime(
      'lastErrorAt',
      this,
    );
    lastError = _i1.ColumnString(
      'lastError',
      this,
    );
    updatedAt = _i1.ColumnDateTime(
      'updatedAt',
      this,
      hasDefault: true,
    );
  }

  late final DwPushRuntimeStateUpdateTable updateTable;

  late final _i1.ColumnString workerName;

  late final _i1.ColumnBool isPaused;

  late final _i1.ColumnDateTime pausedUntil;

  late final _i1.ColumnDateTime lastClaimedAt;

  late final _i1.ColumnDateTime lastCompletedAt;

  late final _i1.ColumnDateTime lastErrorAt;

  late final _i1.ColumnString lastError;

  late final _i1.ColumnDateTime updatedAt;

  @override
  List<_i1.Column> get columns => [
    id,
    workerName,
    isPaused,
    pausedUntil,
    lastClaimedAt,
    lastCompletedAt,
    lastErrorAt,
    lastError,
    updatedAt,
  ];
}

class DwPushRuntimeStateInclude extends _i1.IncludeObject {
  DwPushRuntimeStateInclude._();

  @override
  Map<String, _i1.Include?> get includes => {};

  @override
  _i1.Table<int?> get table => DwPushRuntimeState.t;
}

class DwPushRuntimeStateIncludeList extends _i1.IncludeList {
  DwPushRuntimeStateIncludeList._({
    _i1.WhereExpressionBuilder<DwPushRuntimeStateTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(DwPushRuntimeState.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<int?> get table => DwPushRuntimeState.t;
}

class DwPushRuntimeStateRepository {
  const DwPushRuntimeStateRepository._();

  /// Returns a list of [DwPushRuntimeState]s matching the given query parameters.
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
  Future<List<DwPushRuntimeState>> find(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<DwPushRuntimeStateTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<DwPushRuntimeStateTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<DwPushRuntimeStateTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<DwPushRuntimeState>(
      where: where?.call(DwPushRuntimeState.t),
      orderBy: orderBy?.call(DwPushRuntimeState.t),
      orderByList: orderByList?.call(DwPushRuntimeState.t),
      orderDescending: orderDescending,
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [DwPushRuntimeState] matching the given query parameters.
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
  Future<DwPushRuntimeState?> findFirstRow(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<DwPushRuntimeStateTable>? where,
    int? offset,
    _i1.OrderByBuilder<DwPushRuntimeStateTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<DwPushRuntimeStateTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<DwPushRuntimeState>(
      where: where?.call(DwPushRuntimeState.t),
      orderBy: orderBy?.call(DwPushRuntimeState.t),
      orderByList: orderByList?.call(DwPushRuntimeState.t),
      orderDescending: orderDescending,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [DwPushRuntimeState] by its [id] or null if no such row exists.
  Future<DwPushRuntimeState?> findById(
    _i1.DatabaseSession session,
    int id, {
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<DwPushRuntimeState>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [DwPushRuntimeState]s in the list and returns the inserted rows.
  ///
  /// The returned [DwPushRuntimeState]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  ///
  /// If [ignoreConflicts] is set to `true`, rows that conflict with existing
  /// rows are silently skipped, and only the successfully inserted rows are
  /// returned.
  Future<List<DwPushRuntimeState>> insert(
    _i1.DatabaseSession session,
    List<DwPushRuntimeState> rows, {
    _i1.Transaction? transaction,
    bool ignoreConflicts = false,
  }) async {
    return session.db.insert<DwPushRuntimeState>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
    );
  }

  /// Inserts a single [DwPushRuntimeState] and returns the inserted row.
  ///
  /// The returned [DwPushRuntimeState] will have its `id` field set.
  Future<DwPushRuntimeState> insertRow(
    _i1.DatabaseSession session,
    DwPushRuntimeState row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<DwPushRuntimeState>(
      row,
      transaction: transaction,
    );
  }

  /// Updates all [DwPushRuntimeState]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  Future<List<DwPushRuntimeState>> update(
    _i1.DatabaseSession session,
    List<DwPushRuntimeState> rows, {
    _i1.ColumnSelections<DwPushRuntimeStateTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.update<DwPushRuntimeState>(
      rows,
      columns: columns?.call(DwPushRuntimeState.t),
      transaction: transaction,
    );
  }

  /// Updates a single [DwPushRuntimeState]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<DwPushRuntimeState> updateRow(
    _i1.DatabaseSession session,
    DwPushRuntimeState row, {
    _i1.ColumnSelections<DwPushRuntimeStateTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<DwPushRuntimeState>(
      row,
      columns: columns?.call(DwPushRuntimeState.t),
      transaction: transaction,
    );
  }

  /// Updates a single [DwPushRuntimeState] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<DwPushRuntimeState?> updateById(
    _i1.DatabaseSession session,
    int id, {
    required _i1.ColumnValueListBuilder<DwPushRuntimeStateUpdateTable>
    columnValues,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateById<DwPushRuntimeState>(
      id,
      columnValues: columnValues(DwPushRuntimeState.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [DwPushRuntimeState]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  Future<List<DwPushRuntimeState>> updateWhere(
    _i1.DatabaseSession session, {
    required _i1.ColumnValueListBuilder<DwPushRuntimeStateUpdateTable>
    columnValues,
    required _i1.WhereExpressionBuilder<DwPushRuntimeStateTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<DwPushRuntimeStateTable>? orderBy,
    _i1.OrderByListBuilder<DwPushRuntimeStateTable>? orderByList,
    bool orderDescending = false,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateWhere<DwPushRuntimeState>(
      columnValues: columnValues(DwPushRuntimeState.t.updateTable),
      where: where(DwPushRuntimeState.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(DwPushRuntimeState.t),
      orderByList: orderByList?.call(DwPushRuntimeState.t),
      orderDescending: orderDescending,
      transaction: transaction,
    );
  }

  /// Deletes all [DwPushRuntimeState]s in the list and returns the deleted rows.
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  Future<List<DwPushRuntimeState>> delete(
    _i1.DatabaseSession session,
    List<DwPushRuntimeState> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<DwPushRuntimeState>(
      rows,
      transaction: transaction,
    );
  }

  /// Deletes a single [DwPushRuntimeState].
  Future<DwPushRuntimeState> deleteRow(
    _i1.DatabaseSession session,
    DwPushRuntimeState row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<DwPushRuntimeState>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  Future<List<DwPushRuntimeState>> deleteWhere(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<DwPushRuntimeStateTable> where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteWhere<DwPushRuntimeState>(
      where: where(DwPushRuntimeState.t),
      transaction: transaction,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<DwPushRuntimeStateTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<DwPushRuntimeState>(
      where: where?.call(DwPushRuntimeState.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [DwPushRuntimeState] rows matching the [where] expression.
  Future<void> lockRows(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<DwPushRuntimeStateTable> where,
    required _i1.LockMode lockMode,
    required _i1.Transaction transaction,
    _i1.LockBehavior lockBehavior = _i1.LockBehavior.wait,
  }) async {
    return session.db.lockRows<DwPushRuntimeState>(
      where: where(DwPushRuntimeState.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
