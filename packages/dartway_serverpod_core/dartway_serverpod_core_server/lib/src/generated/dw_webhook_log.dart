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

abstract class DwWebServerLog
    implements _i1.TableRow<int?>, _i1.ProtocolSerialization {
  DwWebServerLog._({
    this.id,
    required this.createdAt,
    required this.method,
    required this.url,
    this.headers,
    this.body,
    this.statusCode,
    this.status,
    this.error,
    this.durationMs,
    this.handler,
    this.ip,
  });

  factory DwWebServerLog({
    int? id,
    required DateTime createdAt,
    required String method,
    required String url,
    String? headers,
    String? body,
    int? statusCode,
    String? status,
    String? error,
    int? durationMs,
    String? handler,
    String? ip,
  }) = _DwWebServerLogImpl;

  factory DwWebServerLog.fromJson(Map<String, dynamic> jsonSerialization) {
    return DwWebServerLog(
      id: jsonSerialization['id'] as int?,
      createdAt:
          _i1.DateTimeJsonExtension.fromJson(jsonSerialization['createdAt']),
      method: jsonSerialization['method'] as String,
      url: jsonSerialization['url'] as String,
      headers: jsonSerialization['headers'] as String?,
      body: jsonSerialization['body'] as String?,
      statusCode: jsonSerialization['statusCode'] as int?,
      status: jsonSerialization['status'] as String?,
      error: jsonSerialization['error'] as String?,
      durationMs: jsonSerialization['durationMs'] as int?,
      handler: jsonSerialization['handler'] as String?,
      ip: jsonSerialization['ip'] as String?,
    );
  }

  static final t = DwWebServerLogTable();

  static const db = DwWebServerLogRepository._();

  @override
  int? id;

  DateTime createdAt;

  String method;

  String url;

  String? headers;

  String? body;

  int? statusCode;

  String? status;

  String? error;

  int? durationMs;

  String? handler;

  String? ip;

  @override
  _i1.Table<int?> get table => t;

  /// Returns a shallow copy of this [DwWebServerLog]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  DwWebServerLog copyWith({
    int? id,
    DateTime? createdAt,
    String? method,
    String? url,
    String? headers,
    String? body,
    int? statusCode,
    String? status,
    String? error,
    int? durationMs,
    String? handler,
    String? ip,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'createdAt': createdAt.toJson(),
      'method': method,
      'url': url,
      if (headers != null) 'headers': headers,
      if (body != null) 'body': body,
      if (statusCode != null) 'statusCode': statusCode,
      if (status != null) 'status': status,
      if (error != null) 'error': error,
      if (durationMs != null) 'durationMs': durationMs,
      if (handler != null) 'handler': handler,
      if (ip != null) 'ip': ip,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      if (id != null) 'id': id,
      'createdAt': createdAt.toJson(),
      'method': method,
      'url': url,
      if (headers != null) 'headers': headers,
      if (body != null) 'body': body,
      if (statusCode != null) 'statusCode': statusCode,
      if (status != null) 'status': status,
      if (error != null) 'error': error,
      if (durationMs != null) 'durationMs': durationMs,
      if (handler != null) 'handler': handler,
      if (ip != null) 'ip': ip,
    };
  }

  static DwWebServerLogInclude include() {
    return DwWebServerLogInclude._();
  }

  static DwWebServerLogIncludeList includeList({
    _i1.WhereExpressionBuilder<DwWebServerLogTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<DwWebServerLogTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<DwWebServerLogTable>? orderByList,
    DwWebServerLogInclude? include,
  }) {
    return DwWebServerLogIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(DwWebServerLog.t),
      orderDescending: orderDescending,
      orderByList: orderByList?.call(DwWebServerLog.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _DwWebServerLogImpl extends DwWebServerLog {
  _DwWebServerLogImpl({
    int? id,
    required DateTime createdAt,
    required String method,
    required String url,
    String? headers,
    String? body,
    int? statusCode,
    String? status,
    String? error,
    int? durationMs,
    String? handler,
    String? ip,
  }) : super._(
          id: id,
          createdAt: createdAt,
          method: method,
          url: url,
          headers: headers,
          body: body,
          statusCode: statusCode,
          status: status,
          error: error,
          durationMs: durationMs,
          handler: handler,
          ip: ip,
        );

  /// Returns a shallow copy of this [DwWebServerLog]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  DwWebServerLog copyWith({
    Object? id = _Undefined,
    DateTime? createdAt,
    String? method,
    String? url,
    Object? headers = _Undefined,
    Object? body = _Undefined,
    Object? statusCode = _Undefined,
    Object? status = _Undefined,
    Object? error = _Undefined,
    Object? durationMs = _Undefined,
    Object? handler = _Undefined,
    Object? ip = _Undefined,
  }) {
    return DwWebServerLog(
      id: id is int? ? id : this.id,
      createdAt: createdAt ?? this.createdAt,
      method: method ?? this.method,
      url: url ?? this.url,
      headers: headers is String? ? headers : this.headers,
      body: body is String? ? body : this.body,
      statusCode: statusCode is int? ? statusCode : this.statusCode,
      status: status is String? ? status : this.status,
      error: error is String? ? error : this.error,
      durationMs: durationMs is int? ? durationMs : this.durationMs,
      handler: handler is String? ? handler : this.handler,
      ip: ip is String? ? ip : this.ip,
    );
  }
}

