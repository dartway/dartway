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
import 'dw_chat_channel.dart' as _i2;
import 'dw_chat_message.dart' as _i3;

abstract class DwChatParticipant
    implements _i1.TableRow<int?>, _i1.ProtocolSerialization {
  DwChatParticipant._({
    this.id,
    required this.userId,
    required this.chatChannelId,
    this.chatChannel,
    this.lastMessageId,
    this.lastMessage,
    this.lastMessageSentAt,
    int? unreadCount,
    this.lastReadMessageId,
    this.lastReadMessage,
    bool? isDeleted,
  })  : unreadCount = unreadCount ?? 0,
        isDeleted = isDeleted ?? false;

  factory DwChatParticipant({
    int? id,
    required int userId,
    required int chatChannelId,
    _i2.DwChatChannel? chatChannel,
    int? lastMessageId,
    _i3.DwChatMessage? lastMessage,
    DateTime? lastMessageSentAt,
    int? unreadCount,
    int? lastReadMessageId,
    _i3.DwChatMessage? lastReadMessage,
    bool? isDeleted,
  }) = _DwChatParticipantImpl;

  factory DwChatParticipant.fromJson(Map<String, dynamic> jsonSerialization) {
    return DwChatParticipant(
      id: jsonSerialization['id'] as int?,
      userId: jsonSerialization['userId'] as int,
      chatChannelId: jsonSerialization['chatChannelId'] as int,
      chatChannel: jsonSerialization['chatChannel'] == null
          ? null
          : _i2.DwChatChannel.fromJson(
              (jsonSerialization['chatChannel'] as Map<String, dynamic>)),
      lastMessageId: jsonSerialization['lastMessageId'] as int?,
      lastMessage: jsonSerialization['lastMessage'] == null
          ? null
          : _i3.DwChatMessage.fromJson(
              (jsonSerialization['lastMessage'] as Map<String, dynamic>)),
      lastMessageSentAt: jsonSerialization['lastMessageSentAt'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(
              jsonSerialization['lastMessageSentAt']),
      unreadCount: jsonSerialization['unreadCount'] as int,
      lastReadMessageId: jsonSerialization['lastReadMessageId'] as int?,
      lastReadMessage: jsonSerialization['lastReadMessage'] == null
          ? null
          : _i3.DwChatMessage.fromJson(
              (jsonSerialization['lastReadMessage'] as Map<String, dynamic>)),
      isDeleted: jsonSerialization['isDeleted'] as bool,
    );
  }

  static final t = DwChatParticipantTable();

  static const db = DwChatParticipantRepository._();

  @override
  int? id;

  int userId;

  int chatChannelId;

  _i2.DwChatChannel? chatChannel;

  int? lastMessageId;

  _i3.DwChatMessage? lastMessage;

  DateTime? lastMessageSentAt;

  int unreadCount;

  int? lastReadMessageId;

  _i3.DwChatMessage? lastReadMessage;

  bool isDeleted;

  @override
  _i1.Table<int?> get table => t;

  /// Returns a shallow copy of this [DwChatParticipant]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  DwChatParticipant copyWith({
    int? id,
    int? userId,
    int? chatChannelId,
    _i2.DwChatChannel? chatChannel,
    int? lastMessageId,
    _i3.DwChatMessage? lastMessage,
    DateTime? lastMessageSentAt,
    int? unreadCount,
    int? lastReadMessageId,
    _i3.DwChatMessage? lastReadMessage,
    bool? isDeleted,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'userId': userId,
      'chatChannelId': chatChannelId,
      if (chatChannel != null) 'chatChannel': chatChannel?.toJson(),
      if (lastMessageId != null) 'lastMessageId': lastMessageId,
      if (lastMessage != null) 'lastMessage': lastMessage?.toJson(),
      if (lastMessageSentAt != null)
        'lastMessageSentAt': lastMessageSentAt?.toJson(),
      'unreadCount': unreadCount,
      if (lastReadMessageId != null) 'lastReadMessageId': lastReadMessageId,
      if (lastReadMessage != null) 'lastReadMessage': lastReadMessage?.toJson(),
      'isDeleted': isDeleted,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      if (id != null) 'id': id,
      'userId': userId,
      'chatChannelId': chatChannelId,
      if (chatChannel != null) 'chatChannel': chatChannel?.toJsonForProtocol(),
      if (lastMessageId != null) 'lastMessageId': lastMessageId,
      if (lastMessage != null) 'lastMessage': lastMessage?.toJsonForProtocol(),
      if (lastMessageSentAt != null)
        'lastMessageSentAt': lastMessageSentAt?.toJson(),
      'unreadCount': unreadCount,
      if (lastReadMessageId != null) 'lastReadMessageId': lastReadMessageId,
      if (lastReadMessage != null)
        'lastReadMessage': lastReadMessage?.toJsonForProtocol(),
      'isDeleted': isDeleted,
    };
  }

  static DwChatParticipantInclude include({
    _i2.DwChatChannelInclude? chatChannel,
    _i3.DwChatMessageInclude? lastMessage,
    _i3.DwChatMessageInclude? lastReadMessage,
  }) {
    return DwChatParticipantInclude._(
      chatChannel: chatChannel,
      lastMessage: lastMessage,
      lastReadMessage: lastReadMessage,
    );
  }

  static DwChatParticipantIncludeList includeList({
    _i1.WhereExpressionBuilder<DwChatParticipantTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<DwChatParticipantTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<DwChatParticipantTable>? orderByList,
    DwChatParticipantInclude? include,
  }) {
    return DwChatParticipantIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(DwChatParticipant.t),
      orderDescending: orderDescending,
      orderByList: orderByList?.call(DwChatParticipant.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _DwChatParticipantImpl extends DwChatParticipant {
  _DwChatParticipantImpl({
    int? id,
    required int userId,
    required int chatChannelId,
    _i2.DwChatChannel? chatChannel,
    int? lastMessageId,
    _i3.DwChatMessage? lastMessage,
    DateTime? lastMessageSentAt,
    int? unreadCount,
    int? lastReadMessageId,
    _i3.DwChatMessage? lastReadMessage,
    bool? isDeleted,
  }) : super._(
          id: id,
          userId: userId,
          chatChannelId: chatChannelId,
          chatChannel: chatChannel,
          lastMessageId: lastMessageId,
          lastMessage: lastMessage,
          lastMessageSentAt: lastMessageSentAt,
          unreadCount: unreadCount,
          lastReadMessageId: lastReadMessageId,
          lastReadMessage: lastReadMessage,
          isDeleted: isDeleted,
        );

  /// Returns a shallow copy of this [DwChatParticipant]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  DwChatParticipant copyWith({
    Object? id = _Undefined,
    int? userId,
    int? chatChannelId,
    Object? chatChannel = _Undefined,
    Object? lastMessageId = _Undefined,
    Object? lastMessage = _Undefined,
    Object? lastMessageSentAt = _Undefined,
    int? unreadCount,
    Object? lastReadMessageId = _Undefined,
    Object? lastReadMessage = _Undefined,
    bool? isDeleted,
  }) {
    return DwChatParticipant(
      id: id is int? ? id : this.id,
      userId: userId ?? this.userId,
      chatChannelId: chatChannelId ?? this.chatChannelId,
      chatChannel: chatChannel is _i2.DwChatChannel?
          ? chatChannel
          : this.chatChannel?.copyWith(),
      lastMessageId: lastMessageId is int? ? lastMessageId : this.lastMessageId,
      lastMessage: lastMessage is _i3.DwChatMessage?
          ? lastMessage
          : this.lastMessage?.copyWith(),
      lastMessageSentAt: lastMessageSentAt is DateTime?
          ? lastMessageSentAt
          : this.lastMessageSentAt,
      unreadCount: unreadCount ?? this.unreadCount,
      lastReadMessageId: lastReadMessageId is int?
          ? lastReadMessageId
          : this.lastReadMessageId,
      lastReadMessage: lastReadMessage is _i3.DwChatMessage?
          ? lastReadMessage
          : this.lastReadMessage?.copyWith(),
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}

class DwChatParticipantTable extends _i1.Table<int?> {
  DwChatParticipantTable({super.tableRelation})
      : super(tableName: 'dw_chat_participant') {
    userId = _i1.ColumnInt(
      'userId',
      this,
    );
    chatChannelId = _i1.ColumnInt(
      'chatChannelId',
      this,
    );
    lastMessageId = _i1.ColumnInt(
      'lastMessageId',
      this,
    );
    lastMessageSentAt = _i1.ColumnDateTime(
      'lastMessageSentAt',
      this,
    );
    unreadCount = _i1.ColumnInt(
      'unreadCount',
      this,
      hasDefault: true,
    );
    lastReadMessageId = _i1.ColumnInt(
      'lastReadMessageId',
      this,
    );
    isDeleted = _i1.ColumnBool(
      'isDeleted',
      this,
      hasDefault: true,
    );
  }

  late final _i1.ColumnInt userId;

  late final _i1.ColumnInt chatChannelId;

  _i2.DwChatChannelTable? _chatChannel;

  late final _i1.ColumnInt lastMessageId;

  _i3.DwChatMessageTable? _lastMessage;

  late final _i1.ColumnDateTime lastMessageSentAt;

  late final _i1.ColumnInt unreadCount;

  late final _i1.ColumnInt lastReadMessageId;

  _i3.DwChatMessageTable? _lastReadMessage;

  late final _i1.ColumnBool isDeleted;

  _i2.DwChatChannelTable get chatChannel {
    if (_chatChannel != null) return _chatChannel!;
    _chatChannel = _i1.createRelationTable(
      relationFieldName: 'chatChannel',
      field: DwChatParticipant.t.chatChannelId,
      foreignField: _i2.DwChatChannel.t.id,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _i2.DwChatChannelTable(tableRelation: foreignTableRelation),
    );
    return _chatChannel!;
  }

  _i3.DwChatMessageTable get lastMessage {
    if (_lastMessage != null) return _lastMessage!;
    _lastMessage = _i1.createRelationTable(
      relationFieldName: 'lastMessage',
      field: DwChatParticipant.t.lastMessageId,
      foreignField: _i3.DwChatMessage.t.id,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _i3.DwChatMessageTable(tableRelation: foreignTableRelation),
    );
    return _lastMessage!;
  }

  _i3.DwChatMessageTable get lastReadMessage {
    if (_lastReadMessage != null) return _lastReadMessage!;
    _lastReadMessage = _i1.createRelationTable(
      relationFieldName: 'lastReadMessage',
      field: DwChatParticipant.t.lastReadMessageId,
      foreignField: _i3.DwChatMessage.t.id,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _i3.DwChatMessageTable(tableRelation: foreignTableRelation),
    );
    return _lastReadMessage!;
  }

  @override
  List<_i1.Column> get columns => [
        id,
        userId,
        chatChannelId,
        lastMessageId,
        lastMessageSentAt,
        unreadCount,
        lastReadMessageId,
        isDeleted,
      ];

  @override
  _i1.Table? getRelationTable(String relationField) {
    if (relationField == 'chatChannel') {
      return chatChannel;
    }
    if (relationField == 'lastMessage') {
      return lastMessage;
    }
    if (relationField == 'lastReadMessage') {
      return lastReadMessage;
    }
    return null;
  }
}

class DwChatParticipantInclude extends _i1.IncludeObject {
  DwChatParticipantInclude._({
    _i2.DwChatChannelInclude? chatChannel,
    _i3.DwChatMessageInclude? lastMessage,
    _i3.DwChatMessageInclude? lastReadMessage,
  }) {
    _chatChannel = chatChannel;
    _lastMessage = lastMessage;
    _lastReadMessage = lastReadMessage;
  }

  _i2.DwChatChannelInclude? _chatChannel;

  _i3.DwChatMessageInclude? _lastMessage;

  _i3.DwChatMessageInclude? _lastReadMessage;

  @override
  Map<String, _i1.Include?> get includes => {
        'chatChannel': _chatChannel,
        'lastMessage': _lastMessage,
        'lastReadMessage': _lastReadMessage,
      };

  @override
  _i1.Table<int?> get table => DwChatParticipant.t;
}

class DwChatParticipantIncludeList extends _i1.IncludeList {
  DwChatParticipantIncludeList._({
    _i1.WhereExpressionBuilder<DwChatParticipantTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(DwChatParticipant.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<int?> get table => DwChatParticipant.t;
}

class DwChatParticipantRepository {
  const DwChatParticipantRepository._();

  final attachRow = const DwChatParticipantAttachRowRepository._();

  final detachRow = const DwChatParticipantDetachRowRepository._();

  /// Returns a list of [DwChatParticipant]s matching the given query parameters.
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
  Future<List<DwChatParticipant>> find(
    _i1.Session session, {
    _i1.WhereExpressionBuilder<DwChatParticipantTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<DwChatParticipantTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<DwChatParticipantTable>? orderByList,
    _i1.Transaction? transaction,
    DwChatParticipantInclude? include,
  }) async {
    return session.db.find<DwChatParticipant>(
      where: where?.call(DwChatParticipant.t),
      orderBy: orderBy?.call(DwChatParticipant.t),
      orderByList: orderByList?.call(DwChatParticipant.t),
      orderDescending: orderDescending,
      limit: limit,
      offset: offset,
      transaction: transaction,
      include: include,
    );
  }

  /// Returns the first matching [DwChatParticipant] matching the given query parameters.
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
  Future<DwChatParticipant?> findFirstRow(
    _i1.Session session, {
    _i1.WhereExpressionBuilder<DwChatParticipantTable>? where,
    int? offset,
    _i1.OrderByBuilder<DwChatParticipantTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<DwChatParticipantTable>? orderByList,
    _i1.Transaction? transaction,
    DwChatParticipantInclude? include,
  }) async {
    return session.db.findFirstRow<DwChatParticipant>(
      where: where?.call(DwChatParticipant.t),
      orderBy: orderBy?.call(DwChatParticipant.t),
      orderByList: orderByList?.call(DwChatParticipant.t),
      orderDescending: orderDescending,
      offset: offset,
      transaction: transaction,
      include: include,
    );
  }

  /// Finds a single [DwChatParticipant] by its [id] or null if no such row exists.
  Future<DwChatParticipant?> findById(
    _i1.Session session,
    int id, {
    _i1.Transaction? transaction,
    DwChatParticipantInclude? include,
  }) async {
    return session.db.findById<DwChatParticipant>(
      id,
      transaction: transaction,
      include: include,
    );
  }

  /// Inserts all [DwChatParticipant]s in the list and returns the inserted rows.
  ///
  /// The returned [DwChatParticipant]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  Future<List<DwChatParticipant>> insert(
    _i1.Session session,
    List<DwChatParticipant> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insert<DwChatParticipant>(
      rows,
      transaction: transaction,
    );
  }

  /// Inserts a single [DwChatParticipant] and returns the inserted row.
  ///
  /// The returned [DwChatParticipant] will have its `id` field set.
  Future<DwChatParticipant> insertRow(
    _i1.Session session,
    DwChatParticipant row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<DwChatParticipant>(
      row,
      transaction: transaction,
    );
  }

  /// Updates all [DwChatParticipant]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  Future<List<DwChatParticipant>> update(
    _i1.Session session,
    List<DwChatParticipant> rows, {
    _i1.ColumnSelections<DwChatParticipantTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.update<DwChatParticipant>(
      rows,
      columns: columns?.call(DwChatParticipant.t),
      transaction: transaction,
    );
  }

  /// Updates a single [DwChatParticipant]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<DwChatParticipant> updateRow(
    _i1.Session session,
    DwChatParticipant row, {
    _i1.ColumnSelections<DwChatParticipantTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<DwChatParticipant>(
      row,
      columns: columns?.call(DwChatParticipant.t),
      transaction: transaction,
    );
  }

  /// Deletes all [DwChatParticipant]s in the list and returns the deleted rows.
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  Future<List<DwChatParticipant>> delete(
    _i1.Session session,
    List<DwChatParticipant> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<DwChatParticipant>(
      rows,
      transaction: transaction,
    );
  }

  /// Deletes a single [DwChatParticipant].
  Future<DwChatParticipant> deleteRow(
    _i1.Session session,
    DwChatParticipant row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<DwChatParticipant>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  Future<List<DwChatParticipant>> deleteWhere(
    _i1.Session session, {
    required _i1.WhereExpressionBuilder<DwChatParticipantTable> where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteWhere<DwChatParticipant>(
      where: where(DwChatParticipant.t),
      transaction: transaction,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.Session session, {
    _i1.WhereExpressionBuilder<DwChatParticipantTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<DwChatParticipant>(
      where: where?.call(DwChatParticipant.t),
      limit: limit,
      transaction: transaction,
    );
  }
}

class DwChatParticipantAttachRowRepository {
  const DwChatParticipantAttachRowRepository._();

  /// Creates a relation between the given [DwChatParticipant] and [DwChatChannel]
  /// by setting the [DwChatParticipant]'s foreign key `chatChannelId` to refer to the [DwChatChannel].
  Future<void> chatChannel(
    _i1.Session session,
    DwChatParticipant dwChatParticipant,
    _i2.DwChatChannel chatChannel, {
    _i1.Transaction? transaction,
  }) async {
    if (dwChatParticipant.id == null) {
      throw ArgumentError.notNull('dwChatParticipant.id');
    }
    if (chatChannel.id == null) {
      throw ArgumentError.notNull('chatChannel.id');
    }

    var $dwChatParticipant =
        dwChatParticipant.copyWith(chatChannelId: chatChannel.id);
    await session.db.updateRow<DwChatParticipant>(
      $dwChatParticipant,
      columns: [DwChatParticipant.t.chatChannelId],
      transaction: transaction,
    );
  }

  /// Creates a relation between the given [DwChatParticipant] and [DwChatMessage]
  /// by setting the [DwChatParticipant]'s foreign key `lastMessageId` to refer to the [DwChatMessage].
  Future<void> lastMessage(
    _i1.Session session,
    DwChatParticipant dwChatParticipant,
    _i3.DwChatMessage lastMessage, {
    _i1.Transaction? transaction,
  }) async {
    if (dwChatParticipant.id == null) {
      throw ArgumentError.notNull('dwChatParticipant.id');
    }
    if (lastMessage.id == null) {
      throw ArgumentError.notNull('lastMessage.id');
    }

    var $dwChatParticipant =
        dwChatParticipant.copyWith(lastMessageId: lastMessage.id);
    await session.db.updateRow<DwChatParticipant>(
      $dwChatParticipant,
      columns: [DwChatParticipant.t.lastMessageId],
      transaction: transaction,
    );
  }

  /// Creates a relation between the given [DwChatParticipant] and [DwChatMessage]
  /// by setting the [DwChatParticipant]'s foreign key `lastReadMessageId` to refer to the [DwChatMessage].
  Future<void> lastReadMessage(
    _i1.Session session,
    DwChatParticipant dwChatParticipant,
    _i3.DwChatMessage lastReadMessage, {
    _i1.Transaction? transaction,
  }) async {
    if (dwChatParticipant.id == null) {
      throw ArgumentError.notNull('dwChatParticipant.id');
    }
    if (lastReadMessage.id == null) {
      throw ArgumentError.notNull('lastReadMessage.id');
    }

    var $dwChatParticipant =
        dwChatParticipant.copyWith(lastReadMessageId: lastReadMessage.id);
    await session.db.updateRow<DwChatParticipant>(
      $dwChatParticipant,
      columns: [DwChatParticipant.t.lastReadMessageId],
      transaction: transaction,
    );
  }
}

class DwChatParticipantDetachRowRepository {
  const DwChatParticipantDetachRowRepository._();

  /// Detaches the relation between this [DwChatParticipant] and the [DwChatMessage] set in `lastMessage`
  /// by setting the [DwChatParticipant]'s foreign key `lastMessageId` to `null`.
  ///
  /// This removes the association between the two models without deleting
  /// the related record.
  Future<void> lastMessage(
    _i1.Session session,
    DwChatParticipant dwchatparticipant, {
    _i1.Transaction? transaction,
  }) async {
    if (dwchatparticipant.id == null) {
      throw ArgumentError.notNull('dwchatparticipant.id');
    }

    var $dwchatparticipant = dwchatparticipant.copyWith(lastMessageId: null);
    await session.db.updateRow<DwChatParticipant>(
      $dwchatparticipant,
      columns: [DwChatParticipant.t.lastMessageId],
      transaction: transaction,
    );
  }

  /// Detaches the relation between this [DwChatParticipant] and the [DwChatMessage] set in `lastReadMessage`
  /// by setting the [DwChatParticipant]'s foreign key `lastReadMessageId` to `null`.
  ///
  /// This removes the association between the two models without deleting
  /// the related record.
  Future<void> lastReadMessage(
    _i1.Session session,
    DwChatParticipant dwchatparticipant, {
    _i1.Transaction? transaction,
  }) async {
    if (dwchatparticipant.id == null) {
      throw ArgumentError.notNull('dwchatparticipant.id');
    }

    var $dwchatparticipant =
        dwchatparticipant.copyWith(lastReadMessageId: null);
    await session.db.updateRow<DwChatParticipant>(
      $dwchatparticipant,
      columns: [DwChatParticipant.t.lastReadMessageId],
      transaction: transaction,
    );
  }
}
