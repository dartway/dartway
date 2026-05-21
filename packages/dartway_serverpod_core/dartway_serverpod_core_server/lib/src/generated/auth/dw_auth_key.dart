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

/// Provides a method of access for a user to authenticate with the server.
abstract class DwAuthKey
    implements _i1.TableRow<int?>, _i1.ProtocolSerialization {
  DwAuthKey._({
    this.id,
    required this.userId,
    required this.hash,
    this.key,
  });

  factory DwAuthKey({
    int? id,
    required int userId,
    required String hash,
    String? key,
  }) = _DwAuthKeyImpl;

  factory DwAuthKey.fromJson(Map<String, dynamic> jsonSerialization) {
    return DwAuthKey(
      id: jsonSerialization['id'] as int?,
      userId: jsonSerialization['userId'] as int,
      hash: jsonSerialization['hash'] as String,
      key: jsonSerialization['key'] as String?,
    );
  }

  static final t = DwAuthKeyTable();

  static const db = DwAuthKeyRepository._();

  @override
  int? id;

  /// The id of the user to provide access to.
  int userId;

  /// The hashed version of the key.
  String hash;

  /// The key sent to the server to authenticate.
  String? key;

  @override
  _i1.Table<int?> get table => t;

  /// Returns a shallow copy of this [DwAuthKey]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  DwAuthKey copyWith({
    int? id,
    int? userId,
    String? hash,
    String? key,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'dartway_serverpod_core.DwAuthKey',
      if (id != null) 'id': id,
      'userId': userId,
      'hash': hash,
      if (key != null) 'key': key,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'dartway_serverpod_core.DwAuthKey',
      if (id != null) 'id': id,
      'userId': userId,
      'hash': hash,
      if (key != null) 'key': key,
    };
  }

  static DwAuthKeyInclude include() {
    return DwAuthKeyInclude._();
  }

  static DwAuthKeyIncludeList includeList({
    _i1.WhereExpressionBuilder<DwAuthKeyTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<DwAuthKeyTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<DwAuthKeyTable>? orderByList,
    DwAuthKeyInclude? include,
  }) {
    return DwAuthKeyIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(DwAuthKey.t),
      orderDescending: orderDescending,
      orderByList: orderByList?.call(DwAuthKey.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _DwAuthKeyImpl extends DwAuthKey {
  _DwAuthKeyImpl({
    int? id,
    required int userId,
    required String hash,
    String? key,
  }) : super._(
         id: id,
         userId: userId,
         hash: hash,
         key: key,
       );

  /// Returns a shallow copy of this [DwAuthKey]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  DwAuthKey copyWith({
    Object? id = _Undefined,
    int? userId,
    String? hash,
    Object? key = _Undefined,
  }) {
    return DwAuthKey(
      id: id is int? ? id : this.id,
      userId: userId ?? this.userId,
      hash: hash ?? this.hash,
      key: key is String? ? key : this.key,
    );
  }
}

class DwAuthKeyUpdateTable extends _i1.UpdateTable<DwAuthKeyTable> {
  DwAuthKeyUpdateTable(super.table);

  _i1.ColumnValue<int, int> userId(int value) => _i1.ColumnValue(
    table.userId,
    value,
  );

  _i1.ColumnValue<String, String> hash(String value) => _i1.ColumnValue(
    table.hash,
    value,
  );
}

class DwAuthKeyTable extends _i1.Table<int?> {
  DwAuthKeyTable({super.tableRelation}) : super(tableName: 'dw_auth_key') {
    updateTable = DwAuthKeyUpdateTable(this);
    userId = _i1.ColumnInt(
      'userId',
      this,
    );
    hash = _i1.ColumnString(
      'hash',
      this,
    );
  }

  late final DwAuthKeyUpdateTable updateTable;

  /// The id of the user to provide access to.
  late final _i1.ColumnInt userId;

  /// The hashed version of the key.
  late final _i1.ColumnString hash;

  @override
  List<_i1.Column> get columns => [
    id,
    userId,
    hash,
  ];
}

class DwAuthKeyInclude extends _i1.IncludeObject {
  DwAuthKeyInclude._();

  @override
  Map<String, _i1.Include?> get includes => {};

  @override
  _i1.Table<int?> get table => DwAuthKey.t;
}

