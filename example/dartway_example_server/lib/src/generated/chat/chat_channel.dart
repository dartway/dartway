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

abstract class ChatChannel
    implements _i1.TableRow<int?>, _i1.ProtocolSerialization {
  ChatChannel._({
    this.id,
    required this.title,
    required this.createdAt,
  });

  factory ChatChannel({
    int? id,
    required String title,
    required DateTime createdAt,
  }) = _ChatChannelImpl;

  factory ChatChannel.fromJson(Map<String, dynamic> jsonSerialization) {
    return ChatChannel(
      id: jsonSerialization['id'] as int?,
      title: jsonSerialization['title'] as String,
      createdAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
    );
  }

  static final t = ChatChannelTable();

  static const db = ChatChannelRepository._();

  @override
  int? id;

  String title;

  DateTime createdAt;

  @override
  _i1.Table<int?> get table => t;

  /// Returns a shallow copy of this [ChatChannel]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  ChatChannel copyWith({
    int? id,
    String? title,
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'ChatChannel',
      if (id != null) 'id': id,
      'title': title,
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'ChatChannel',
      if (id != null) 'id': id,
      'title': title,
      'createdAt': createdAt.toJson(),
    };
  }

  static ChatChannelInclude include() {
    return ChatChannelInclude._();
  }

  static ChatChannelIncludeList includeList({
    _i1.WhereExpressionBuilder<ChatChannelTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<ChatChannelTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<ChatChannelTable>? orderByList,
    ChatChannelInclude? include,
  }) {
    return ChatChannelIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(ChatChannel.t),
      orderDescending: orderDescending,
      orderByList: orderByList?.call(ChatChannel.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _ChatChannelImpl extends ChatChannel {
  _ChatChannelImpl({
    int? id,
    required String title,
    required DateTime createdAt,
  }) : super._(
         id: id,
         title: title,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [ChatChannel]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  ChatChannel copyWith({
    Object? id = _Undefined,
    String? title,
    DateTime? createdAt,
  }) {
    return ChatChannel(
      id: id is int? ? id : this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class ChatChannelUpdateTable extends _i1.UpdateTable<ChatChannelTable> {
  ChatChannelUpdateTable(super.table);

  _i1.ColumnValue<String, String> title(String value) => _i1.ColumnValue(
    table.title,
    value,
  );

  _i1.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _i1.ColumnValue(
        table.createdAt,
        value,
      );
}

class ChatChannelTable extends _i1.Table<int?> {
  ChatChannelTable({super.tableRelation}) : super(tableName: 'chat_channel') {
    updateTable = ChatChannelUpdateTable(this);
    title = _i1.ColumnString(
      'title',
      this,
    );
    createdAt = _i1.ColumnDateTime(
      'createdAt',
      this,
    );
  }

  late final ChatChannelUpdateTable updateTable;

  late final _i1.ColumnString title;

  late final _i1.ColumnDateTime createdAt;

  @override
  List<_i1.Column> get columns => [
    id,
    title,
    createdAt,
  ];
}

class ChatChannelInclude extends _i1.IncludeObject {
  ChatChannelInclude._();

  @override
  Map<String, _i1.Include?> get includes => {};

  @override
  _i1.Table<int?> get table => ChatChannel.t;
}

class ChatChannelIncludeList extends _i1.IncludeList {
  ChatChannelIncludeList._({
    _i1.WhereExpressionBuilder<ChatChannelTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(ChatChannel.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<int?> get table => ChatChannel.t;
}

class ChatChannelRepository {
  const ChatChannelRepository._();

  /// Returns a list of [ChatChannel]s matching the given query parameters.
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
  Future<List<ChatChannel>> find(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<ChatChannelTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<ChatChannelTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<ChatChannelTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<ChatChannel>(
      where: where?.call(ChatChannel.t),
      orderBy: orderBy?.call(ChatChannel.t),
      orderByList: orderByList?.call(ChatChannel.t),
      orderDescending: orderDescending,
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [ChatChannel] matching the given query parameters.
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
  Future<ChatChannel?> findFirstRow(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<ChatChannelTable>? where,
    int? offset,
    _i1.OrderByBuilder<ChatChannelTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<ChatChannelTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<ChatChannel>(
      where: where?.call(ChatChannel.t),
      orderBy: orderBy?.call(ChatChannel.t),
      orderByList: orderByList?.call(ChatChannel.t),
      orderDescending: orderDescending,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [ChatChannel] by its [id] or null if no such row exists.
  Future<ChatChannel?> findById(
    _i1.DatabaseSession session,
    int id, {
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<ChatChannel>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [ChatChannel]s in the list and returns the inserted rows.
  ///
  /// The returned [ChatChannel]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  ///
  /// If [ignoreConflicts] is set to `true`, rows that conflict with existing
  /// rows are silently skipped, and only the successfully inserted rows are
  /// returned.
  Future<List<ChatChannel>> insert(
    _i1.DatabaseSession session,
    List<ChatChannel> rows, {
    _i1.Transaction? transaction,
    bool ignoreConflicts = false,
  }) async {
    return session.db.insert<ChatChannel>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
    );
  }

  /// Inserts a single [ChatChannel] and returns the inserted row.
  ///
  /// The returned [ChatChannel] will have its `id` field set.
  Future<ChatChannel> insertRow(
    _i1.DatabaseSession session,
    ChatChannel row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<ChatChannel>(
      row,
      transaction: transaction,
    );
  }

  /// Updates all [ChatChannel]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  Future<List<ChatChannel>> update(
    _i1.DatabaseSession session,
    List<ChatChannel> rows, {
    _i1.ColumnSelections<ChatChannelTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.update<ChatChannel>(
      rows,
      columns: columns?.call(ChatChannel.t),
      transaction: transaction,
    );
  }

  /// Updates a single [ChatChannel]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<ChatChannel> updateRow(
    _i1.DatabaseSession session,
    ChatChannel row, {
    _i1.ColumnSelections<ChatChannelTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<ChatChannel>(
      row,
      columns: columns?.call(ChatChannel.t),
      transaction: transaction,
    );
  }

  /// Updates a single [ChatChannel] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<ChatChannel?> updateById(
    _i1.DatabaseSession session,
    int id, {
    required _i1.ColumnValueListBuilder<ChatChannelUpdateTable> columnValues,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateById<ChatChannel>(
      id,
      columnValues: columnValues(ChatChannel.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [ChatChannel]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  Future<List<ChatChannel>> updateWhere(
    _i1.DatabaseSession session, {
    required _i1.ColumnValueListBuilder<ChatChannelUpdateTable> columnValues,
    required _i1.WhereExpressionBuilder<ChatChannelTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<ChatChannelTable>? orderBy,
    _i1.OrderByListBuilder<ChatChannelTable>? orderByList,
    bool orderDescending = false,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateWhere<ChatChannel>(
      columnValues: columnValues(ChatChannel.t.updateTable),
      where: where(ChatChannel.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(ChatChannel.t),
      orderByList: orderByList?.call(ChatChannel.t),
      orderDescending: orderDescending,
      transaction: transaction,
    );
  }

  /// Deletes all [ChatChannel]s in the list and returns the deleted rows.
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  Future<List<ChatChannel>> delete(
    _i1.DatabaseSession session,
    List<ChatChannel> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<ChatChannel>(
      rows,
      transaction: transaction,
    );
  }

  /// Deletes a single [ChatChannel].
  Future<ChatChannel> deleteRow(
    _i1.DatabaseSession session,
    ChatChannel row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<ChatChannel>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  Future<List<ChatChannel>> deleteWhere(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<ChatChannelTable> where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteWhere<ChatChannel>(
      where: where(ChatChannel.t),
      transaction: transaction,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<ChatChannelTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<ChatChannel>(
      where: where?.call(ChatChannel.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [ChatChannel] rows matching the [where] expression.
  Future<void> lockRows(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<ChatChannelTable> where,
    required _i1.LockMode lockMode,
    required _i1.Transaction transaction,
    _i1.LockBehavior lockBehavior = _i1.LockBehavior.wait,
  }) async {
    return session.db.lockRows<ChatChannel>(
      where: where(ChatChannel.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
