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

/// Bounded hourly counters used instead of permanent delivery history.
abstract class DwPushMetricBucket
    implements _i1.TableRow<int?>, _i1.ProtocolSerialization {
  DwPushMetricBucket._({
    this.id,
    required this.bucketStart,
    required this.category,
    required this.outcome,
    int? eventCount,
    DateTime? updatedAt,
  }) : eventCount = eventCount ?? 0,
       updatedAt = updatedAt ?? DateTime.now();

  factory DwPushMetricBucket({
    int? id,
    required DateTime bucketStart,
    required String category,
    required String outcome,
    int? eventCount,
    DateTime? updatedAt,
  }) = _DwPushMetricBucketImpl;

  factory DwPushMetricBucket.fromJson(Map<String, dynamic> jsonSerialization) {
    return DwPushMetricBucket(
      id: jsonSerialization['id'] as int?,
      bucketStart: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['bucketStart'],
      ),
      category: jsonSerialization['category'] as String,
      outcome: jsonSerialization['outcome'] as String,
      eventCount: jsonSerialization['eventCount'] as int?,
      updatedAt: jsonSerialization['updatedAt'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(jsonSerialization['updatedAt']),
    );
  }

  static final t = DwPushMetricBucketTable();

  static const db = DwPushMetricBucketRepository._();

  @override
  int? id;

  DateTime bucketStart;

  String category;

  String outcome;

  int eventCount;

  DateTime updatedAt;

  @override
  _i1.Table<int?> get table => t;

  /// Returns a shallow copy of this [DwPushMetricBucket]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  DwPushMetricBucket copyWith({
    int? id,
    DateTime? bucketStart,
    String? category,
    String? outcome,
    int? eventCount,
    DateTime? updatedAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'dartway_push.DwPushMetricBucket',
      if (id != null) 'id': id,
      'bucketStart': bucketStart.toJson(),
      'category': category,
      'outcome': outcome,
      'eventCount': eventCount,
      'updatedAt': updatedAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static DwPushMetricBucketInclude include() {
    return DwPushMetricBucketInclude._();
  }

  static DwPushMetricBucketIncludeList includeList({
    _i1.WhereExpressionBuilder<DwPushMetricBucketTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<DwPushMetricBucketTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<DwPushMetricBucketTable>? orderByList,
    DwPushMetricBucketInclude? include,
  }) {
    return DwPushMetricBucketIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(DwPushMetricBucket.t),
      orderDescending: orderDescending,
      orderByList: orderByList?.call(DwPushMetricBucket.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _DwPushMetricBucketImpl extends DwPushMetricBucket {
  _DwPushMetricBucketImpl({
    int? id,
    required DateTime bucketStart,
    required String category,
    required String outcome,
    int? eventCount,
    DateTime? updatedAt,
  }) : super._(
         id: id,
         bucketStart: bucketStart,
         category: category,
         outcome: outcome,
         eventCount: eventCount,
         updatedAt: updatedAt,
       );

  /// Returns a shallow copy of this [DwPushMetricBucket]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  DwPushMetricBucket copyWith({
    Object? id = _Undefined,
    DateTime? bucketStart,
    String? category,
    String? outcome,
    int? eventCount,
    DateTime? updatedAt,
  }) {
    return DwPushMetricBucket(
      id: id is int? ? id : this.id,
      bucketStart: bucketStart ?? this.bucketStart,
      category: category ?? this.category,
      outcome: outcome ?? this.outcome,
      eventCount: eventCount ?? this.eventCount,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class DwPushMetricBucketUpdateTable
    extends _i1.UpdateTable<DwPushMetricBucketTable> {
  DwPushMetricBucketUpdateTable(super.table);

  _i1.ColumnValue<DateTime, DateTime> bucketStart(DateTime value) =>
      _i1.ColumnValue(
        table.bucketStart,
        value,
      );

  _i1.ColumnValue<String, String> category(String value) => _i1.ColumnValue(
    table.category,
    value,
  );

  _i1.ColumnValue<String, String> outcome(String value) => _i1.ColumnValue(
    table.outcome,
    value,
  );

  _i1.ColumnValue<int, int> eventCount(int value) => _i1.ColumnValue(
    table.eventCount,
    value,
  );

  _i1.ColumnValue<DateTime, DateTime> updatedAt(DateTime value) =>
      _i1.ColumnValue(
        table.updatedAt,
        value,
      );
}

class DwPushMetricBucketTable extends _i1.Table<int?> {
  DwPushMetricBucketTable({super.tableRelation})
    : super(tableName: 'dw_push_metric_bucket') {
    updateTable = DwPushMetricBucketUpdateTable(this);
    bucketStart = _i1.ColumnDateTime(
      'bucketStart',
      this,
    );
    category = _i1.ColumnString(
      'category',
      this,
    );
    outcome = _i1.ColumnString(
      'outcome',
      this,
    );
    eventCount = _i1.ColumnInt(
      'eventCount',
      this,
      hasDefault: true,
    );
    updatedAt = _i1.ColumnDateTime(
      'updatedAt',
      this,
      hasDefault: true,
    );
  }

  late final DwPushMetricBucketUpdateTable updateTable;

  late final _i1.ColumnDateTime bucketStart;

  late final _i1.ColumnString category;

  late final _i1.ColumnString outcome;

  late final _i1.ColumnInt eventCount;

  late final _i1.ColumnDateTime updatedAt;

  @override
  List<_i1.Column> get columns => [
    id,
    bucketStart,
    category,
    outcome,
    eventCount,
    updatedAt,
  ];
}

class DwPushMetricBucketInclude extends _i1.IncludeObject {
  DwPushMetricBucketInclude._();

  @override
  Map<String, _i1.Include?> get includes => {};

  @override
  _i1.Table<int?> get table => DwPushMetricBucket.t;
}

class DwPushMetricBucketIncludeList extends _i1.IncludeList {
  DwPushMetricBucketIncludeList._({
    _i1.WhereExpressionBuilder<DwPushMetricBucketTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(DwPushMetricBucket.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<int?> get table => DwPushMetricBucket.t;
}

class DwPushMetricBucketRepository {
  const DwPushMetricBucketRepository._();

  /// Returns a list of [DwPushMetricBucket]s matching the given query parameters.
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
  Future<List<DwPushMetricBucket>> find(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<DwPushMetricBucketTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<DwPushMetricBucketTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<DwPushMetricBucketTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<DwPushMetricBucket>(
      where: where?.call(DwPushMetricBucket.t),
      orderBy: orderBy?.call(DwPushMetricBucket.t),
      orderByList: orderByList?.call(DwPushMetricBucket.t),
      orderDescending: orderDescending,
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [DwPushMetricBucket] matching the given query parameters.
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
  Future<DwPushMetricBucket?> findFirstRow(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<DwPushMetricBucketTable>? where,
    int? offset,
    _i1.OrderByBuilder<DwPushMetricBucketTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<DwPushMetricBucketTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<DwPushMetricBucket>(
      where: where?.call(DwPushMetricBucket.t),
      orderBy: orderBy?.call(DwPushMetricBucket.t),
      orderByList: orderByList?.call(DwPushMetricBucket.t),
      orderDescending: orderDescending,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [DwPushMetricBucket] by its [id] or null if no such row exists.
  Future<DwPushMetricBucket?> findById(
    _i1.DatabaseSession session,
    int id, {
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<DwPushMetricBucket>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [DwPushMetricBucket]s in the list and returns the inserted rows.
  ///
  /// The returned [DwPushMetricBucket]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  ///
  /// If [ignoreConflicts] is set to `true`, rows that conflict with existing
  /// rows are silently skipped, and only the successfully inserted rows are
  /// returned.
  Future<List<DwPushMetricBucket>> insert(
    _i1.DatabaseSession session,
    List<DwPushMetricBucket> rows, {
    _i1.Transaction? transaction,
    bool ignoreConflicts = false,
  }) async {
    return session.db.insert<DwPushMetricBucket>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
    );
  }

  /// Inserts a single [DwPushMetricBucket] and returns the inserted row.
  ///
  /// The returned [DwPushMetricBucket] will have its `id` field set.
  Future<DwPushMetricBucket> insertRow(
    _i1.DatabaseSession session,
    DwPushMetricBucket row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<DwPushMetricBucket>(
      row,
      transaction: transaction,
    );
  }

  /// Updates all [DwPushMetricBucket]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  Future<List<DwPushMetricBucket>> update(
    _i1.DatabaseSession session,
    List<DwPushMetricBucket> rows, {
    _i1.ColumnSelections<DwPushMetricBucketTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.update<DwPushMetricBucket>(
      rows,
      columns: columns?.call(DwPushMetricBucket.t),
      transaction: transaction,
    );
  }

  /// Updates a single [DwPushMetricBucket]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<DwPushMetricBucket> updateRow(
    _i1.DatabaseSession session,
    DwPushMetricBucket row, {
    _i1.ColumnSelections<DwPushMetricBucketTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<DwPushMetricBucket>(
      row,
      columns: columns?.call(DwPushMetricBucket.t),
      transaction: transaction,
    );
  }

  /// Updates a single [DwPushMetricBucket] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<DwPushMetricBucket?> updateById(
    _i1.DatabaseSession session,
    int id, {
    required _i1.ColumnValueListBuilder<DwPushMetricBucketUpdateTable>
    columnValues,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateById<DwPushMetricBucket>(
      id,
      columnValues: columnValues(DwPushMetricBucket.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [DwPushMetricBucket]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  Future<List<DwPushMetricBucket>> updateWhere(
    _i1.DatabaseSession session, {
    required _i1.ColumnValueListBuilder<DwPushMetricBucketUpdateTable>
    columnValues,
    required _i1.WhereExpressionBuilder<DwPushMetricBucketTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<DwPushMetricBucketTable>? orderBy,
    _i1.OrderByListBuilder<DwPushMetricBucketTable>? orderByList,
    bool orderDescending = false,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateWhere<DwPushMetricBucket>(
      columnValues: columnValues(DwPushMetricBucket.t.updateTable),
      where: where(DwPushMetricBucket.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(DwPushMetricBucket.t),
      orderByList: orderByList?.call(DwPushMetricBucket.t),
      orderDescending: orderDescending,
      transaction: transaction,
    );
  }

  /// Deletes all [DwPushMetricBucket]s in the list and returns the deleted rows.
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  Future<List<DwPushMetricBucket>> delete(
    _i1.DatabaseSession session,
    List<DwPushMetricBucket> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<DwPushMetricBucket>(
      rows,
      transaction: transaction,
    );
  }

  /// Deletes a single [DwPushMetricBucket].
  Future<DwPushMetricBucket> deleteRow(
    _i1.DatabaseSession session,
    DwPushMetricBucket row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<DwPushMetricBucket>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  Future<List<DwPushMetricBucket>> deleteWhere(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<DwPushMetricBucketTable> where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteWhere<DwPushMetricBucket>(
      where: where(DwPushMetricBucket.t),
      transaction: transaction,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<DwPushMetricBucketTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<DwPushMetricBucket>(
      where: where?.call(DwPushMetricBucket.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [DwPushMetricBucket] rows matching the [where] expression.
  Future<void> lockRows(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<DwPushMetricBucketTable> where,
    required _i1.LockMode lockMode,
    required _i1.Transaction transaction,
    _i1.LockBehavior lockBehavior = _i1.LockBehavior.wait,
  }) async {
    return session.db.lockRows<DwPushMetricBucket>(
      where: where(DwPushMetricBucket.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
