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

/// A device push token owned by the push module, keyed on an opaque recipient
/// id (the app's user id). Tokens are stored only after
/// DwDevicePushTokenPolicy normalization, so the UNIQUE(token) index is the
/// authoritative canonical-token key. Server-only: never sent to clients.
abstract class DwDevicePushToken
    implements _i1.TableRow<int?>, _i1.ProtocolSerialization {
  DwDevicePushToken._({
    this.id,
    required this.recipientId,
    required this.token,
    DateTime? createdAt,
    required this.updatedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory DwDevicePushToken({
    int? id,
    required int recipientId,
    required String token,
    DateTime? createdAt,
    required DateTime updatedAt,
  }) = _DwDevicePushTokenImpl;

  factory DwDevicePushToken.fromJson(Map<String, dynamic> jsonSerialization) {
    return DwDevicePushToken(
      id: jsonSerialization['id'] as int?,
      recipientId: jsonSerialization['recipientId'] as int,
      token: jsonSerialization['token'] as String,
      createdAt: jsonSerialization['createdAt'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(jsonSerialization['createdAt']),
      updatedAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['updatedAt'],
      ),
    );
  }

  static final t = DwDevicePushTokenTable();

  static const db = DwDevicePushTokenRepository._();

  @override
  int? id;

  int recipientId;

  String token;

  DateTime createdAt;

  DateTime updatedAt;

  @override
  _i1.Table<int?> get table => t;

  /// Returns a shallow copy of this [DwDevicePushToken]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  DwDevicePushToken copyWith({
    int? id,
    int? recipientId,
    String? token,
    DateTime? createdAt,
    DateTime? updatedAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'dartway_push.DwDevicePushToken',
      if (id != null) 'id': id,
      'recipientId': recipientId,
      'token': token,
      'createdAt': createdAt.toJson(),
      'updatedAt': updatedAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static DwDevicePushTokenInclude include() {
    return DwDevicePushTokenInclude._();
  }

  static DwDevicePushTokenIncludeList includeList({
    _i1.WhereExpressionBuilder<DwDevicePushTokenTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<DwDevicePushTokenTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<DwDevicePushTokenTable>? orderByList,
    DwDevicePushTokenInclude? include,
  }) {
    return DwDevicePushTokenIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(DwDevicePushToken.t),
      orderDescending: orderDescending,
      orderByList: orderByList?.call(DwDevicePushToken.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _DwDevicePushTokenImpl extends DwDevicePushToken {
  _DwDevicePushTokenImpl({
    int? id,
    required int recipientId,
    required String token,
    DateTime? createdAt,
    required DateTime updatedAt,
  }) : super._(
         id: id,
         recipientId: recipientId,
         token: token,
         createdAt: createdAt,
         updatedAt: updatedAt,
       );

  /// Returns a shallow copy of this [DwDevicePushToken]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  DwDevicePushToken copyWith({
    Object? id = _Undefined,
    int? recipientId,
    String? token,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DwDevicePushToken(
      id: id is int? ? id : this.id,
      recipientId: recipientId ?? this.recipientId,
      token: token ?? this.token,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class DwDevicePushTokenUpdateTable
    extends _i1.UpdateTable<DwDevicePushTokenTable> {
  DwDevicePushTokenUpdateTable(super.table);

  _i1.ColumnValue<int, int> recipientId(int value) => _i1.ColumnValue(
    table.recipientId,
    value,
  );

  _i1.ColumnValue<String, String> token(String value) => _i1.ColumnValue(
    table.token,
    value,
  );

  _i1.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _i1.ColumnValue(
        table.createdAt,
        value,
      );

  _i1.ColumnValue<DateTime, DateTime> updatedAt(DateTime value) =>
      _i1.ColumnValue(
        table.updatedAt,
        value,
      );
}

class DwDevicePushTokenTable extends _i1.Table<int?> {
  DwDevicePushTokenTable({super.tableRelation})
    : super(tableName: 'dw_device_push_token') {
    updateTable = DwDevicePushTokenUpdateTable(this);
    recipientId = _i1.ColumnInt(
      'recipientId',
      this,
    );
    token = _i1.ColumnString(
      'token',
      this,
    );
    createdAt = _i1.ColumnDateTime(
      'createdAt',
      this,
      hasDefault: true,
    );
    updatedAt = _i1.ColumnDateTime(
      'updatedAt',
      this,
    );
  }

  late final DwDevicePushTokenUpdateTable updateTable;

  late final _i1.ColumnInt recipientId;

  late final _i1.ColumnString token;

  late final _i1.ColumnDateTime createdAt;

  late final _i1.ColumnDateTime updatedAt;

  @override
  List<_i1.Column> get columns => [
    id,
    recipientId,
    token,
    createdAt,
    updatedAt,
  ];
}

class DwDevicePushTokenInclude extends _i1.IncludeObject {
  DwDevicePushTokenInclude._();

  @override
  Map<String, _i1.Include?> get includes => {};

  @override
  _i1.Table<int?> get table => DwDevicePushToken.t;
}

class DwDevicePushTokenIncludeList extends _i1.IncludeList {
  DwDevicePushTokenIncludeList._({
    _i1.WhereExpressionBuilder<DwDevicePushTokenTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(DwDevicePushToken.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<int?> get table => DwDevicePushToken.t;
}

class DwDevicePushTokenRepository {
  const DwDevicePushTokenRepository._();

  /// Returns a list of [DwDevicePushToken]s matching the given query parameters.
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
  Future<List<DwDevicePushToken>> find(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<DwDevicePushTokenTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<DwDevicePushTokenTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<DwDevicePushTokenTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<DwDevicePushToken>(
      where: where?.call(DwDevicePushToken.t),
      orderBy: orderBy?.call(DwDevicePushToken.t),
      orderByList: orderByList?.call(DwDevicePushToken.t),
      orderDescending: orderDescending,
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [DwDevicePushToken] matching the given query parameters.
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
  Future<DwDevicePushToken?> findFirstRow(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<DwDevicePushTokenTable>? where,
    int? offset,
    _i1.OrderByBuilder<DwDevicePushTokenTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<DwDevicePushTokenTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<DwDevicePushToken>(
      where: where?.call(DwDevicePushToken.t),
      orderBy: orderBy?.call(DwDevicePushToken.t),
      orderByList: orderByList?.call(DwDevicePushToken.t),
      orderDescending: orderDescending,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [DwDevicePushToken] by its [id] or null if no such row exists.
  Future<DwDevicePushToken?> findById(
    _i1.DatabaseSession session,
    int id, {
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<DwDevicePushToken>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [DwDevicePushToken]s in the list and returns the inserted rows.
  ///
  /// The returned [DwDevicePushToken]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  ///
  /// If [ignoreConflicts] is set to `true`, rows that conflict with existing
  /// rows are silently skipped, and only the successfully inserted rows are
  /// returned.
  Future<List<DwDevicePushToken>> insert(
    _i1.DatabaseSession session,
    List<DwDevicePushToken> rows, {
    _i1.Transaction? transaction,
    bool ignoreConflicts = false,
  }) async {
    return session.db.insert<DwDevicePushToken>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
    );
  }

  /// Inserts a single [DwDevicePushToken] and returns the inserted row.
  ///
  /// The returned [DwDevicePushToken] will have its `id` field set.
  Future<DwDevicePushToken> insertRow(
    _i1.DatabaseSession session,
    DwDevicePushToken row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<DwDevicePushToken>(
      row,
      transaction: transaction,
    );
  }

  /// Updates all [DwDevicePushToken]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  Future<List<DwDevicePushToken>> update(
    _i1.DatabaseSession session,
    List<DwDevicePushToken> rows, {
    _i1.ColumnSelections<DwDevicePushTokenTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.update<DwDevicePushToken>(
      rows,
      columns: columns?.call(DwDevicePushToken.t),
      transaction: transaction,
    );
  }

  /// Updates a single [DwDevicePushToken]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<DwDevicePushToken> updateRow(
    _i1.DatabaseSession session,
    DwDevicePushToken row, {
    _i1.ColumnSelections<DwDevicePushTokenTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<DwDevicePushToken>(
      row,
      columns: columns?.call(DwDevicePushToken.t),
      transaction: transaction,
    );
  }

  /// Updates a single [DwDevicePushToken] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<DwDevicePushToken?> updateById(
    _i1.DatabaseSession session,
    int id, {
    required _i1.ColumnValueListBuilder<DwDevicePushTokenUpdateTable>
    columnValues,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateById<DwDevicePushToken>(
      id,
      columnValues: columnValues(DwDevicePushToken.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [DwDevicePushToken]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  Future<List<DwDevicePushToken>> updateWhere(
    _i1.DatabaseSession session, {
    required _i1.ColumnValueListBuilder<DwDevicePushTokenUpdateTable>
    columnValues,
    required _i1.WhereExpressionBuilder<DwDevicePushTokenTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<DwDevicePushTokenTable>? orderBy,
    _i1.OrderByListBuilder<DwDevicePushTokenTable>? orderByList,
    bool orderDescending = false,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateWhere<DwDevicePushToken>(
      columnValues: columnValues(DwDevicePushToken.t.updateTable),
      where: where(DwDevicePushToken.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(DwDevicePushToken.t),
      orderByList: orderByList?.call(DwDevicePushToken.t),
      orderDescending: orderDescending,
      transaction: transaction,
    );
  }

  /// Deletes all [DwDevicePushToken]s in the list and returns the deleted rows.
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  Future<List<DwDevicePushToken>> delete(
    _i1.DatabaseSession session,
    List<DwDevicePushToken> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<DwDevicePushToken>(
      rows,
      transaction: transaction,
    );
  }

  /// Deletes a single [DwDevicePushToken].
  Future<DwDevicePushToken> deleteRow(
    _i1.DatabaseSession session,
    DwDevicePushToken row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<DwDevicePushToken>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  Future<List<DwDevicePushToken>> deleteWhere(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<DwDevicePushTokenTable> where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteWhere<DwDevicePushToken>(
      where: where(DwDevicePushToken.t),
      transaction: transaction,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<DwDevicePushTokenTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<DwDevicePushToken>(
      where: where?.call(DwDevicePushToken.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [DwDevicePushToken] rows matching the [where] expression.
  Future<void> lockRows(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<DwDevicePushTokenTable> where,
    required _i1.LockMode lockMode,
    required _i1.Transaction transaction,
    _i1.LockBehavior lockBehavior = _i1.LockBehavior.wait,
  }) async {
    return session.db.lockRows<DwDevicePushToken>(
      where: where(DwDevicePushToken.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
