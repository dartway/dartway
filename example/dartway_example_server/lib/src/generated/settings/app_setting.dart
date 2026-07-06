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

abstract class AppSetting
    implements _i1.TableRow<int?>, _i1.ProtocolSerialization {
  AppSetting._({
    this.id,
    required this.settingKey,
    required this.settingValue,
  });

  factory AppSetting({
    int? id,
    required String settingKey,
    required String settingValue,
  }) = _AppSettingImpl;

  factory AppSetting.fromJson(Map<String, dynamic> jsonSerialization) {
    return AppSetting(
      id: jsonSerialization['id'] as int?,
      settingKey: jsonSerialization['settingKey'] as String,
      settingValue: jsonSerialization['settingValue'] as String,
    );
  }

  static final t = AppSettingTable();

  static const db = AppSettingRepository._();

  @override
  int? id;

  String settingKey;

  String settingValue;

  @override
  _i1.Table<int?> get table => t;

  /// Returns a shallow copy of this [AppSetting]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  AppSetting copyWith({
    int? id,
    String? settingKey,
    String? settingValue,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'AppSetting',
      if (id != null) 'id': id,
      'settingKey': settingKey,
      'settingValue': settingValue,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'AppSetting',
      if (id != null) 'id': id,
      'settingKey': settingKey,
      'settingValue': settingValue,
    };
  }

  static AppSettingInclude include() {
    return AppSettingInclude._();
  }

  static AppSettingIncludeList includeList({
    _i1.WhereExpressionBuilder<AppSettingTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<AppSettingTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<AppSettingTable>? orderByList,
    AppSettingInclude? include,
  }) {
    return AppSettingIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(AppSetting.t),
      orderDescending: orderDescending,
      orderByList: orderByList?.call(AppSetting.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _AppSettingImpl extends AppSetting {
  _AppSettingImpl({
    int? id,
    required String settingKey,
    required String settingValue,
  }) : super._(
         id: id,
         settingKey: settingKey,
         settingValue: settingValue,
       );

  /// Returns a shallow copy of this [AppSetting]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  AppSetting copyWith({
    Object? id = _Undefined,
    String? settingKey,
    String? settingValue,
  }) {
    return AppSetting(
      id: id is int? ? id : this.id,
      settingKey: settingKey ?? this.settingKey,
      settingValue: settingValue ?? this.settingValue,
    );
  }
}

class AppSettingUpdateTable extends _i1.UpdateTable<AppSettingTable> {
  AppSettingUpdateTable(super.table);

  _i1.ColumnValue<String, String> settingKey(String value) => _i1.ColumnValue(
    table.settingKey,
    value,
  );

  _i1.ColumnValue<String, String> settingValue(String value) => _i1.ColumnValue(
    table.settingValue,
    value,
  );
}

class AppSettingTable extends _i1.Table<int?> {
  AppSettingTable({super.tableRelation}) : super(tableName: 'app_setting') {
    updateTable = AppSettingUpdateTable(this);
    settingKey = _i1.ColumnString(
      'settingKey',
      this,
    );
    settingValue = _i1.ColumnString(
      'settingValue',
      this,
    );
  }

  late final AppSettingUpdateTable updateTable;

  late final _i1.ColumnString settingKey;

  late final _i1.ColumnString settingValue;

  @override
  List<_i1.Column> get columns => [
    id,
    settingKey,
    settingValue,
  ];
}

class AppSettingInclude extends _i1.IncludeObject {
  AppSettingInclude._();

  @override
  Map<String, _i1.Include?> get includes => {};

  @override
  _i1.Table<int?> get table => AppSetting.t;
}

