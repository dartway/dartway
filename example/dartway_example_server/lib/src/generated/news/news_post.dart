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
import '../user_profile/user_profile.dart' as _i2;
import 'package:dartway_example_server/src/generated/protocol.dart' as _i3;

abstract class NewsPost
    implements _i1.TableRow<int?>, _i1.ProtocolSerialization {
  NewsPost._({
    this.id,
    required this.authorProfileId,
    this.authorProfile,
    required this.title,
    required this.text,
    required this.createdAt,
  });

  factory NewsPost({
    int? id,
    required int authorProfileId,
    _i2.UserProfile? authorProfile,
    required String title,
    required String text,
    required DateTime createdAt,
  }) = _NewsPostImpl;

  factory NewsPost.fromJson(Map<String, dynamic> jsonSerialization) {
    return NewsPost(
      id: jsonSerialization['id'] as int?,
      authorProfileId: jsonSerialization['authorProfileId'] as int,
      authorProfile: jsonSerialization['authorProfile'] == null
          ? null
          : _i3.Protocol().deserialize<_i2.UserProfile>(
              jsonSerialization['authorProfile'],
            ),
      title: jsonSerialization['title'] as String,
      text: jsonSerialization['text'] as String,
      createdAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
    );
  }

  static final t = NewsPostTable();

  static const db = NewsPostRepository._();

  @override
  int? id;

  int authorProfileId;

  _i2.UserProfile? authorProfile;

  String title;

  String text;

  DateTime createdAt;

  @override
  _i1.Table<int?> get table => t;

  /// Returns a shallow copy of this [NewsPost]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  NewsPost copyWith({
    int? id,
    int? authorProfileId,
    _i2.UserProfile? authorProfile,
    String? title,
    String? text,
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'NewsPost',
      if (id != null) 'id': id,
      'authorProfileId': authorProfileId,
      if (authorProfile != null) 'authorProfile': authorProfile?.toJson(),
      'title': title,
      'text': text,
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'NewsPost',
      if (id != null) 'id': id,
      'authorProfileId': authorProfileId,
      if (authorProfile != null)
        'authorProfile': authorProfile?.toJsonForProtocol(),
      'title': title,
      'text': text,
      'createdAt': createdAt.toJson(),
    };
  }

  static NewsPostInclude include({_i2.UserProfileInclude? authorProfile}) {
    return NewsPostInclude._(authorProfile: authorProfile);
  }

  static NewsPostIncludeList includeList({
    _i1.WhereExpressionBuilder<NewsPostTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<NewsPostTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<NewsPostTable>? orderByList,
    NewsPostInclude? include,
  }) {
    return NewsPostIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(NewsPost.t),
      orderDescending: orderDescending,
      orderByList: orderByList?.call(NewsPost.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _NewsPostImpl extends NewsPost {
  _NewsPostImpl({
    int? id,
    required int authorProfileId,
    _i2.UserProfile? authorProfile,
    required String title,
    required String text,
    required DateTime createdAt,
  }) : super._(
         id: id,
         authorProfileId: authorProfileId,
         authorProfile: authorProfile,
         title: title,
         text: text,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [NewsPost]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  NewsPost copyWith({
    Object? id = _Undefined,
    int? authorProfileId,
    Object? authorProfile = _Undefined,
    String? title,
    String? text,
    DateTime? createdAt,
  }) {
    return NewsPost(
      id: id is int? ? id : this.id,
      authorProfileId: authorProfileId ?? this.authorProfileId,
      authorProfile: authorProfile is _i2.UserProfile?
          ? authorProfile
          : this.authorProfile?.copyWith(),
      title: title ?? this.title,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class NewsPostUpdateTable extends _i1.UpdateTable<NewsPostTable> {
  NewsPostUpdateTable(super.table);

  _i1.ColumnValue<int, int> authorProfileId(int value) => _i1.ColumnValue(
    table.authorProfileId,
    value,
  );

  _i1.ColumnValue<String, String> title(String value) => _i1.ColumnValue(
    table.title,
    value,
  );

  _i1.ColumnValue<String, String> text(String value) => _i1.ColumnValue(
    table.text,
    value,
  );

  _i1.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _i1.ColumnValue(
        table.createdAt,
        value,
      );
}

class NewsPostTable extends _i1.Table<int?> {
  NewsPostTable({super.tableRelation}) : super(tableName: 'news_post') {
    updateTable = NewsPostUpdateTable(this);
    authorProfileId = _i1.ColumnInt(
      'authorProfileId',
      this,
    );
    title = _i1.ColumnString(
      'title',
      this,
    );
    text = _i1.ColumnString(
      'text',
      this,
    );
    createdAt = _i1.ColumnDateTime(
      'createdAt',
      this,
    );
  }

  late final NewsPostUpdateTable updateTable;

  late final _i1.ColumnInt authorProfileId;

  _i2.UserProfileTable? _authorProfile;

  late final _i1.ColumnString title;

  late final _i1.ColumnString text;

  late final _i1.ColumnDateTime createdAt;

  _i2.UserProfileTable get authorProfile {
    if (_authorProfile != null) return _authorProfile!;
    _authorProfile = _i1.createRelationTable(
      relationFieldName: 'authorProfile',
      field: NewsPost.t.authorProfileId,
      foreignField: _i2.UserProfile.t.id,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _i2.UserProfileTable(tableRelation: foreignTableRelation),
    );
    return _authorProfile!;
  }

  @override
  List<_i1.Column> get columns => [
    id,
    authorProfileId,
    title,
    text,
    createdAt,
  ];

  @override
  _i1.Table? getRelationTable(String relationField) {
    if (relationField == 'authorProfile') {
      return authorProfile;
    }
    return null;
  }
}

class NewsPostInclude extends _i1.IncludeObject {
  NewsPostInclude._({_i2.UserProfileInclude? authorProfile}) {
    _authorProfile = authorProfile;
  }

  _i2.UserProfileInclude? _authorProfile;

  @override
  Map<String, _i1.Include?> get includes => {'authorProfile': _authorProfile};

  @override
  _i1.Table<int?> get table => NewsPost.t;
}

class NewsPostIncludeList extends _i1.IncludeList {
  NewsPostIncludeList._({
    _i1.WhereExpressionBuilder<NewsPostTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(NewsPost.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<int?> get table => NewsPost.t;
}

class NewsPostRepository {
  const NewsPostRepository._();

  final attachRow = const NewsPostAttachRowRepository._();

  /// Returns a list of [NewsPost]s matching the given query parameters.
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
  Future<List<NewsPost>> find(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<NewsPostTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<NewsPostTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<NewsPostTable>? orderByList,
    _i1.Transaction? transaction,
    NewsPostInclude? include,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<NewsPost>(
      where: where?.call(NewsPost.t),
      orderBy: orderBy?.call(NewsPost.t),
      orderByList: orderByList?.call(NewsPost.t),
      orderDescending: orderDescending,
      limit: limit,
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [NewsPost] matching the given query parameters.
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
  Future<NewsPost?> findFirstRow(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<NewsPostTable>? where,
    int? offset,
    _i1.OrderByBuilder<NewsPostTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<NewsPostTable>? orderByList,
    _i1.Transaction? transaction,
    NewsPostInclude? include,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<NewsPost>(
      where: where?.call(NewsPost.t),
      orderBy: orderBy?.call(NewsPost.t),
      orderByList: orderByList?.call(NewsPost.t),
      orderDescending: orderDescending,
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [NewsPost] by its [id] or null if no such row exists.
  Future<NewsPost?> findById(
    _i1.DatabaseSession session,
    int id, {
    _i1.Transaction? transaction,
    NewsPostInclude? include,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<NewsPost>(
      id,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [NewsPost]s in the list and returns the inserted rows.
  ///
  /// The returned [NewsPost]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  ///
  /// If [ignoreConflicts] is set to `true`, rows that conflict with existing
  /// rows are silently skipped, and only the successfully inserted rows are
  /// returned.
  Future<List<NewsPost>> insert(
    _i1.DatabaseSession session,
    List<NewsPost> rows, {
    _i1.Transaction? transaction,
    bool ignoreConflicts = false,
  }) async {
    return session.db.insert<NewsPost>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
    );
  }

  /// Inserts a single [NewsPost] and returns the inserted row.
  ///
  /// The returned [NewsPost] will have its `id` field set.
  Future<NewsPost> insertRow(
    _i1.DatabaseSession session,
    NewsPost row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<NewsPost>(
      row,
      transaction: transaction,
    );
  }

  /// Updates all [NewsPost]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  Future<List<NewsPost>> update(
    _i1.DatabaseSession session,
    List<NewsPost> rows, {
    _i1.ColumnSelections<NewsPostTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.update<NewsPost>(
      rows,
      columns: columns?.call(NewsPost.t),
      transaction: transaction,
    );
  }

  /// Updates a single [NewsPost]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<NewsPost> updateRow(
    _i1.DatabaseSession session,
    NewsPost row, {
    _i1.ColumnSelections<NewsPostTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<NewsPost>(
      row,
      columns: columns?.call(NewsPost.t),
      transaction: transaction,
    );
  }

  /// Updates a single [NewsPost] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<NewsPost?> updateById(
    _i1.DatabaseSession session,
    int id, {
    required _i1.ColumnValueListBuilder<NewsPostUpdateTable> columnValues,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateById<NewsPost>(
      id,
      columnValues: columnValues(NewsPost.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [NewsPost]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  Future<List<NewsPost>> updateWhere(
    _i1.DatabaseSession session, {
    required _i1.ColumnValueListBuilder<NewsPostUpdateTable> columnValues,
    required _i1.WhereExpressionBuilder<NewsPostTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<NewsPostTable>? orderBy,
    _i1.OrderByListBuilder<NewsPostTable>? orderByList,
    bool orderDescending = false,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateWhere<NewsPost>(
      columnValues: columnValues(NewsPost.t.updateTable),
      where: where(NewsPost.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(NewsPost.t),
      orderByList: orderByList?.call(NewsPost.t),
      orderDescending: orderDescending,
      transaction: transaction,
    );
  }

  /// Deletes all [NewsPost]s in the list and returns the deleted rows.
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  Future<List<NewsPost>> delete(
    _i1.DatabaseSession session,
    List<NewsPost> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<NewsPost>(
      rows,
      transaction: transaction,
    );
  }

  /// Deletes a single [NewsPost].
  Future<NewsPost> deleteRow(
    _i1.DatabaseSession session,
    NewsPost row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<NewsPost>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  Future<List<NewsPost>> deleteWhere(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<NewsPostTable> where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteWhere<NewsPost>(
      where: where(NewsPost.t),
      transaction: transaction,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<NewsPostTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<NewsPost>(
      where: where?.call(NewsPost.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [NewsPost] rows matching the [where] expression.
  Future<void> lockRows(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<NewsPostTable> where,
    required _i1.LockMode lockMode,
    required _i1.Transaction transaction,
    _i1.LockBehavior lockBehavior = _i1.LockBehavior.wait,
  }) async {
    return session.db.lockRows<NewsPost>(
      where: where(NewsPost.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

class NewsPostAttachRowRepository {
  const NewsPostAttachRowRepository._();

  /// Creates a relation between the given [NewsPost] and [UserProfile]
  /// by setting the [NewsPost]'s foreign key `authorProfileId` to refer to the [UserProfile].
  Future<void> authorProfile(
    _i1.DatabaseSession session,
    NewsPost newsPost,
    _i2.UserProfile authorProfile, {
    _i1.Transaction? transaction,
  }) async {
    if (newsPost.id == null) {
      throw ArgumentError.notNull('newsPost.id');
    }
    if (authorProfile.id == null) {
      throw ArgumentError.notNull('authorProfile.id');
    }

    var $newsPost = newsPost.copyWith(authorProfileId: authorProfile.id);
    await session.db.updateRow<NewsPost>(
      $newsPost,
      columns: [NewsPost.t.authorProfileId],
      transaction: transaction,
    );
  }
}
