/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters

// ignore_for_file: unnecessary_null_comparison

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod/serverpod.dart' as _i1;
import 'dw_chat_participant.dart' as _i2;

abstract class DwChatChannel
    implements _i1.TableRow<int?>, _i1.ProtocolSerialization {
  DwChatChannel._({
    this.id,
    required this.channel,
    this.chatParticipants,
  });

  factory DwChatChannel({
    int? id,
    required String channel,
    List<_i2.DwChatParticipant>? chatParticipants,
  }) = _DwChatChannelImpl;

  factory DwChatChannel.fromJson(Map<String, dynamic> jsonSerialization) {
    return DwChatChannel(
      id: jsonSerialization['id'] as int?,
      channel: jsonSerialization['channel'] as String,
      chatParticipants: (jsonSerialization['chatParticipants'] as List?)
          ?.map((e) =>
              _i2.DwChatParticipant.fromJson((e as Map<String, dynamic>)))
          .toList(),
    );
  }

  static final t = DwChatChannelTable();

  static const db = DwChatChannelRepository._();

  @override
  int? id;

  String channel;

  List<_i2.DwChatParticipant>? chatParticipants;

  @override
  _i1.Table<int?> get table => t;

  /// Returns a shallow copy of this [DwChatChannel]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  DwChatChannel copyWith({
    int? id,
    String? channel,
    List<_i2.DwChatParticipant>? chatParticipants,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'channel': channel,
      if (chatParticipants != null)
        'chatParticipants':
            chatParticipants?.toJson(valueToJson: (v) => v.toJson()),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      if (id != null) 'id': id,
      'channel': channel,
      if (chatParticipants != null)
        'chatParticipants':
            chatParticipants?.toJson(valueToJson: (v) => v.toJsonForProtocol()),
    };
  }

  static DwChatChannelInclude include(
      {_i2.DwChatParticipantIncludeList? chatParticipants}) {
    return DwChatChannelInclude._(chatParticipants: chatParticipants);
  }

  static DwChatChannelIncludeList includeList({
    _i1.WhereExpressionBuilder<DwChatChannelTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<DwChatChannelTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<DwChatChannelTable>? orderByList,
    DwChatChannelInclude? include,
  }) {
    return DwChatChannelIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(DwChatChannel.t),
      orderDescending: orderDescending,
      orderByList: orderByList?.call(DwChatChannel.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _DwChatChannelImpl extends DwChatChannel {
  _DwChatChannelImpl({
    int? id,
    required String channel,
    List<_i2.DwChatParticipant>? chatParticipants,
  }) : super._(
          id: id,
          channel: channel,
          chatParticipants: chatParticipants,
        );

  /// Returns a shallow copy of this [DwChatChannel]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  DwChatChannel copyWith({
    Object? id = _Undefined,
    String? channel,
    Object? chatParticipants = _Undefined,
  }) {
    return DwChatChannel(
      id: id is int? ? id : this.id,
      channel: channel ?? this.channel,
      chatParticipants: chatParticipants is List<_i2.DwChatParticipant>?
          ? chatParticipants
          : this.chatParticipants?.map((e0) => e0.copyWith()).toList(),
    );
  }
}

class DwChatChannelTable extends _i1.Table<int?> {
  DwChatChannelTable({super.tableRelation})
      : super(tableName: 'dw_chat_channel') {
    channel = _i1.ColumnString(
      'channel',
      this,
    );
  }

  late final _i1.ColumnString channel;

  _i2.DwChatParticipantTable? ___chatParticipants;

  _i1.ManyRelation<_i2.DwChatParticipantTable>? _chatParticipants;

  _i2.DwChatParticipantTable get __chatParticipants {
    if (___chatParticipants != null) return ___chatParticipants!;
    ___chatParticipants = _i1.createRelationTable(
      relationFieldName: '__chatParticipants',
      field: DwChatChannel.t.id,
      foreignField: _i2.DwChatParticipant.t.chatChannelId,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _i2.DwChatParticipantTable(tableRelation: foreignTableRelation),
    );
    return ___chatParticipants!;
  }

  _i1.ManyRelation<_i2.DwChatParticipantTable> get chatParticipants {
    if (_chatParticipants != null) return _chatParticipants!;
    var relationTable = _i1.createRelationTable(
      relationFieldName: 'chatParticipants',
      field: DwChatChannel.t.id,
      foreignField: _i2.DwChatParticipant.t.chatChannelId,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _i2.DwChatParticipantTable(tableRelation: foreignTableRelation),
    );
    _chatParticipants = _i1.ManyRelation<_i2.DwChatParticipantTable>(
      tableWithRelations: relationTable,
      table: _i2.DwChatParticipantTable(
          tableRelation: relationTable.tableRelation!.lastRelation),
    );
    return _chatParticipants!;
  }

