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

abstract class ClubService
    implements _i1.TableRow<int?>, _i1.ProtocolSerialization {
  ClubService._({
    this.id,
    required this.title,
    required this.description,
    required this.durationMinutes,
    required this.price,
    this.imageUrl,
  });

  factory ClubService({
    int? id,
    required String title,
    required String description,
    required int durationMinutes,
    required int price,
    String? imageUrl,
  }) = _ClubServiceImpl;

  factory ClubService.fromJson(Map<String, dynamic> jsonSerialization) {
    return ClubService(
      id: jsonSerialization['id'] as int?,
      title: jsonSerialization['title'] as String,
      description: jsonSerialization['description'] as String,
      durationMinutes: jsonSerialization['durationMinutes'] as int,
      price: jsonSerialization['price'] as int,
      imageUrl: jsonSerialization['imageUrl'] as String?,
    );
  }

  static final t = ClubServiceTable();

  static const db = ClubServiceRepository._();

  @override
  int? id;

  String title;

  String description;

  int durationMinutes;

  int price;

  String? imageUrl;

  @override
  _i1.Table<int?> get table => t;

  /// Returns a shallow copy of this [ClubService]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  ClubService copyWith({
    int? id,
    String? title,
    String? description,
    int? durationMinutes,
    int? price,
    String? imageUrl,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'ClubService',
      if (id != null) 'id': id,
      'title': title,
      'description': description,
      'durationMinutes': durationMinutes,
      'price': price,
      if (imageUrl != null) 'imageUrl': imageUrl,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'ClubService',
      if (id != null) 'id': id,
      'title': title,
      'description': description,
      'durationMinutes': durationMinutes,
      'price': price,
      if (imageUrl != null) 'imageUrl': imageUrl,
    };
  }

  static ClubServiceInclude include() {
    return ClubServiceInclude._();
  }

  static ClubServiceIncludeList includeList({
    _i1.WhereExpressionBuilder<ClubServiceTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<ClubServiceTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<ClubServiceTable>? orderByList,
    ClubServiceInclude? include,
  }) {
    return ClubServiceIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(ClubService.t),
      orderDescending: orderDescending,
      orderByList: orderByList?.call(ClubService.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _ClubServiceImpl extends ClubService {
  _ClubServiceImpl({
    int? id,
    required String title,
    required String description,
    required int durationMinutes,
    required int price,
    String? imageUrl,
  }) : super._(
         id: id,
         title: title,
         description: description,
         durationMinutes: durationMinutes,
         price: price,
         imageUrl: imageUrl,
       );

  /// Returns a shallow copy of this [ClubService]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  ClubService copyWith({
    Object? id = _Undefined,
    String? title,
    String? description,
    int? durationMinutes,
    int? price,
    Object? imageUrl = _Undefined,
  }) {
    return ClubService(
      id: id is int? ? id : this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      price: price ?? this.price,
      imageUrl: imageUrl is String? ? imageUrl : this.imageUrl,
    );
  }
}

class ClubServiceUpdateTable extends _i1.UpdateTable<ClubServiceTable> {
  ClubServiceUpdateTable(super.table);

  _i1.ColumnValue<String, String> title(String value) => _i1.ColumnValue(
    table.title,
    value,
  );

  _i1.ColumnValue<String, String> description(String value) => _i1.ColumnValue(
    table.description,
    value,
  );

  _i1.ColumnValue<int, int> durationMinutes(int value) => _i1.ColumnValue(
    table.durationMinutes,
    value,
  );

  _i1.ColumnValue<int, int> price(int value) => _i1.ColumnValue(
    table.price,
    value,
  );

  _i1.ColumnValue<String, String> imageUrl(String? value) => _i1.ColumnValue(
    table.imageUrl,
    value,
  );
}

class ClubServiceTable extends _i1.Table<int?> {
  ClubServiceTable({super.tableRelation}) : super(tableName: 'club_service') {
    updateTable = ClubServiceUpdateTable(this);
    title = _i1.ColumnString(
      'title',
      this,
    );
    description = _i1.ColumnString(
      'description',
      this,
    );
    durationMinutes = _i1.ColumnInt(
      'durationMinutes',
      this,
    );
    price = _i1.ColumnInt(
      'price',
      this,
    );
    imageUrl = _i1.ColumnString(
      'imageUrl',
      this,
    );
  }

  late final ClubServiceUpdateTable updateTable;

  late final _i1.ColumnString title;

  late final _i1.ColumnString description;

  late final _i1.ColumnInt durationMinutes;

  late final _i1.ColumnInt price;

  late final _i1.ColumnString imageUrl;

  @override
  List<_i1.Column> get columns => [
    id,
    title,
    description,
    durationMinutes,
    price,
    imageUrl,
  ];
}

class ClubServiceInclude extends _i1.IncludeObject {
  ClubServiceInclude._();