class DwWebServerLogTable extends _i1.Table<int?> {
  DwWebServerLogTable({super.tableRelation})
      : super(tableName: 'dw_web_server_log') {
    createdAt = _i1.ColumnDateTime(
      'createdAt',
      this,
    );
    method = _i1.ColumnString(
      'method',
      this,
    );
    url = _i1.ColumnString(
      'url',
      this,
    );
    headers = _i1.ColumnString(
      'headers',
      this,
    );
    body = _i1.ColumnString(
      'body',
      this,
    );
    statusCode = _i1.ColumnInt(
      'statusCode',
      this,
    );
    status = _i1.ColumnString(
      'status',
      this,
    );
    error = _i1.ColumnString(
      'error',
      this,
    );
    durationMs = _i1.ColumnInt(
      'durationMs',
      this,
    );
    handler = _i1.ColumnString(
      'handler',
      this,
    );
    ip = _i1.ColumnString(
      'ip',
      this,
    );
  }

  late final _i1.ColumnDateTime createdAt;

  late final _i1.ColumnString method;

  late final _i1.ColumnString url;

  late final _i1.ColumnString headers;

  late final _i1.ColumnString body;

  late final _i1.ColumnInt statusCode;

  late final _i1.ColumnString status;

  late final _i1.ColumnString error;

  late final _i1.ColumnInt durationMs;

  late final _i1.ColumnString handler;

  late final _i1.ColumnString ip;

  @override
  List<_i1.Column> get columns => [
        id,
        createdAt,
        method,
        url,
        headers,
        body,
        statusCode,
        status,
        error,
        durationMs,
        handler,
        ip,
      ];
}

class DwWebServerLogInclude extends _i1.IncludeObject {
  DwWebServerLogInclude._();

  @override
  Map<String, _i1.Include?> get includes => {};

  @override
  _i1.Table<int?> get table => DwWebServerLog.t;
}