  @override
  List<_i1.Column> get columns => [
        id,
        channel,
      ];

  @override
  _i1.Table? getRelationTable(String relationField) {
    if (relationField == 'chatParticipants') {
      return __chatParticipants;
    }
    return null;
  }
}

class DwChatChannelInclude extends _i1.IncludeObject {
  DwChatChannelInclude._({_i2.DwChatParticipantIncludeList? chatParticipants}) {
    _chatParticipants = chatParticipants;
  }

  _i2.DwChatParticipantIncludeList? _chatParticipants;

  @override
  Map<String, _i1.Include?> get includes =>
      {'chatParticipants': _chatParticipants};

  @override
  _i1.Table<int?> get table => DwChatChannel.t;
}

class DwChatChannelIncludeList extends _i1.IncludeList {
  DwChatChannelIncludeList._({
    _i1.WhereExpressionBuilder<DwChatChannelTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(DwChatChannel.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<int?> get table => DwChatChannel.t;
}

class DwChatChannelRepository {
  const DwChatChannelRepository._();

  final attach = const DwChatChannelAttachRepository._();

  final attachRow = const DwChatChannelAttachRowRepository._();

  final detach = const DwChatChannelDetachRepository._();

  final detachRow = const DwChatChannelDetachRowRepository._();

  /// Returns a list of [DwChatChannel]s matching the given query parameters.
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
  Future<List<DwChatChannel>> find(
    _i1.Session session, {
    _i1.WhereExpressionBuilder<DwChatChannelTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<DwChatChannelTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<DwChatChannelTable>? orderByList,
    _i1.Transaction? transaction,
    DwChatChannelInclude? include,
  }) async {
    return session.db.find<DwChatChannel>(
      where: where?.call(DwChatChannel.t),
      orderBy: orderBy?.call(DwChatChannel.t),
      orderByList: orderByList?.call(DwChatChannel.t),
      orderDescending: orderDescending,
      limit: limit,
      offset: offset,
      transaction: transaction,
      include: include,
    );
  }

  /// Returns the first matching [DwChatChannel] matching the given query parameters.
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
  Future<DwChatChannel?> findFirstRow(
    _i1.Session session, {
    _i1.WhereExpressionBuilder<DwChatChannelTable>? where,
    int? offset,
    _i1.OrderByBuilder<DwChatChannelTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<DwChatChannelTable>? orderByList,
    _i1.Transaction? transaction,
    DwChatChannelInclude? include,
  }) async {
    return session.db.findFirstRow<DwChatChannel>(
      where: where?.call(DwChatChannel.t),
      orderBy: orderBy?.call(DwChatChannel.t),
      orderByList: orderByList?.call(DwChatChannel.t),
      orderDescending: orderDescending,
      offset: offset,
      transaction: transaction,
      include: include,
    );
  }

  /// Finds a single [DwChatChannel] by its [id] or null if no such row exists.
  Future<DwChatChannel?> findById(
    _i1.Session session,
    int id, {
    _i1.Transaction? transaction,
    DwChatChannelInclude? include,
  }) async {
    return session.db.findById<DwChatChannel>(
      id,
      transaction: transaction,
      include: include,
    );
  }

  /// Inserts all [DwChatChannel]s in the list and returns the inserted rows.
  ///
  /// The returned [DwChatChannel]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  Future<List<DwChatChannel>> insert(
    _i1.Session session,
    List<DwChatChannel> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insert<DwChatChannel>(
      rows,
      transaction: transaction,
    );
  }

  /// Inserts a single [DwChatChannel] and returns the inserted row.
  ///
  /// The returned [DwChatChannel] will have its `id` field set.
  Future<DwChatChannel> insertRow(
    _i1.Session session,
    DwChatChannel row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<DwChatChannel>(
      row,
      transaction: transaction,
    );
  }

  /// Updates all [DwChatChannel]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  Future<List<DwChatChannel>> update(
    _i1.Session session,
    List<DwChatChannel> rows, {
    _i1.ColumnSelections<DwChatChannelTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.update<DwChatChannel>(
      rows,
      columns: columns?.call(DwChatChannel.t),
      transaction: transaction,
    );
  }

  /// Updates a single [DwChatChannel]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<DwChatChannel> updateRow(
    _i1.Session session,
    DwChatChannel row, {
    _i1.ColumnSelections<DwChatChannelTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<DwChatChannel>(
      row,
      columns: columns?.call(DwChatChannel.t),
      transaction: transaction,
    );
  }

  /// Deletes all [DwChatChannel]s in the list and returns the deleted rows.
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  Future<List<DwChatChannel>> delete(
    _i1.Session session,
    List<DwChatChannel> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<DwChatChannel>(
      rows,
      transaction: transaction,
    );
  }

  /// Deletes a single [DwChatChannel].
  Future<DwChatChannel> deleteRow(
    _i1.Session session,
    DwChatChannel row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<DwChatChannel>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  Future<List<DwChatChannel>> deleteWhere(
    _i1.Session session, {
    required _i1.WhereExpressionBuilder<DwChatChannelTable> where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteWhere<DwChatChannel>(
      where: where(DwChatChannel.t),
      transaction: transaction,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.Session session, {
    _i1.WhereExpressionBuilder<DwChatChannelTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<DwChatChannel>(
      where: where?.call(DwChatChannel.t),
      limit: limit,
      transaction: transaction,
    );
  }
}

class DwChatChannelAttachRepository {
  const DwChatChannelAttachRepository._();

  /// Creates a relation between this [DwChatChannel] and the given [DwChatParticipant]s
  /// by setting each [DwChatParticipant]'s foreign key `chatChannelId` to refer to this [DwChatChannel].
  Future<void> chatParticipants(
    _i1.Session session,
    DwChatChannel dwChatChannel,
    List<_i2.DwChatParticipant> dwChatParticipant, {
    _i1.Transaction? transaction,
  }) async {
    if (dwChatParticipant.any((e) => e.id == null)) {
      throw ArgumentError.notNull('dwChatParticipant.id');
    }
    if (dwChatChannel.id == null) {
      throw ArgumentError.notNull('dwChatChannel.id');
    }

    var $dwChatParticipant = dwChatParticipant
        .map((e) => e.copyWith(chatChannelId: dwChatChannel.id))
        .toList();
    await session.db.update<_i2.DwChatParticipant>(
      $dwChatParticipant,
      columns: [_i2.DwChatParticipant.t.chatChannelId],
      transaction: transaction,
    );
  }
}

class DwChatChannelAttachRowRepository {
  const DwChatChannelAttachRowRepository._();

  /// Creates a relation between this [DwChatChannel] and the given [DwChatParticipant]
  /// by setting the [DwChatParticipant]'s foreign key `chatChannelId` to refer to this [DwChatChannel].
  Future<void> chatParticipants(
    _i1.Session session,
    DwChatChannel dwChatChannel,
    _i2.DwChatParticipant dwChatParticipant, {
    _i1.Transaction? transaction,
  }) async {
    if (dwChatParticipant.id == null) {
      throw ArgumentError.notNull('dwChatParticipant.id');
    }
    if (dwChatChannel.id == null) {
      throw ArgumentError.notNull('dwChatChannel.id');
    }

    var $dwChatParticipant =
        dwChatParticipant.copyWith(chatChannelId: dwChatChannel.id);
    await session.db.updateRow<_i2.DwChatParticipant>(
      $dwChatParticipant,
      columns: [_i2.DwChatParticipant.t.chatChannelId],
      transaction: transaction,
    );
  }
}

class DwChatChannelDetachRepository {
  const DwChatChannelDetachRepository._();

  /// Detaches the relation between this [DwChatChannel] and the given [DwChatParticipant]
  /// by setting the [DwChatParticipant]'s foreign key `chatChannelId` to `null`.
  ///
  /// This removes the association between the two models without deleting
  /// the related record.
  Future<void> chatParticipants(
    _i1.Session session,
    List<_i2.DwChatParticipant> dwChatParticipant, {
    _i1.Transaction? transaction,
  }) async {
    if (dwChatParticipant.any((e) => e.id == null)) {
      throw ArgumentError.notNull('dwChatParticipant.id');
    }

    var $dwChatParticipant =
        dwChatParticipant.map((e) => e.copyWith(chatChannelId: null)).toList();
    await session.db.update<_i2.DwChatParticipant>(
      $dwChatParticipant,
      columns: [_i2.DwChatParticipant.t.chatChannelId],
      transaction: transaction,
    );
  }
}

class DwChatChannelDetachRowRepository {
  const DwChatChannelDetachRowRepository._();

  /// Detaches the relation between this [DwChatChannel] and the given [DwChatParticipant]
  /// by setting the [DwChatParticipant]'s foreign key `chatChannelId` to `null`.
  ///
  /// This removes the association between the two models without deleting
  /// the related record.
  Future<void> chatParticipants(
    _i1.Session session,
    _i2.DwChatParticipant dwChatParticipant, {
    _i1.Transaction? transaction,
  }) async {
    if (dwChatParticipant.id == null) {
      throw ArgumentError.notNull('dwChatParticipant.id');
    }

    var $dwChatParticipant = dwChatParticipant.copyWith(chatChannelId: null);
    await session.db.updateRow<_i2.DwChatParticipant>(
      $dwChatParticipant,
      columns: [_i2.DwChatParticipant.t.chatChannelId],
      transaction: transaction,
    );
  }
}