class AppSettingIncludeList extends _i1.IncludeList {
  AppSettingIncludeList._({
    _i1.WhereExpressionBuilder<AppSettingTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(AppSetting.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<int?> get table => AppSetting.t;
}

class AppSettingRepository {
  const AppSettingRepository._();

  /// Returns a list of [AppSetting]s matching the given query parameters.
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
  Future<List<AppSetting>> find(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<AppSettingTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<AppSettingTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<AppSettingTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<AppSetting>(
      where: where?.call(AppSetting.t),
      orderBy: orderBy?.call(AppSetting.t),
      orderByList: orderByList?.call(AppSetting.t),
      orderDescending: orderDescending,
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [AppSetting] matching the given query parameters.
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
  Future<AppSetting?> findFirstRow(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<AppSettingTable>? where,
    int? offset,
    _i1.OrderByBuilder<AppSettingTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<AppSettingTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<AppSetting>(
      where: where?.call(AppSetting.t),
      orderBy: orderBy?.call(AppSetting.t),
      orderByList: orderByList?.call(AppSetting.t),
      orderDescending: orderDescending,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [AppSetting] by its [id] or null if no such row exists.
  Future<AppSetting?> findById(
    _i1.DatabaseSession session,
    int id, {
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<AppSetting>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [AppSetting]s in the list and returns the inserted rows.
  ///
  /// The returned [AppSetting]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  ///
  /// If [ignoreConflicts] is set to `true`, rows that conflict with existing
  /// rows are silently skipped, and only the successfully inserted rows are
  /// returned.
  Future<List<AppSetting>> insert(
    _i1.DatabaseSession session,
    List<AppSetting> rows, {
    _i1.Transaction? transaction,
    bool ignoreConflicts = false,
  }) async {
    return session.db.insert<AppSetting>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
    );
  }

  /// Inserts a single [AppSetting] and returns the inserted row.
  ///
  /// The returned [AppSetting] will have its `id` field set.
  Future<AppSetting> insertRow(
    _i1.DatabaseSession session,
    AppSetting row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<AppSetting>(
      row,
      transaction: transaction,
    );
  }

  /// Updates all [AppSetting]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  Future<List<AppSetting>> update(
    _i1.DatabaseSession session,
    List<AppSetting> rows, {
    _i1.ColumnSelections<AppSettingTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.update<AppSetting>(
      rows,
      columns: columns?.call(AppSetting.t),
      transaction: transaction,
    );
  }

  /// Updates a single [AppSetting]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<AppSetting> updateRow(
    _i1.DatabaseSession session,
    AppSetting row, {
    _i1.ColumnSelections<AppSettingTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<AppSetting>(
      row,
      columns: columns?.call(AppSetting.t),
      transaction: transaction,
    );
  }

  /// Updates a single [AppSetting] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<AppSetting?> updateById(
    _i1.DatabaseSession session,
    int id, {
    required _i1.ColumnValueListBuilder<AppSettingUpdateTable> columnValues,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateById<AppSetting>(
      id,
      columnValues: columnValues(AppSetting.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [AppSetting]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  Future<List<AppSetting>> updateWhere(
    _i1.DatabaseSession session, {
    required _i1.ColumnValueListBuilder<AppSettingUpdateTable> columnValues,
    required _i1.WhereExpressionBuilder<AppSettingTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<AppSettingTable>? orderBy,
    _i1.OrderByListBuilder<AppSettingTable>? orderByList,
    bool orderDescending = false,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateWhere<AppSetting>(
      columnValues: columnValues(AppSetting.t.updateTable),
      where: where(AppSetting.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(AppSetting.t),
      orderByList: orderByList?.call(AppSetting.t),
      orderDescending: orderDescending,
      transaction: transaction,
    );
  }

  /// Deletes all [AppSetting]s in the list and returns the deleted rows.
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  Future<List<AppSetting>> delete(
    _i1.DatabaseSession session,
    List<AppSetting> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<AppSetting>(
      rows,
      transaction: transaction,
    );
  }

  /// Deletes a single [AppSetting].
  Future<AppSetting> deleteRow(
    _i1.DatabaseSession session,
    AppSetting row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<AppSetting>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  Future<List<AppSetting>> deleteWhere(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<AppSettingTable> where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteWhere<AppSetting>(
      where: where(AppSetting.t),
      transaction: transaction,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<AppSettingTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<AppSetting>(
      where: where?.call(AppSetting.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [AppSetting] rows matching the [where] expression.
  Future<void> lockRows(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<AppSettingTable> where,
    required _i1.LockMode lockMode,
    required _i1.Transaction transaction,
    _i1.LockBehavior lockBehavior = _i1.LockBehavior.wait,
  }) async {
    return session.db.lockRows<AppSetting>(
      where: where(AppSetting.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