class DwWebServerLogIncludeList extends _i1.IncludeList {
  DwWebServerLogIncludeList._({
    _i1.WhereExpressionBuilder<DwWebServerLogTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(DwWebServerLog.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<int?> get table => DwWebServerLog.t;
}

class DwWebServerLogRepository {
  const DwWebServerLogRepository._();

  /// Returns a list of [DwWebServerLog]s matching the given query parameters.
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
  Future<List<DwWebServerLog>> find(
    _i1.Session session, {
    _i1.WhereExpressionBuilder<DwWebServerLogTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<DwWebServerLogTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<DwWebServerLogTable>? orderByList,
    _i1.Transaction? transaction,
  }) async {
    return session.db.find<DwWebServerLog>(
      where: where?.call(DwWebServerLog.t),
      orderBy: orderBy?.call(DwWebServerLog.t),
      orderByList: orderByList?.call(DwWebServerLog.t),
      orderDescending: orderDescending,
      limit: limit,
      offset: offset,
      transaction: transaction,
    );
  }

  /// Returns the first matching [DwWebServerLog] matching the given query parameters.
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
  Future<DwWebServerLog?> findFirstRow(
    _i1.Session session, {
    _i1.WhereExpressionBuilder<DwWebServerLogTable>? where,
    int? offset,
    _i1.OrderByBuilder<DwWebServerLogTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<DwWebServerLogTable>? orderByList,
    _i1.Transaction? transaction,
  }) async {
    return session.db.findFirstRow<DwWebServerLog>(
      where: where?.call(DwWebServerLog.t),
      orderBy: orderBy?.call(DwWebServerLog.t),
      orderByList: orderByList?.call(DwWebServerLog.t),
      orderDescending: orderDescending,
      offset: offset,
      transaction: transaction,
    );
  }

  /// Finds a single [DwWebServerLog] by its [id] or null if no such row exists.
  Future<DwWebServerLog?> findById(
    _i1.Session session,
    int id, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.findById<DwWebServerLog>(
      id,
      transaction: transaction,
    );
  }

  /// Inserts all [DwWebServerLog]s in the list and returns the inserted rows.
  ///
  /// The returned [DwWebServerLog]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  Future<List<DwWebServerLog>> insert(
    _i1.Session session,
    List<DwWebServerLog> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insert<DwWebServerLog>(
      rows,
      transaction: transaction,
    );
  }

  /// Inserts a single [DwWebServerLog] and returns the inserted row.
  ///
  /// The returned [DwWebServerLog] will have its `id` field set.
  Future<DwWebServerLog> insertRow(
    _i1.Session session,
    DwWebServerLog row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<DwWebServerLog>(
      row,
      transaction: transaction,
    );
  }

  /// Updates all [DwWebServerLog]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  Future<List<DwWebServerLog>> update(
    _i1.Session session,
    List<DwWebServerLog> rows, {
    _i1.ColumnSelections<DwWebServerLogTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.update<DwWebServerLog>(
      rows,
      columns: columns?.call(DwWebServerLog.t),
      transaction: transaction,
    );
  }

  /// Updates a single [DwWebServerLog]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<DwWebServerLog> updateRow(
    _i1.Session session,
    DwWebServerLog row, {
    _i1.ColumnSelections<DwWebServerLogTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<DwWebServerLog>(
      row,
      columns: columns?.call(DwWebServerLog.t),
      transaction: transaction,
    );
  }

  /// Deletes all [DwWebServerLog]s in the list and returns the deleted rows.
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  Future<List<DwWebServerLog>> delete(
    _i1.Session session,
    List<DwWebServerLog> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<DwWebServerLog>(
      rows,
      transaction: transaction,
    );
  }

  /// Deletes a single [DwWebServerLog].
  Future<DwWebServerLog> deleteRow(
    _i1.Session session,
    DwWebServerLog row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<DwWebServerLog>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  Future<List<DwWebServerLog>> deleteWhere(
    _i1.Session session, {
    required _i1.WhereExpressionBuilder<DwWebServerLogTable> where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteWhere<DwWebServerLog>(
      where: where(DwWebServerLog.t),
      transaction: transaction,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.Session session, {
    _i1.WhereExpressionBuilder<DwWebServerLogTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<DwWebServerLog>(
      where: where?.call(DwWebServerLog.t),
      limit: limit,
      transaction: transaction,
    );
  }
}
