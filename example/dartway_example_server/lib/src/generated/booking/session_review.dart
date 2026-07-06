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
import '../booking/session_booking.dart' as _i2;
import 'package:dartway_example_server/src/generated/protocol.dart' as _i3;

abstract class SessionReview
    implements _i1.TableRow<int?>, _i1.ProtocolSerialization {
  SessionReview._({
    this.id,
    required this.bookingId,
    this.booking,
    required this.rating,
    this.reviewText,
    required this.createdAt,
  });

  factory SessionReview({
    int? id,
    required int bookingId,
    _i2.SessionBooking? booking,
    required int rating,
    String? reviewText,
    required DateTime createdAt,
  }) = _SessionReviewImpl;

  factory SessionReview.fromJson(Map<String, dynamic> jsonSerialization) {
    return SessionReview(
      id: jsonSerialization['id'] as int?,
      bookingId: jsonSerialization['bookingId'] as int,
      booking: jsonSerialization['booking'] == null
          ? null
          : _i3.Protocol().deserialize<_i2.SessionBooking>(
              jsonSerialization['booking'],
            ),
      rating: jsonSerialization['rating'] as int,
      reviewText: jsonSerialization['reviewText'] as String?,
      createdAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
    );
  }

  static final t = SessionReviewTable();

  static const db = SessionReviewRepository._();

  @override
  int? id;

  int bookingId;

  _i2.SessionBooking? booking;

  int rating;

  String? reviewText;

  DateTime createdAt;

  @override
  _i1.Table<int?> get table => t;

  /// Returns a shallow copy of this [SessionReview]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  SessionReview copyWith({
    int? id,
    int? bookingId,
    _i2.SessionBooking? booking,
    int? rating,
    String? reviewText,
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'SessionReview',
      if (id != null) 'id': id,
      'bookingId': bookingId,
      if (booking != null) 'booking': booking?.toJson(),
      'rating': rating,
      if (reviewText != null) 'reviewText': reviewText,
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'SessionReview',
      if (id != null) 'id': id,
      'bookingId': bookingId,
      if (booking != null) 'booking': booking?.toJsonForProtocol(),
      'rating': rating,
      if (reviewText != null) 'reviewText': reviewText,
      'createdAt': createdAt.toJson(),
    };
  }

  static SessionReviewInclude include({_i2.SessionBookingInclude? booking}) {
    return SessionReviewInclude._(booking: booking);
  }

  static SessionReviewIncludeList includeList({
    _i1.WhereExpressionBuilder<SessionReviewTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<SessionReviewTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<SessionReviewTable>? orderByList,
    SessionReviewInclude? include,
  }) {
    return SessionReviewIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(SessionReview.t),
      orderDescending: orderDescending,
      orderByList: orderByList?.call(SessionReview.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _SessionReviewImpl extends SessionReview {
  _SessionReviewImpl({
    int? id,
    required int bookingId,
    _i2.SessionBooking? booking,
    required int rating,
    String? reviewText,
    required DateTime createdAt,
  }) : super._(
         id: id,
         bookingId: bookingId,
         booking: booking,
         rating: rating,
         reviewText: reviewText,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [SessionReview]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  SessionReview copyWith({
    Object? id = _Undefined,
    int? bookingId,
    Object? booking = _Undefined,
    int? rating,
    Object? reviewText = _Undefined,
    DateTime? createdAt,
  }) {
    return SessionReview(
      id: id is int? ? id : this.id,
      bookingId: bookingId ?? this.bookingId,
      booking: booking is _i2.SessionBooking?
          ? booking
          : this.booking?.copyWith(),
      rating: rating ?? this.rating,
      reviewText: reviewText is String? ? reviewText : this.reviewText,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class SessionReviewUpdateTable extends _i1.UpdateTable<SessionReviewTable> {
  SessionReviewUpdateTable(super.table);

  _i1.ColumnValue<int, int> bookingId(int value) => _i1.ColumnValue(
    table.bookingId,
    value,
  );

  _i1.ColumnValue<int, int> rating(int value) => _i1.ColumnValue(
    table.rating,
    value,
  );

  _i1.ColumnValue<String, String> reviewText(String? value) => _i1.ColumnValue(
    table.reviewText,
    value,
  );

  _i1.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _i1.ColumnValue(
        table.createdAt,
        value,
      );
}

class SessionReviewTable extends _i1.Table<int?> {
  SessionReviewTable({super.tableRelation})
    : super(tableName: 'session_review') {
    updateTable = SessionReviewUpdateTable(this);
    bookingId = _i1.ColumnInt(
      'bookingId',
      this,
    );
    rating = _i1.ColumnInt(
      'rating',
      this,
    );
    reviewText = _i1.ColumnString(
      'reviewText',
      this,
    );
    createdAt = _i1.ColumnDateTime(
      'createdAt',
      this,
    );
  }

  late final SessionReviewUpdateTable updateTable;

  late final _i1.ColumnInt bookingId;

  _i2.SessionBookingTable? _booking;

  late final _i1.ColumnInt rating;

  late final _i1.ColumnString reviewText;

  late final _i1.ColumnDateTime createdAt;

  _i2.SessionBookingTable get booking {
    if (_booking != null) return _booking!;
    _booking = _i1.createRelationTable(
      relationFieldName: 'booking',
      field: SessionReview.t.bookingId,
      foreignField: _i2.SessionBooking.t.id,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _i2.SessionBookingTable(tableRelation: foreignTableRelation),
    );
    return _booking!;
  }

  @override
  List<_i1.Column> get columns => [
    id,
    bookingId,
    rating,
    reviewText,
    createdAt,
  ];

  @override
  _i1.Table? getRelationTable(String relationField) {
    if (relationField == 'booking') {
      return booking;
    }
    return null;
  }
}

class SessionReviewInclude extends _i1.IncludeObject {
  SessionReviewInclude._({_i2.SessionBookingInclude? booking}) {
    _booking = booking;
  }

  _i2.SessionBookingInclude? _booking;

  @override
  Map<String, _i1.Include?> get includes => {'booking': _booking};

  @override
  _i1.Table<int?> get table => SessionReview.t;
}

class SessionReviewIncludeList extends _i1.IncludeList {
  SessionReviewIncludeList._({
    _i1.WhereExpressionBuilder<SessionReviewTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(SessionReview.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<int?> get table => SessionReview.t;
}

class SessionReviewRepository {
  const SessionReviewRepository._();

  final attachRow = const SessionReviewAttachRowRepository._();

  /// Returns a list of [SessionReview]s matching the given query parameters.
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
  Future<List<SessionReview>> find(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<SessionReviewTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<SessionReviewTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<SessionReviewTable>? orderByList,
    _i1.Transaction? transaction,
    SessionReviewInclude? include,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<SessionReview>(
      where: where?.call(SessionReview.t),
      orderBy: orderBy?.call(SessionReview.t),
      orderByList: orderByList?.call(SessionReview.t),
      orderDescending: orderDescending,
      limit: limit,
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [SessionReview] matching the given query parameters.
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
  Future<SessionReview?> findFirstRow(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<SessionReviewTable>? where,
    int? offset,
    _i1.OrderByBuilder<SessionReviewTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<SessionReviewTable>? orderByList,
    _i1.Transaction? transaction,
    SessionReviewInclude? include,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<SessionReview>(
      where: where?.call(SessionReview.t),
      orderBy: orderBy?.call(SessionReview.t),
      orderByList: orderByList?.call(SessionReview.t),
      orderDescending: orderDescending,
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [SessionReview] by its [id] or null if no such row exists.
  Future<SessionReview?> findById(
    _i1.DatabaseSession session,
    int id, {
    _i1.Transaction? transaction,
    SessionReviewInclude? include,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<SessionReview>(
      id,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [SessionReview]s in the list and returns the inserted rows.
  ///
  /// The returned [SessionReview]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  ///
  /// If [ignoreConflicts] is set to `true`, rows that conflict with existing
  /// rows are silently skipped, and only the successfully inserted rows are
  /// returned.
  Future<List<SessionReview>> insert(
    _i1.DatabaseSession session,
    List<SessionReview> rows, {
    _i1.Transaction? transaction,
    bool ignoreConflicts = false,
  }) async {
    return session.db.insert<SessionReview>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
    );
  }

  /// Inserts a single [SessionReview] and returns the inserted row.
  ///
  /// The returned [SessionReview] will have its `id` field set.
  Future<SessionReview> insertRow(
    _i1.DatabaseSession session,
    SessionReview row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<SessionReview>(
      row,
      transaction: transaction,
    );
  }

  /// Updates all [SessionReview]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  Future<List<SessionReview>> update(
    _i1.DatabaseSession session,
    List<SessionReview> rows, {
    _i1.ColumnSelections<SessionReviewTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.update<SessionReview>(
      rows,
      columns: columns?.call(SessionReview.t),
      transaction: transaction,
    );
  }

  /// Updates a single [SessionReview]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<SessionReview> updateRow(
    _i1.DatabaseSession session,
    SessionReview row, {
    _i1.ColumnSelections<SessionReviewTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<SessionReview>(
      row,
      columns: columns?.call(SessionReview.t),
      transaction: transaction,
    );
  }

  /// Updates a single [SessionReview] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<SessionReview?> updateById(
    _i1.DatabaseSession session,
    int id, {
    required _i1.ColumnValueListBuilder<SessionReviewUpdateTable> columnValues,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateById<SessionReview>(
      id,
      columnValues: columnValues(SessionReview.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [SessionReview]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  Future<List<SessionReview>> updateWhere(
    _i1.DatabaseSession session, {
    required _i1.ColumnValueListBuilder<SessionReviewUpdateTable> columnValues,
    required _i1.WhereExpressionBuilder<SessionReviewTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<SessionReviewTable>? orderBy,
    _i1.OrderByListBuilder<SessionReviewTable>? orderByList,
    bool orderDescending = false,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateWhere<SessionReview>(
      columnValues: columnValues(SessionReview.t.updateTable),
      where: where(SessionReview.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(SessionReview.t),
      orderByList: orderByList?.call(SessionReview.t),
      orderDescending: orderDescending,
      transaction: transaction,
    );
  }

  /// Deletes all [SessionReview]s in the list and returns the deleted rows.
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  Future<List<SessionReview>> delete(
    _i1.DatabaseSession session,
    List<SessionReview> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<SessionReview>(
      rows,
      transaction: transaction,
    );
  }

  /// Deletes a single [SessionReview].
  Future<SessionReview> deleteRow(
    _i1.DatabaseSession session,
    SessionReview row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<SessionReview>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  Future<List<SessionReview>> deleteWhere(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<SessionReviewTable> where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteWhere<SessionReview>(
      where: where(SessionReview.t),
      transaction: transaction,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<SessionReviewTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<SessionReview>(
      where: where?.call(SessionReview.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [SessionReview] rows matching the [where] expression.
  Future<void> lockRows(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<SessionReviewTable> where,
    required _i1.LockMode lockMode,
    required _i1.Transaction transaction,
    _i1.LockBehavior lockBehavior = _i1.LockBehavior.wait,
  }) async {
    return session.db.lockRows<SessionReview>(
      where: where(SessionReview.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

class SessionReviewAttachRowRepository {
  const SessionReviewAttachRowRepository._();

  /// Creates a relation between the given [SessionReview] and [SessionBooking]
  /// by setting the [SessionReview]'s foreign key `bookingId` to refer to the [SessionBooking].
  Future<void> booking(
    _i1.DatabaseSession session,
    SessionReview sessionReview,
    _i2.SessionBooking booking, {
    _i1.Transaction? transaction,
  }) async {
    if (sessionReview.id == null) {
      throw ArgumentError.notNull('sessionReview.id');
    }
    if (booking.id == null) {
      throw ArgumentError.notNull('booking.id');
    }

    var $sessionReview = sessionReview.copyWith(bookingId: booking.id);
    await session.db.updateRow<SessionReview>(
      $sessionReview,
      columns: [SessionReview.t.bookingId],
      transaction: transaction,
    );
  }
}
