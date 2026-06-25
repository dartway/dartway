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
import '../user_profile/user_profile.dart' as _i2;

abstract class FeedPost
    implements _i1.TableRow<int?>, _i1.ProtocolSerialization {
  FeedPost._({
    this.id,
    required this.authorProfileId,
    this.authorProfile,
    required this.title,
    required this.text,
    required this.createdAt,
  });

  factory FeedPost({
    int? id,
    required int authorProfileId,
    _i2.UserProfile? authorProfile,
    required String title,
    required String text,
    required DateTime createdAt,
  }) = _FeedPostImpl;

  factory FeedPost.fromJson(Map<String, dynamic> jsonSerialization) {
    return FeedPost(
      id: jsonSerialization['id'] as int?,
      authorProfileId: jsonSerialization['authorProfileId'] as int,
      authorProfile: jsonSerialization['authorProfile'] == null
          ? null
          : _i2.UserProfile.fromJson(
              (jsonSerialization['authorProfile'] as Map<String, dynamic>)),
      title: jsonSerialization['title'] as String,
      text: jsonSerialization['text'] as String,
      createdAt:
          _i1.DateTimeJsonExtension.fromJson(jsonSerialization['createdAt']),
    );
  }

  static final t = FeedPostTable();

  static const db = FeedPostRepository._();

  @override
  int? id;

  int authorProfileId;

  _i2.UserProfile? authorProfile;

  String title;

  String text;

  DateTime createdAt;

  @override
  _i1.Table<int?> get table => t;

  /// Returns a shallow copy of this [FeedPost]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  FeedPost copyWith({
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
      if (id != null) 'id': id,
      'authorProfileId': authorProfileId,
      if (authorProfile != null)
        'authorProfile': authorProfile?.toJsonForProtocol(),
      'title': title,
      'text': text,
      'createdAt': createdAt.toJson(),
    };
  }

  static FeedPostInclude include({_i2.UserProfileInclude? authorProfile}) {
    return FeedPostInclude._(authorProfile: authorProfile);
  }

  static FeedPostIncludeList includeList({
    _i1.WhereExpressionBuilder<FeedPostTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<FeedPostTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<FeedPostTable>? orderByList,
    FeedPostInclude? include,
  }) {
    return FeedPostIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(FeedPost.t),
      orderDescending: orderDescending,
      orderByList: orderByList?.call(FeedPost.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _FeedPostImpl extends FeedPost {
  _FeedPostImpl({
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

  /// Returns a shallow copy of this [FeedPost]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  FeedPost copyWith({
    Object? id = _Undefined,
    int? authorProfileId,
    Object? authorProfile = _Undefined,
    String? title,
    String? text,
    DateTime? createdAt,
  }) {
    return FeedPost(
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

class FeedPostTable extends _i1.Table<int?> {
  FeedPostTable({super.tableRelation}) : super(tableName: 'feed_post') {
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

  late final _i1.ColumnInt authorProfileId;

  _i2.UserProfileTable? _authorProfile;

  late final _i1.ColumnString title;

  late final _i1.ColumnString text;

  late final _i1.ColumnDateTime createdAt;

  _i2.UserProfileTable get authorProfile {
    if (_authorProfile != null) return _authorProfile!;
    _authorProfile = _i1.createRelationTable(
      relationFieldName: 'authorProfile',
      field: FeedPost.t.authorProfileId,
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

class FeedPostInclude extends _i1.IncludeObject {
  FeedPostInclude._({_i2.UserProfileInclude? authorProfile}) {
    _authorProfile = authorProfile;
  }

  _i2.UserProfileInclude? _authorProfile;

  @override
  Map<String, _i1.Include?> get includes => {'authorProfile': _authorProfile};

  @override
  _i1.Table<int?> get table => FeedPost.t;
}

class FeedPostIncludeList extends _i1.IncludeList {
  FeedPostIncludeList._({
    _i1.WhereExpressionBuilder<FeedPostTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(FeedPost.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<int?> get table => FeedPost.t;
}

class FeedPostRepository {
  const FeedPostRepository._();

  final attachRow = const FeedPostAttachRowRepository._();

  /// Returns a list of [FeedPost]s matching the given query parameters.
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
  Future<List<FeedPost>> find(
    _i1.Session session, {
    _i1.WhereExpressionBuilder<FeedPostTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<FeedPostTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<FeedPostTable>? orderByList,
    _i1.Transaction? transaction,
    FeedPostInclude? include,
  }) async {
    return session.db.find<FeedPost>(
      where: where?.call(FeedPost.t),
      orderBy: orderBy?.call(FeedPost.t),
      orderByList: orderByList?.call(FeedPost.t),
      orderDescending: orderDescending,
      limit: limit,
      offset: offset,
      transaction: transaction,
      include: include,
    );
  }

  /// Returns the first matching [FeedPost] matching the given query parameters.
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
  Future<FeedPost?> findFirstRow(
    _i1.Session session, {
    _i1.WhereExpressionBuilder<FeedPostTable>? where,
    int? offset,
    _i1.OrderByBuilder<FeedPostTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<FeedPostTable>? orderByList,
    _i1.Transaction? transaction,
    FeedPostInclude? include,
  }) async {
    return session.db.findFirstRow<FeedPost>(
      where: where?.call(FeedPost.t),
      orderBy: orderBy?.call(FeedPost.t),
      orderByList: orderByList?.call(FeedPost.t),
      orderDescending: orderDescending,
      offset: offset,
      transaction: transaction,
      include: include,
    );
  }

  /// Finds a single [FeedPost] by its [id] or null if no such row exists.
  Future<FeedPost?> findById(
    _i1.Session session,
    int id, {
    _i1.Transaction? transaction,
    FeedPostInclude? include,
  }) async {
    return session.db.findById<FeedPost>(
      id,
      transaction: transaction,
      include: include,
    );
  }

  /// Inserts all [FeedPost]s in the list and returns the inserted rows.
  ///
  /// The returned [FeedPost]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  Future<List<FeedPost>> insert(
    _i1.Session session,
    List<FeedPost> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insert<FeedPost>(
      rows,
      transaction: transaction,
    );
  }

  /// Inserts a single [FeedPost] and returns the inserted row.
  ///
  /// The returned [FeedPost] will have its `id` field set.
  Future<FeedPost> insertRow(
    _i1.Session session,
    FeedPost row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<FeedPost>(
      row,
      transaction: transaction,
    );
  }

  /// Updates all [FeedPost]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  Future<List<FeedPost>> update(
    _i1.Session session,
    List<FeedPost> rows, {
    _i1.ColumnSelections<FeedPostTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.update<FeedPost>(
      rows,
      columns: columns?.call(FeedPost.t),
      transaction: transaction,
    );
  }

  /// Updates a single [FeedPost]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<FeedPost> updateRow(
    _i1.Session session,
    FeedPost row, {
    _i1.ColumnSelections<FeedPostTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<FeedPost>(
      row,
      columns: columns?.call(FeedPost.t),
      transaction: transaction,
    );
  }

  /// Deletes all [FeedPost]s in the list and returns the deleted rows.
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  Future<List<FeedPost>> delete(
    _i1.Session session,
    List<FeedPost> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<FeedPost>(
      rows,
      transaction: transaction,
    );
  }

  /// Deletes a single [FeedPost].
  Future<FeedPost> deleteRow(
    _i1.Session session,
    FeedPost row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<FeedPost>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  Future<List<FeedPost>> deleteWhere(
    _i1.Session session, {
    required _i1.WhereExpressionBuilder<FeedPostTable> where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteWhere<FeedPost>(
      where: where(FeedPost.t),
      transaction: transaction,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.Session session, {
    _i1.WhereExpressionBuilder<FeedPostTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<FeedPost>(
      where: where?.call(FeedPost.t),
      limit: limit,
      transaction: transaction,
    );
  }
}

class FeedPostAttachRowRepository {
  const FeedPostAttachRowRepository._();

  /// Creates a relation between the given [FeedPost] and [UserProfile]
  /// by setting the [FeedPost]'s foreign key `authorProfileId` to refer to the [UserProfile].
  Future<void> authorProfile(
    _i1.Session session,
    FeedPost feedPost,
    _i2.UserProfile authorProfile, {
    _i1.Transaction? transaction,
  }) async {
    if (feedPost.id == null) {
      throw ArgumentError.notNull('feedPost.id');
    }
    if (authorProfile.id == null) {
      throw ArgumentError.notNull('authorProfile.id');
    }

    var $feedPost = feedPost.copyWith(authorProfileId: authorProfile.id);
    await session.db.updateRow<FeedPost>(
      $feedPost,
      columns: [FeedPost.t.authorProfileId],
      transaction: transaction,
    );
  }
}