class DwAuthKeyIncludeList extends _i1.IncludeList {
  DwAuthKeyIncludeList._({
    _i1.WhereExpressionBuilder<DwAuthKeyTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(DwAuthKey.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<int?> get table => DwAuthKey.t;
}

class DwAuthKeyRepository {
  const DwAuthKeyRepository._();

  /// Returns a list of [DwAuthKey]s matching the given query parameters.
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
  Future<List<DwAuthKey>> find(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<DwAuthKeyTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<DwAuthKeyTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<DwAuthKeyTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<DwAuthKey>(
      where: where?.call(DwAuthKey.t),
      orderBy: orderBy?.call(DwAuthKey.t),
      orderByList: orderByList?.call(DwAuthKey.t),
      orderDescending: orderDescending,
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [DwAuthKey] matching the given query parameters.
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
  Future<DwAuthKey?> findFirstRow(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<DwAuthKeyTable>? where,
    int? offset,
    _i1.OrderByBuilder<DwAuthKeyTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<DwAuthKeyTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<DwAuthKey>(
      where: where?.call(DwAuthKey.t),
      orderBy: orderBy?.call(DwAuthKey.t),
      orderByList: orderByList?.call(DwAuthKey.t),
      orderDescending: orderDescending,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [DwAuthKey] by its [id] or null if no such row exists.
  Future<DwAuthKey?> findById(
    _i1.DatabaseSession session,
    int id, {
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<DwAuthKey>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [DwAuthKey]s in the list and returns the inserted rows.
  ///
  /// The returned [DwAuthKey]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  ///
  /// If [ignoreConflicts] is set to `true`, rows that conflict with existing
  /// rows are silently skipped, and only the successfully inserted rows are
  /// returned.
  Future<List<DwAuthKey>> insert(
    _i1.DatabaseSession session,
    List<DwAuthKey> rows, {
    _i1.Transaction? transaction,
    bool ignoreConflicts = false,
  }) async {
    return session.db.insert<DwAuthKey>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
    );
  }

  /// Inserts a single [DwAuthKey] and returns the inserted row.
  ///
  /// The returned [DwAuthKey] will have its `id` field set.
  Future<DwAuthKey> insertRow(
    _i1.DatabaseSession session,
    DwAuthKey row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<DwAuthKey>(
      row,
      transaction: transaction,
    );
  }

  /// Updates all [DwAuthKey]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  Future<List<DwAuthKey>> update(
    _i1.DatabaseSession session,
    List<DwAuthKey> rows, {
    _i1.ColumnSelections<DwAuthKeyTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.update<DwAuthKey>(
      rows,
      columns: columns?.call(DwAuthKey.t),
      transaction: transaction,
    );
  }

  /// Updates a single [DwAuthKey]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<DwAuthKey> updateRow(
    _i1.DatabaseSession session,
    DwAuthKey row, {
    _i1.ColumnSelections<DwAuthKeyTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<DwAuthKey>(
      row,
      columns: columns?.call(DwAuthKey.t),
      transaction: transaction,
    );
  }

  /// Updates a single [DwAuthKey] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<DwAuthKey?> updateById(
    _i1.DatabaseSession session,
    int id, {
    required _i1.ColumnValueListBuilder<DwAuthKeyUpdateTable> columnValues,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateById<DwAuthKey>(
      id,
      columnValues: columnValues(DwAuthKey.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [DwAuthKey]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  Future<List<DwAuthKey>> updateWhere(
    _i1.DatabaseSession session, {
    required _i1.ColumnValueListBuilder<DwAuthKeyUpdateTable> columnValues,
    required _i1.WhereExpressionBuilder<DwAuthKeyTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<DwAuthKeyTable>? orderBy,
    _i1.OrderByListBuilder<DwAuthKeyTable>? orderByList,
    bool orderDescending = false,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateWhere<DwAuthKey>(
      columnValues: columnValues(DwAuthKey.t.updateTable),
      where: where(DwAuthKey.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(DwAuthKey.t),
      orderByList: orderByList?.call(DwAuthKey.t),
      orderDescending: orderDescending,
      transaction: transaction,
    );
  }

  /// Deletes all [DwAuthKey]s in the list and returns the deleted rows.
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  Future<List<DwAuthKey>> delete(
    _i1.DatabaseSession session,
    List<DwAuthKey> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<DwAuthKey>(
      rows,
      transaction: transaction,
    );
  }

  /// Deletes a single [DwAuthKey].
  Future<DwAuthKey> deleteRow(
    _i1.DatabaseSession session,
    DwAuthKey row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<DwAuthKey>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  Future<List<DwAuthKey>> deleteWhere(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<DwAuthKeyTable> where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteWhere<DwAuthKey>(
      where: where(DwAuthKey.t),
      transaction: transaction,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<DwAuthKeyTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<DwAuthKey>(
      where: where?.call(DwAuthKey.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [DwAuthKey] rows matching the [where] expression.
  Future<void> lockRows(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<DwAuthKeyTable> where,
    required _i1.LockMode lockMode,
    required _i1.Transaction transaction,
    _i1.LockBehavior lockBehavior = _i1.LockBehavior.wait,
  }) async {
    return session.db.lockRows<DwAuthKey>(
      where: where(DwAuthKey.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
