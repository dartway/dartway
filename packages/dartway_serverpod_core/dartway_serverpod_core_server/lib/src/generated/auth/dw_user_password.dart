/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod/serverpod.dart' as _i1;

abstract class DwUserPassword
    implements _i1.TableRow<int?>, _i1.ProtocolSerialization {
  DwUserPassword._({
    this.id,
    required this.userId,
    required this.passwordHash,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DwUserPassword({
    int? id,
    required int userId,
    required String passwordHash,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _DwUserPasswordImpl;

  factory DwUserPassword.fromJson(Map<String, dynamic> jsonSerialization) {
    return DwUserPassword(
      id: jsonSerialization['id'] as int?,
      userId: jsonSerialization['userId'] as int,
      passwordHash: jsonSerialization['passwordHash'] as String,
      createdAt:
          _i1.DateTimeJsonExtension.fromJson(jsonSerialization['createdAt']),
      updatedAt:
          _i1.DateTimeJsonExtension.fromJson(jsonSerialization['updatedAt']),
    );
  }

  static final t = DwUserPasswordTable();

  static const db = DwUserPasswordRepository._();

  @override
  int? id;

  int userId;

  String passwordHash;

  DateTime createdAt;

  DateTime updatedAt;

  @override
  _i1.Table<int?> get table => t;

  /// Returns a shallow copy of this [DwUserPassword]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  DwUserPassword copyWith({
    int? id,
    int? userId,
    String? passwordHash,
    DateTime? createdAt,
    DateTime? updatedAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'userId': userId,
      'passwordHash': passwordHash,
      'createdAt': createdAt.toJson(),
      'updatedAt': updatedAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      if (id != null) 'id': id,
      'userId': userId,
      'passwordHash': passwordHash,
      'createdAt': createdAt.toJson(),
      'updatedAt': updatedAt.toJson(),
    };
  }

  static DwUserPasswordInclude include() {
    return DwUserPasswordInclude._();
  }

  static DwUserPasswordIncludeList includeList({
    _i1.WhereExpressionBuilder<DwUserPasswordTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<DwUserPasswordTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<DwUserPasswordTable>? orderByList,
    DwUserPasswordInclude? include,
  }) {
    return DwUserPasswordIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(DwUserPassword.t),
      orderDescending: orderDescending,
      orderByList: orderByList?.call(DwUserPassword.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _DwUserPasswordImpl extends DwUserPassword {
  _DwUserPasswordImpl({
    int? id,
    required int userId,
    required String passwordHash,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) : super._(
          id: id,
          userId: userId,
          passwordHash: passwordHash,
          createdAt: createdAt,
          updatedAt: updatedAt,
        );

  /// Returns a shallow copy of this [DwUserPassword]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  DwUserPassword copyWith({
    Object? id = _Undefined,
    int? userId,
    String? passwordHash,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DwUserPassword(
      id: id is int? ? id : this.id,
      userId: userId ?? this.userId,
      passwordHash: passwordHash ?? this.passwordHash,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class DwUserPasswordTable extends _i1.Table<int?> {
  DwUserPasswordTable({super.tableRelation})
      : super(tableName: 'dw_user_password') {
    userId = _i1.ColumnInt(
      'userId',
      this,
    );
    passwordHash = _i1.ColumnString(
      'passwordHash',
      this,
    );
    createdAt = _i1.ColumnDateTime(
      'createdAt',
      this,
    );
    updatedAt = _i1.ColumnDateTime(
      'updatedAt',
      this,
    );
  }

  late final _i1.ColumnInt userId;

  late final _i1.ColumnString passwordHash;

  late final _i1.ColumnDateTime createdAt;

  late final _i1.ColumnDateTime updatedAt;

  @override
  List<_i1.Column> get columns => [
        id,
        userId,
        passwordHash,
        createdAt,
        updatedAt,
      ];
}

class DwUserPasswordInclude extends _i1.IncludeObject {
  DwUserPasswordInclude._();

  @override
  Map<String, _i1.Include?> get includes => {};

  @override
  _i1.Table<int?> get table => DwUserPassword.t;
}

class DwUserPasswordIncludeList extends _i1.IncludeList {
  DwUserPasswordIncludeList._({
    _i1.WhereExpressionBuilder<DwUserPasswordTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(DwUserPassword.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<int?> get table => DwUserPassword.t;
}

class DwUserPasswordRepository {
  const DwUserPasswordRepository._();

  /// Returns a list of [DwUserPassword]s matching the given query parameters.
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
  Future<List<DwUserPassword>> find(
    _i1.Session session, {
    _i1.WhereExpressionBuilder<DwUserPasswordTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<DwUserPasswordTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<DwUserPasswordTable>? orderByList,
    _i1.Transaction? transaction,
  }) async {
    return session.db.find<DwUserPassword>(
      where: where?.call(DwUserPassword.t),
      orderBy: orderBy?.call(DwUserPassword.t),
      orderByList: orderByList?.call(DwUserPassword.t),
      orderDescending: orderDescending,
      limit: limit,
      offset: offset,
      transaction: transaction,
    );
  }

  /// Returns the first matching [DwUserPassword] matching the given query parameters.
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
  Future<DwUserPassword?> findFirstRow(
    _i1.Session session, {
    _i1.WhereExpressionBuilder<DwUserPasswordTable>? where,
    int? offset,
    _i1.OrderByBuilder<DwUserPasswordTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<DwUserPasswordTable>? orderByList,
    _i1.Transaction? transaction,
  }) async {
    return session.db.findFirstRow<DwUserPassword>(
      where: where?.call(DwUserPassword.t),
      orderBy: orderBy?.call(DwUserPassword.t),
      orderByList: orderByList?.call(DwUserPassword.t),
      orderDescending: orderDescending,
      offset: offset,
      transaction: transaction,
    );
  }

  /// Finds a single [DwUserPassword] by its [id] or null if no such row exists.
  Future<DwUserPassword?> findById(
    _i1.Session session,
    int id, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.findById<DwUserPassword>(
      id,
      transaction: transaction,
    );
  }

  /// Inserts all [DwUserPassword]s in the list and returns the inserted rows.
  ///
  /// The returned [DwUserPassword]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  Future<List<DwUserPassword>> insert(
    _i1.Session session,
    List<DwUserPassword> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insert<DwUserPassword>(
      rows,
      transaction: transaction,
    );
  }

  /// Inserts a single [DwUserPassword] and returns the inserted row.
  ///
  /// The returned [DwUserPassword] will have its `id` field set.
  Future<DwUserPassword> insertRow(
    _i1.Session session,
    DwUserPassword row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<DwUserPassword>(
      row,
      transaction: transaction,
    );
  }

  /// Updates all [DwUserPassword]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  Future<List<DwUserPassword>> update(
    _i1.Session session,
    List<DwUserPassword> rows, {
    _i1.ColumnSelections<DwUserPasswordTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.update<DwUserPassword>(
      rows,
      columns: columns?.call(DwUserPassword.t),
      transaction: transaction,
    );
  }

  /// Updates a single [DwUserPassword]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<DwUserPassword> updateRow(
    _i1.Session session,
    DwUserPassword row, {
    _i1.ColumnSelections<DwUserPasswordTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<DwUserPassword>(
      row,
      columns: columns?.call(DwUserPassword.t),
      transaction: transaction,
    );
  }

  /// Deletes all [DwUserPassword]s in the list and returns the deleted rows.
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  Future<List<DwUserPassword>> delete(
    _i1.Session session,
    List<DwUserPassword> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<DwUserPassword>(
      rows,
      transaction: transaction,
    );
  }

  /// Deletes a single [DwUserPassword].
  Future<DwUserPassword> deleteRow(
    _i1.Session session,
    DwUserPassword row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<DwUserPassword>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  Future<List<DwUserPassword>> deleteWhere(
    _i1.Session session, {
    required _i1.WhereExpressionBuilder<DwUserPasswordTable> where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteWhere<DwUserPassword>(
      where: where(DwUserPassword.t),
      transaction: transaction,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.Session session, {
    _i1.WhereExpressionBuilder<DwUserPasswordTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<DwUserPassword>(
      where: where?.call(DwUserPassword.t),
      limit: limit,
      transaction: transaction,
    );
  }
}
