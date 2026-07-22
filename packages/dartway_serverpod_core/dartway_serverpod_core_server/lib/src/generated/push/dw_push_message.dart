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
import 'package:dartway_serverpod_core_server/src/generated/protocol.dart'
    as _i2;

/// Immutable content stored once for all recipient deliveries.
abstract class DwPushMessage
    implements _i1.TableRow<int?>, _i1.ProtocolSerialization {
  DwPushMessage._({
    this.id,
    required this.deduplicationKey,
    required this.category,
    required this.title,
    this.body,
    this.imageUrl,
    this.data,
    DateTime? createdAt,
    this.audienceClosedAt,
    required this.scheduledAt,
    required this.expiresAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory DwPushMessage({
    int? id,
    required String deduplicationKey,
    required String category,
    required String title,
    String? body,
    String? imageUrl,
    Map<String, String>? data,
    DateTime? createdAt,
    DateTime? audienceClosedAt,
    required DateTime scheduledAt,
    required DateTime expiresAt,
  }) = _DwPushMessageImpl;

  factory DwPushMessage.fromJson(Map<String, dynamic> jsonSerialization) {
    return DwPushMessage(
      id: jsonSerialization['id'] as int?,
      deduplicationKey: jsonSerialization['deduplicationKey'] as String,
      category: jsonSerialization['category'] as String,
      title: jsonSerialization['title'] as String,
      body: jsonSerialization['body'] as String?,
      imageUrl: jsonSerialization['imageUrl'] as String?,
      data: jsonSerialization['data'] == null
          ? null
          : _i2.Protocol().deserialize<Map<String, String>>(
              jsonSerialization['data'],
            ),
      createdAt: jsonSerialization['createdAt'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(jsonSerialization['createdAt']),
      audienceClosedAt: jsonSerialization['audienceClosedAt'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(
              jsonSerialization['audienceClosedAt'],
            ),
      scheduledAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['scheduledAt'],
      ),
      expiresAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['expiresAt'],
      ),
    );
  }

  static final t = DwPushMessageTable();

  static const db = DwPushMessageRepository._();

  @override
  int? id;

  String deduplicationKey;

  String category;

  String title;

  String? body;

  String? imageUrl;

  Map<String, String>? data;

  DateTime createdAt;

  DateTime? audienceClosedAt;

  DateTime scheduledAt;

  DateTime expiresAt;

  @override
  _i1.Table<int?> get table => t;

  /// Returns a shallow copy of this [DwPushMessage]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  DwPushMessage copyWith({
    int? id,
    String? deduplicationKey,
    String? category,
    String? title,
    String? body,
    String? imageUrl,
    Map<String, String>? data,
    DateTime? createdAt,
    DateTime? audienceClosedAt,
    DateTime? scheduledAt,
    DateTime? expiresAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'dartway_serverpod_core.DwPushMessage',
      if (id != null) 'id': id,
      'deduplicationKey': deduplicationKey,
      'category': category,
      'title': title,
      if (body != null) 'body': body,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (data != null) 'data': data?.toJson(),
      'createdAt': createdAt.toJson(),
      if (audienceClosedAt != null)
        'audienceClosedAt': audienceClosedAt?.toJson(),
      'scheduledAt': scheduledAt.toJson(),
      'expiresAt': expiresAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static DwPushMessageInclude include() {
    return DwPushMessageInclude._();
  }

  static DwPushMessageIncludeList includeList({
    _i1.WhereExpressionBuilder<DwPushMessageTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<DwPushMessageTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<DwPushMessageTable>? orderByList,
    DwPushMessageInclude? include,
  }) {
    return DwPushMessageIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(DwPushMessage.t),
      orderDescending: orderDescending,
      orderByList: orderByList?.call(DwPushMessage.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _DwPushMessageImpl extends DwPushMessage {
  _DwPushMessageImpl({
    int? id,
    required String deduplicationKey,
    required String category,
    required String title,
    String? body,
    String? imageUrl,
    Map<String, String>? data,
    DateTime? createdAt,
    DateTime? audienceClosedAt,
    required DateTime scheduledAt,
    required DateTime expiresAt,
  }) : super._(
         id: id,
         deduplicationKey: deduplicationKey,
         category: category,
         title: title,
         body: body,
         imageUrl: imageUrl,
         data: data,
         createdAt: createdAt,
         audienceClosedAt: audienceClosedAt,
         scheduledAt: scheduledAt,
         expiresAt: expiresAt,
       );

  /// Returns a shallow copy of this [DwPushMessage]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  DwPushMessage copyWith({
    Object? id = _Undefined,
    String? deduplicationKey,
    String? category,
    String? title,
    Object? body = _Undefined,
    Object? imageUrl = _Undefined,
    Object? data = _Undefined,
    DateTime? createdAt,
    Object? audienceClosedAt = _Undefined,
    DateTime? scheduledAt,
    DateTime? expiresAt,
  }) {
    return DwPushMessage(
      id: id is int? ? id : this.id,
      deduplicationKey: deduplicationKey ?? this.deduplicationKey,
      category: category ?? this.category,
      title: title ?? this.title,
      body: body is String? ? body : this.body,
      imageUrl: imageUrl is String? ? imageUrl : this.imageUrl,
      data: data is Map<String, String>?
          ? data
          : this.data?.map(
              (
                key0,
                value0,
              ) => MapEntry(
                key0,
                value0,
              ),
            ),
      createdAt: createdAt ?? this.createdAt,
      audienceClosedAt: audienceClosedAt is DateTime?
          ? audienceClosedAt
          : this.audienceClosedAt,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }
}

class DwPushMessageUpdateTable extends _i1.UpdateTable<DwPushMessageTable> {
  DwPushMessageUpdateTable(super.table);

  _i1.ColumnValue<String, String> deduplicationKey(String value) =>
      _i1.ColumnValue(
        table.deduplicationKey,
        value,
      );

  _i1.ColumnValue<String, String> category(String value) => _i1.ColumnValue(
    table.category,
    value,
  );

  _i1.ColumnValue<String, String> title(String value) => _i1.ColumnValue(
    table.title,
    value,
  );

  _i1.ColumnValue<String, String> body(String? value) => _i1.ColumnValue(
    table.body,
    value,
  );

  _i1.ColumnValue<String, String> imageUrl(String? value) => _i1.ColumnValue(
    table.imageUrl,
    value,
  );

  _i1.ColumnValue<Map<String, String>, Map<String, String>> data(
    Map<String, String>? value,
  ) => _i1.ColumnValue(
    table.data,
    value,
  );

  _i1.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _i1.ColumnValue(
        table.createdAt,
        value,
      );

  _i1.ColumnValue<DateTime, DateTime> audienceClosedAt(DateTime? value) =>
      _i1.ColumnValue(
        table.audienceClosedAt,
        value,
      );

  _i1.ColumnValue<DateTime, DateTime> scheduledAt(DateTime value) =>
      _i1.ColumnValue(
        table.scheduledAt,
        value,
      );

  _i1.ColumnValue<DateTime, DateTime> expiresAt(DateTime value) =>
      _i1.ColumnValue(
        table.expiresAt,
        value,
      );
}

class DwPushMessageTable extends _i1.Table<int?> {
  DwPushMessageTable({super.tableRelation})
    : super(tableName: 'dw_push_message') {
    updateTable = DwPushMessageUpdateTable(this);
    deduplicationKey = _i1.ColumnString(
      'deduplicationKey',
      this,
    );
    category = _i1.ColumnString(
      'category',
      this,
    );
    title = _i1.ColumnString(
      'title',
      this,
    );
    body = _i1.ColumnString(
      'body',
      this,
    );
    imageUrl = _i1.ColumnString(
      'imageUrl',
      this,
    );
    data = _i1.ColumnSerializable<Map<String, String>>(
      'data',
      this,
    );
    createdAt = _i1.ColumnDateTime(
      'createdAt',
      this,
      hasDefault: true,
    );
    audienceClosedAt = _i1.ColumnDateTime(
      'audienceClosedAt',
      this,
    );
    scheduledAt = _i1.ColumnDateTime(
      'scheduledAt',
      this,
    );
    expiresAt = _i1.ColumnDateTime(
      'expiresAt',
      this,
    );
  }

  late final DwPushMessageUpdateTable updateTable;

  late final _i1.ColumnString deduplicationKey;

  late final _i1.ColumnString category;

  late final _i1.ColumnString title;

  late final _i1.ColumnString body;

  late final _i1.ColumnString imageUrl;

  late final _i1.ColumnSerializable<Map<String, String>> data;

  late final _i1.ColumnDateTime createdAt;

  late final _i1.ColumnDateTime audienceClosedAt;

  late final _i1.ColumnDateTime scheduledAt;

  late final _i1.ColumnDateTime expiresAt;

  @override
  List<_i1.Column> get columns => [
    id,
    deduplicationKey,
    category,
    title,
    body,
    imageUrl,
    data,
    createdAt,
    audienceClosedAt,
    scheduledAt,
    expiresAt,
  ];
}

class DwPushMessageInclude extends _i1.IncludeObject {
  DwPushMessageInclude._();

  @override
  Map<String, _i1.Include?> get includes => {};

  @override
  _i1.Table<int?> get table => DwPushMessage.t;
}

class DwPushMessageIncludeList extends _i1.IncludeList {
  DwPushMessageIncludeList._({
    _i1.WhereExpressionBuilder<DwPushMessageTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(DwPushMessage.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<int?> get table => DwPushMessage.t;
}

class DwPushMessageRepository {
  const DwPushMessageRepository._();

  /// Returns a list of [DwPushMessage]s matching the given query parameters.
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
  Future<List<DwPushMessage>> find(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<DwPushMessageTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<DwPushMessageTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<DwPushMessageTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<DwPushMessage>(
      where: where?.call(DwPushMessage.t),
      orderBy: orderBy?.call(DwPushMessage.t),
      orderByList: orderByList?.call(DwPushMessage.t),
      orderDescending: orderDescending,
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [DwPushMessage] matching the given query parameters.
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
  Future<DwPushMessage?> findFirstRow(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<DwPushMessageTable>? where,
    int? offset,
    _i1.OrderByBuilder<DwPushMessageTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<DwPushMessageTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<DwPushMessage>(
      where: where?.call(DwPushMessage.t),
      orderBy: orderBy?.call(DwPushMessage.t),
      orderByList: orderByList?.call(DwPushMessage.t),
      orderDescending: orderDescending,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [DwPushMessage] by its [id] or null if no such row exists.
  Future<DwPushMessage?> findById(
    _i1.DatabaseSession session,
    int id, {
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<DwPushMessage>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [DwPushMessage]s in the list and returns the inserted rows.
  ///
  /// The returned [DwPushMessage]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  ///
  /// If [ignoreConflicts] is set to `true`, rows that conflict with existing
  /// rows are silently skipped, and only the successfully inserted rows are
  /// returned.
  Future<List<DwPushMessage>> insert(
    _i1.DatabaseSession session,
    List<DwPushMessage> rows, {
    _i1.Transaction? transaction,
    bool ignoreConflicts = false,
  }) async {
    return session.db.insert<DwPushMessage>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
    );
  }

  /// Inserts a single [DwPushMessage] and returns the inserted row.
  ///
  /// The returned [DwPushMessage] will have its `id` field set.
  Future<DwPushMessage> insertRow(
    _i1.DatabaseSession session,
    DwPushMessage row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<DwPushMessage>(
      row,
      transaction: transaction,
    );
  }

  /// Updates all [DwPushMessage]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  Future<List<DwPushMessage>> update(
    _i1.DatabaseSession session,
    List<DwPushMessage> rows, {
    _i1.ColumnSelections<DwPushMessageTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.update<DwPushMessage>(
      rows,
      columns: columns?.call(DwPushMessage.t),
      transaction: transaction,
    );
  }

  /// Updates a single [DwPushMessage]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<DwPushMessage> updateRow(
    _i1.DatabaseSession session,
    DwPushMessage row, {
    _i1.ColumnSelections<DwPushMessageTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<DwPushMessage>(
      row,
      columns: columns?.call(DwPushMessage.t),
      transaction: transaction,
    );
  }

  /// Updates a single [DwPushMessage] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<DwPushMessage?> updateById(
    _i1.DatabaseSession session,
    int id, {
    required _i1.ColumnValueListBuilder<DwPushMessageUpdateTable> columnValues,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateById<DwPushMessage>(
      id,
      columnValues: columnValues(DwPushMessage.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [DwPushMessage]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  Future<List<DwPushMessage>> updateWhere(
    _i1.DatabaseSession session, {
    required _i1.ColumnValueListBuilder<DwPushMessageUpdateTable> columnValues,
    required _i1.WhereExpressionBuilder<DwPushMessageTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<DwPushMessageTable>? orderBy,
    _i1.OrderByListBuilder<DwPushMessageTable>? orderByList,
    bool orderDescending = false,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateWhere<DwPushMessage>(
      columnValues: columnValues(DwPushMessage.t.updateTable),
      where: where(DwPushMessage.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(DwPushMessage.t),
      orderByList: orderByList?.call(DwPushMessage.t),
      orderDescending: orderDescending,
      transaction: transaction,
    );
  }

  /// Deletes all [DwPushMessage]s in the list and returns the deleted rows.
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  Future<List<DwPushMessage>> delete(
    _i1.DatabaseSession session,
    List<DwPushMessage> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<DwPushMessage>(
      rows,
      transaction: transaction,
    );
  }

  /// Deletes a single [DwPushMessage].
  Future<DwPushMessage> deleteRow(
    _i1.DatabaseSession session,
    DwPushMessage row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<DwPushMessage>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  Future<List<DwPushMessage>> deleteWhere(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<DwPushMessageTable> where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteWhere<DwPushMessage>(
      where: where(DwPushMessage.t),
      transaction: transaction,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<DwPushMessageTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<DwPushMessage>(
      where: where?.call(DwPushMessage.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [DwPushMessage] rows matching the [where] expression.
  Future<void> lockRows(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<DwPushMessageTable> where,
    required _i1.LockMode lockMode,
    required _i1.Transaction transaction,
    _i1.LockBehavior lockBehavior = _i1.LockBehavior.wait,
  }) async {
    return session.db.lockRows<DwPushMessage>(
      where: where(DwPushMessage.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
