/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member
// ignore_for_file: unnecessary_null_comparison

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod/serverpod.dart' as _i1;
import '../chat/chat_channel.dart' as _i2;
import '../user_profile/user_profile.dart' as _i3;
import 'package:dartway_example_server/src/generated/protocol.dart' as _i4;

abstract class ChatMessage
    implements _i1.TableRow<int?>, _i1.ProtocolSerialization {
  ChatMessage._({
    this.id,
    required this.channelId,
    this.channel,
    required this.authorProfileId,
    this.authorProfile,
    required this.messageText,
    required this.createdAt,
  });

  factory ChatMessage({
    int? id,
    required int channelId,
    _i2.ChatChannel? channel,
    required int authorProfileId,
    _i3.UserProfile? authorProfile,
    required String messageText,
    required DateTime createdAt,
  }) = _ChatMessageImpl;

  factory ChatMessage.fromJson(Map<String, dynamic> jsonSerialization) {
    return ChatMessage(
      id: jsonSerialization['id'] as int?,
      channelId: jsonSerialization['channelId'] as int,
      channel: jsonSerialization['channel'] == null
          ? null
          : _i4.Protocol().deserialize<_i2.ChatChannel>(
              jsonSerialization['channel'],
            ),
      authorProfileId: jsonSerialization['authorProfileId'] as int,
      authorProfile: jsonSerialization['authorProfile'] == null
          ? null
          : _i4.Protocol().deserialize<_i3.UserProfile>(
              jsonSerialization['authorProfile'],
            ),
      messageText: jsonSerialization['messageText'] as String,
      createdAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
    );
  }

  static final t = ChatMessageTable();

  static const db = ChatMessageRepository._();

  @override
  int? id;

  int channelId;

  _i2.ChatChannel? channel;

  int authorProfileId;

  _i3.UserProfile? authorProfile;

  String messageText;

  DateTime createdAt;

  @override
  _i1.Table<int?> get table => t;

  /// Returns a shallow copy of this [ChatMessage]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  ChatMessage copyWith({
    int? id,
    int? channelId,
    _i2.ChatChannel? channel,
    int? authorProfileId,
    _i3.UserProfile? authorProfile,
    String? messageText,
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'ChatMessage',
      if (id != null) 'id': id,
      'channelId': channelId,
      if (channel != null) 'channel': channel?.toJson(),
      'authorProfileId': authorProfileId,
      if (authorProfile != null) 'authorProfile': authorProfile?.toJson(),
      'messageText': messageText,
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'ChatMessage',
      if (id != null) 'id': id,
      'channelId': channelId,
      if (channel != null) 'channel': channel?.toJsonForProtocol(),
      'authorProfileId': authorProfileId,
      if (authorProfile != null)
        'authorProfile': authorProfile?.toJsonForProtocol(),
      'messageText': messageText,
      'createdAt': createdAt.toJson(),
    };
  }

  static ChatMessageInclude include({
    _i2.ChatChannelInclude? channel,
    _i3.UserProfileInclude? authorProfile,
  }) {
    return ChatMessageInclude._(
      channel: channel,
      authorProfile: authorProfile,
    );
  }

  static ChatMessageIncludeList includeList({
    _i1.WhereExpressionBuilder<ChatMessageTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<ChatMessageTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<ChatMessageTable>? orderByList,
    ChatMessageInclude? include,
  }) {
    return ChatMessageIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(ChatMessage.t),
      orderDescending: orderDescending,
      orderByList: orderByList?.call(ChatMessage.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _ChatMessageImpl extends ChatMessage {
  _ChatMessageImpl({
    int? id,
    required int channelId,
    _i2.ChatChannel? channel,
    required int authorProfileId,
    _i3.UserProfile? authorProfile,
    required String messageText,
    required DateTime createdAt,
  }) : super._(
         id: id,
         channelId: channelId,
         channel: channel,
         authorProfileId: authorProfileId,
         authorProfile: authorProfile,
         messageText: messageText,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [ChatMessage]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  ChatMessage copyWith({
    Object? id = _Undefined,
    int? channelId,
    Object? channel = _Undefined,
    int? authorProfileId,
    Object? authorProfile = _Undefined,
    String? messageText,
    DateTime? createdAt,
  }) {
    return ChatMessage(
      id: id is int? ? id : this.id,
      channelId: channelId ?? this.channelId,
      channel: channel is _i2.ChatChannel? ? channel : this.channel?.copyWith(),
      authorProfileId: authorProfileId ?? this.authorProfileId,
      authorProfile: authorProfile is _i3.UserProfile?
          ? authorProfile
          : this.authorProfile?.copyWith(),
      messageText: messageText ?? this.messageText,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class ChatMessageUpdateTable extends _i1.UpdateTable<ChatMessageTable> {
  ChatMessageUpdateTable(super.table);

  _i1.ColumnValue<int, int> channelId(int value) => _i1.ColumnValue(
    table.channelId,
    value,
  );

  _i1.ColumnValue<int, int> authorProfileId(int value) => _i1.ColumnValue(
    table.authorProfileId,
    value,
  );

  _i1.ColumnValue<String, String> messageText(String value) => _i1.ColumnValue(
    table.messageText,
    value,
  );

  _i1.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _i1.ColumnValue(
        table.createdAt,
        value,
      );
}

class ChatMessageTable extends _i1.Table<int?> {
  ChatMessageTable({super.tableRelation}) : super(tableName: 'chat_message') {
    updateTable = ChatMessageUpdateTable(this);
    channelId = _i1.ColumnInt(
      'channelId',
      this,
    );
    authorProfileId = _i1.ColumnInt(
      'authorProfileId',
      this,
    );
    messageText = _i1.ColumnString(
      'messageText',
      this,
    );
    createdAt = _i1.ColumnDateTime(
      'createdAt',
      this,
    );
  }

  late final ChatMessageUpdateTable updateTable;

  late final _i1.ColumnInt channelId;

  _i2.ChatChannelTable? _channel;

  late final _i1.ColumnInt authorProfileId;

  _i3.UserProfileTable? _authorProfile;

  late final _i1.ColumnString messageText;

  late final _i1.ColumnDateTime createdAt;

  _i2.ChatChannelTable get channel {
    if (_channel != null) return _channel!;
    _channel = _i1.createRelationTable(
      relationFieldName: 'channel',
      field: ChatMessage.t.channelId,
      foreignField: _i2.ChatChannel.t.id,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _i2.ChatChannelTable(tableRelation: foreignTableRelation),
    );
    return _channel!;
  }

  _i3.UserProfileTable get authorProfile {
    if (_authorProfile != null) return _authorProfile!;
    _authorProfile = _i1.createRelationTable(
      relationFieldName: 'authorProfile',
      field: ChatMessage.t.authorProfileId,
      foreignField: _i3.UserProfile.t.id,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _i3.UserProfileTable(tableRelation: foreignTableRelation),
    );
    return _authorProfile!;
  }

  @override
  List<_i1.Column> get columns => [
    id,
    channelId,
    authorProfileId,
    messageText,
    createdAt,
  ];

  @override
  _i1.Table? getRelationTable(String relationField) {
    if (relationField == 'channel') {
      return channel;
    }
    if (relationField == 'authorProfile') {
      return authorProfile;
    }
    return null;
  }
}

class ChatMessageInclude extends _i1.IncludeObject {
  ChatMessageInclude._({
    _i2.ChatChannelInclude? channel,
    _i3.UserProfileInclude? authorProfile,
  }) {
    _channel = channel;
    _authorProfile = authorProfile;
  }

  _i2.ChatChannelInclude? _channel;

  _i3.UserProfileInclude? _authorProfile;

  @override
  Map<String, _i1.Include?> get includes => {
    'channel': _channel,
    'authorProfile': _authorProfile,
  };

  @override
  _i1.Table<int?> get table => ChatMessage.t;
}

class ChatMessageIncludeList extends _i1.IncludeList {
  ChatMessageIncludeList._({
    _i1.WhereExpressionBuilder<ChatMessageTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(ChatMessage.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<int?> get table => ChatMessage.t;
}

class ChatMessageRepository {
  const ChatMessageRepository._();

  final attachRow = const ChatMessageAttachRowRepository._();

  /// Returns a list of [ChatMessage]s matching the given query parameters.
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
  Future<List<ChatMessage>> find(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<ChatMessageTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<ChatMessageTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<ChatMessageTable>? orderByList,
    _i1.Transaction? transaction,
    ChatMessageInclude? include,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<ChatMessage>(
      where: where?.call(ChatMessage.t),
      orderBy: orderBy?.call(ChatMessage.t),
      orderByList: orderByList?.call(ChatMessage.t),
      orderDescending: orderDescending,
      limit: limit,
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [ChatMessage] matching the given query parameters.
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
  Future<ChatMessage?> findFirstRow(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<ChatMessageTable>? where,
    int? offset,
    _i1.OrderByBuilder<ChatMessageTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<ChatMessageTable>? orderByList,
    _i1.Transaction? transaction,
    ChatMessageInclude? include,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<ChatMessage>(
      where: where?.call(ChatMessage.t),
      orderBy: orderBy?.call(ChatMessage.t),
      orderByList: orderByList?.call(ChatMessage.t),
      orderDescending: orderDescending,
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [ChatMessage] by its [id] or null if no such row exists.
  Future<ChatMessage?> findById(
    _i1.DatabaseSession session,
    int id, {
    _i1.Transaction? transaction,
    ChatMessageInclude? include,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<ChatMessage>(
      id,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [ChatMessage]s in the list and returns the inserted rows.
  ///
  /// The returned [ChatMessage]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  ///
  /// If [ignoreConflicts] is set to `true`, rows that conflict with existing
  /// rows are silently skipped, and only the successfully inserted rows are
  /// returned.
  Future<List<ChatMessage>> insert(
    _i1.DatabaseSession session,
    List<ChatMessage> rows, {
    _i1.Transaction? transaction,
    bool ignoreConflicts = false,
  }) async {
    return session.db.insert<ChatMessage>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
    );
  }

  /// Inserts a single [ChatMessage] and returns the inserted row.
  ///
  /// The returned [ChatMessage] will have its `id` field set.
  Future<ChatMessage> insertRow(
    _i1.DatabaseSession session,
    ChatMessage row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<ChatMessage>(
      row,
      transaction: transaction,
    );
  }

  /// Updates all [ChatMessage]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  Future<List<ChatMessage>> update(
    _i1.DatabaseSession session,
    List<ChatMessage> rows, {
    _i1.ColumnSelections<ChatMessageTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.update<ChatMessage>(
      rows,
      columns: columns?.call(ChatMessage.t),
      transaction: transaction,
    );
  }

  /// Updates a single [ChatMessage]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<ChatMessage> updateRow(
    _i1.DatabaseSession session,
    ChatMessage row, {
    _i1.ColumnSelections<ChatMessageTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<ChatMessage>(
      row,
      columns: columns?.call(ChatMessage.t),
      transaction: transaction,
    );
  }

  /// Updates a single [ChatMessage] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<ChatMessage?> updateById(
    _i1.DatabaseSession session,
    int id, {
    required _i1.ColumnValueListBuilder<ChatMessageUpdateTable> columnValues,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateById<ChatMessage>(
      id,
      columnValues: columnValues(ChatMessage.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [ChatMessage]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  Future<List<ChatMessage>> updateWhere(
    _i1.DatabaseSession session, {
    required _i1.ColumnValueListBuilder<ChatMessageUpdateTable> columnValues,
    required _i1.WhereExpressionBuilder<ChatMessageTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<ChatMessageTable>? orderBy,
    _i1.OrderByListBuilder<ChatMessageTable>? orderByList,
    bool orderDescending = false,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateWhere<ChatMessage>(
      columnValues: columnValues(ChatMessage.t.updateTable),
      where: where(ChatMessage.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(ChatMessage.t),
      orderByList: orderByList?.call(ChatMessage.t),
      orderDescending: orderDescending,
      transaction: transaction,
    );
  }

  /// Deletes all [ChatMessage]s in the list and returns the deleted rows.
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  Future<List<ChatMessage>> delete(
    _i1.DatabaseSession session,
    List<ChatMessage> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<ChatMessage>(
      rows,
      transaction: transaction,
    );
  }

  /// Deletes a single [ChatMessage].
  Future<ChatMessage> deleteRow(
    _i1.DatabaseSession session,
    ChatMessage row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<ChatMessage>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  Future<List<ChatMessage>> deleteWhere(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<ChatMessageTable> where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteWhere<ChatMessage>(
      where: where(ChatMessage.t),
      transaction: transaction,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<ChatMessageTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<ChatMessage>(
      where: where?.call(ChatMessage.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [ChatMessage] rows matching the [where] expression.
  Future<void> lockRows(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<ChatMessageTable> where,
    required _i1.LockMode lockMode,
    required _i1.Transaction transaction,
    _i1.LockBehavior lockBehavior = _i1.LockBehavior.wait,
  }) async {
    return session.db.lockRows<ChatMessage>(
      where: where(ChatMessage.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

class ChatMessageAttachRowRepository {
  const ChatMessageAttachRowRepository._();

  /// Creates a relation between the given [ChatMessage] and [ChatChannel]
  /// by setting the [ChatMessage]'s foreign key `channelId` to refer to the [ChatChannel].
  Future<void> channel(
    _i1.DatabaseSession session,
    ChatMessage chatMessage,
    _i2.ChatChannel channel, {
    _i1.Transaction? transaction,
  }) async {
    if (chatMessage.id == null) {
      throw ArgumentError.notNull('chatMessage.id');
    }
    if (channel.id == null) {
      throw ArgumentError.notNull('channel.id');
    }

    var $chatMessage = chatMessage.copyWith(channelId: channel.id);
    await session.db.updateRow<ChatMessage>(
      $chatMessage,
      columns: [ChatMessage.t.channelId],
      transaction: transaction,
    );
  }

  /// Creates a relation between the given [ChatMessage] and [UserProfile]
  /// by setting the [ChatMessage]'s foreign key `authorProfileId` to refer to the [UserProfile].
  Future<void> authorProfile(
    _i1.DatabaseSession session,
    ChatMessage chatMessage,
    _i3.UserProfile authorProfile, {
    _i1.Transaction? transaction,
  }) async {
    if (chatMessage.id == null) {
      throw ArgumentError.notNull('chatMessage.id');
    }
    if (authorProfile.id == null) {
      throw ArgumentError.notNull('authorProfile.id');
    }

    var $chatMessage = chatMessage.copyWith(authorProfileId: authorProfile.id);
    await session.db.updateRow<ChatMessage>(
      $chatMessage,
      columns: [ChatMessage.t.authorProfileId],
      transaction: transaction,
    );
  }
}