  @override
  Map<String, _i1.Include?> get includes => {};

  @override
  _i1.Table<int?> get table => ClubService.t;
}

class ClubServiceIncludeList extends _i1.IncludeList {
  ClubServiceIncludeList._({
    _i1.WhereExpressionBuilder<ClubServiceTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(ClubService.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<int?> get table => ClubService.t;
}

class ClubServiceRepository {
  const ClubServiceRepository._();

  /// Returns a list of [ClubService]s matching the given query parameters.
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
  Future<List<ClubService>> find(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<ClubServiceTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<ClubServiceTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<ClubServiceTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<ClubService>(
      where: where?.call(ClubService.t),
      orderBy: orderBy?.call(ClubService.t),
      orderByList: orderByList?.call(ClubService.t),
      orderDescending: orderDescending,
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [ClubService] matching the given query parameters.
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
  Future<ClubService?> findFirstRow(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<ClubServiceTable>? where,
    int? offset,
    _i1.OrderByBuilder<ClubServiceTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<ClubServiceTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<ClubService>(
      where: where?.call(ClubService.t),
      orderBy: orderBy?.call(ClubService.t),
      orderByList: orderByList?.call(ClubService.t),
      orderDescending: orderDescending,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [ClubService] by its [id] or null if no such row exists.
  Future<ClubService?> findById(
    _i1.DatabaseSession session,
    int id, {
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<ClubService>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [ClubService]s in the list and returns the inserted rows.
  ///
  /// The returned [ClubService]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  ///
  /// If [ignoreConflicts] is set to `true`, rows that conflict with existing
  /// rows are silently skipped, and only the successfully inserted rows are
  /// returned.
  Future<List<ClubService>> insert(
    _i1.DatabaseSession session,
    List<ClubService> rows, {
    _i1.Transaction? transaction,
    bool ignoreConflicts = false,
  }) async {
    return session.db.insert<ClubService>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
    );
  }

  /// Inserts a single [ClubService] and returns the inserted row.
  ///
  /// The returned [ClubService] will have its `id` field set.
  Future<ClubService> insertRow(
    _i1.DatabaseSession session,
    ClubService row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<ClubService>(
      row,
      transaction: transaction,
    );
  }

  /// Updates all [ClubService]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  Future<List<ClubService>> update(
    _i1.DatabaseSession session,
    List<ClubService> rows, {
    _i1.ColumnSelections<ClubServiceTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.update<ClubService>(
      rows,
      columns: columns?.call(ClubService.t),
      transaction: transaction,
    );
  }

  /// Updates a single [ClubService]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<ClubService> updateRow(
    _i1.DatabaseSession session,
    ClubService row, {
    _i1.ColumnSelections<ClubServiceTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<ClubService>(
      row,
      columns: columns?.call(ClubService.t),
      transaction: transaction,
    );
  }

  /// Updates a single [ClubService] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<ClubService?> updateById(
    _i1.DatabaseSession session,
    int id, {
    required _i1.ColumnValueListBuilder<ClubServiceUpdateTable> columnValues,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateById<ClubService>(
      id,
      columnValues: columnValues(ClubService.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [ClubService]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  Future<List<ClubService>> updateWhere(
    _i1.DatabaseSession session, {
    required _i1.ColumnValueListBuilder<ClubServiceUpdateTable> columnValues,
    required _i1.WhereExpressionBuilder<ClubServiceTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<ClubServiceTable>? orderBy,
    _i1.OrderByListBuilder<ClubServiceTable>? orderByList,
    bool orderDescending = false,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateWhere<ClubService>(
      columnValues: columnValues(ClubService.t.updateTable),
      where: where(ClubService.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(ClubService.t),
      orderByList: orderByList?.call(ClubService.t),
      orderDescending: orderDescending,
      transaction: transaction,
    );
  }

  /// Deletes all [ClubService]s in the list and returns the deleted rows.
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  Future<List<ClubService>> delete(
    _i1.DatabaseSession session,
    List<ClubService> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<ClubService>(
      rows,
      transaction: transaction,
    );
  }

  /// Deletes a single [ClubService].
  Future<ClubService> deleteRow(
    _i1.DatabaseSession session,
    ClubService row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<ClubService>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  Future<List<ClubService>> deleteWhere(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<ClubServiceTable> where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteWhere<ClubService>(
      where: where(ClubService.t),
      transaction: transaction,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<ClubServiceTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<ClubService>(
      where: where?.call(ClubService.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [ClubService] rows matching the [where] expression.
  Future<void> lockRows(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<ClubServiceTable> where,
    required _i1.LockMode lockMode,
    required _i1.Transaction transaction,
    _i1.LockBehavior lockBehavior = _i1.LockBehavior.wait,
  }) async {
    return session.db.lockRows<ClubService>(
      where: where(ClubService.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
