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
import '../schedule/club_session.dart' as _i2;
import '../user_profile/user_profile.dart' as _i3;
import '../booking/enums/booking_status.dart' as _i4;
import 'package:dartway_example_server/src/generated/protocol.dart' as _i5;

abstract class SessionBooking
    implements _i1.TableRow<int?>, _i1.ProtocolSerialization {
  SessionBooking._({
    this.id,
    required this.clubSessionId,
    this.clubSession,
    required this.clientProfileId,
    this.clientProfile,
    required this.status,
    required this.createdAt,
  });

  factory SessionBooking({
    int? id,
    required int clubSessionId,
    _i2.ClubSession? clubSession,
    required int clientProfileId,
    _i3.UserProfile? clientProfile,
    required _i4.BookingStatus status,
    required DateTime createdAt,
  }) = _SessionBookingImpl;

  factory SessionBooking.fromJson(Map<String, dynamic> jsonSerialization) {
    return SessionBooking(
      id: jsonSerialization['id'] as int?,
      clubSessionId: jsonSerialization['clubSessionId'] as int,
      clubSession: jsonSerialization['clubSession'] == null
          ? null
          : _i5.Protocol().deserialize<_i2.ClubSession>(
              jsonSerialization['clubSession'],
            ),
      clientProfileId: jsonSerialization['clientProfileId'] as int,
      clientProfile: jsonSerialization['clientProfile'] == null
          ? null
          : _i5.Protocol().deserialize<_i3.UserProfile>(
              jsonSerialization['clientProfile'],
            ),
      status: _i4.BookingStatus.fromJson(
        (jsonSerialization['status'] as String),
      ),
      createdAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
    );
  }

  static final t = SessionBookingTable();

  static const db = SessionBookingRepository._();

  @override
  int? id;

  int clubSessionId;

  _i2.ClubSession? clubSession;

  int clientProfileId;

  _i3.UserProfile? clientProfile;

  _i4.BookingStatus status;

  DateTime createdAt;

  @override
  _i1.Table<int?> get table => t;

  /// Returns a shallow copy of this [SessionBooking]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  SessionBooking copyWith({
    int? id,
    int? clubSessionId,
    _i2.ClubSession? clubSession,
    int? clientProfileId,
    _i3.UserProfile? clientProfile,
    _i4.BookingStatus? status,
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'SessionBooking',
      if (id != null) 'id': id,
      'clubSessionId': clubSessionId,
      if (clubSession != null) 'clubSession': clubSession?.toJson(),
      'clientProfileId': clientProfileId,
      if (clientProfile != null) 'clientProfile': clientProfile?.toJson(),
      'status': status.toJson(),
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'SessionBooking',
      if (id != null) 'id': id,
      'clubSessionId': clubSessionId,
      if (clubSession != null) 'clubSession': clubSession?.toJsonForProtocol(),
      'clientProfileId': clientProfileId,
      if (clientProfile != null)
        'clientProfile': clientProfile?.toJsonForProtocol(),
      'status': status.toJson(),
      'createdAt': createdAt.toJson(),
    };
  }

  static SessionBookingInclude include({
    _i2.ClubSessionInclude? clubSession,
    _i3.UserProfileInclude? clientProfile,
  }) {
    return SessionBookingInclude._(
      clubSession: clubSession,
      clientProfile: clientProfile,
    );
  }

  static SessionBookingIncludeList includeList({
    _i1.WhereExpressionBuilder<SessionBookingTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<SessionBookingTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<SessionBookingTable>? orderByList,
    SessionBookingInclude? include,
  }) {
    return SessionBookingIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(SessionBooking.t),
      orderDescending: orderDescending,
      orderByList: orderByList?.call(SessionBooking.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _SessionBookingImpl extends SessionBooking {
  _SessionBookingImpl({
    int? id,
    required int clubSessionId,
    _i2.ClubSession? clubSession,
    required int clientProfileId,
    _i3.UserProfile? clientProfile,
    required _i4.BookingStatus status,
    required DateTime createdAt,
  }) : super._(
         id: id,
         clubSessionId: clubSessionId,
         clubSession: clubSession,
         clientProfileId: clientProfileId,
         clientProfile: clientProfile,
         status: status,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [SessionBooking]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  SessionBooking copyWith({
    Object? id = _Undefined,
    int? clubSessionId,
    Object? clubSession = _Undefined,
    int? clientProfileId,
    Object? clientProfile = _Undefined,
    _i4.BookingStatus? status,
    DateTime? createdAt,
  }) {
    return SessionBooking(
      id: id is int? ? id : this.id,
      clubSessionId: clubSessionId ?? this.clubSessionId,
      clubSession: clubSession is _i2.ClubSession?
          ? clubSession
          : this.clubSession?.copyWith(),
      clientProfileId: clientProfileId ?? this.clientProfileId,
      clientProfile: clientProfile is _i3.UserProfile?
          ? clientProfile
          : this.clientProfile?.copyWith(),
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class SessionBookingUpdateTable extends _i1.UpdateTable<SessionBookingTable> {
  SessionBookingUpdateTable(super.table);

  _i1.ColumnValue<int, int> clubSessionId(int value) => _i1.ColumnValue(
    table.clubSessionId,
    value,
  );

  _i1.ColumnValue<int, int> clientProfileId(int value) => _i1.ColumnValue(
    table.clientProfileId,
    value,
  );

  _i1.ColumnValue<_i4.BookingStatus, _i4.BookingStatus> status(
    _i4.BookingStatus value,
  ) => _i1.ColumnValue(
    table.status,
    value,
  );

  _i1.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _i1.ColumnValue(
        table.createdAt,
        value,
      );
}

class SessionBookingTable extends _i1.Table<int?> {
  SessionBookingTable({super.tableRelation})
    : super(tableName: 'session_booking') {
    updateTable = SessionBookingUpdateTable(this);
    clubSessionId = _i1.ColumnInt(
      'clubSessionId',
      this,
    );
    clientProfileId = _i1.ColumnInt(
      'clientProfileId',
      this,
    );
    status = _i1.ColumnEnum(
      'status',
      this,
      _i1.EnumSerialization.byName,
    );
    createdAt = _i1.ColumnDateTime(
      'createdAt',
      this,
    );
  }

  late final SessionBookingUpdateTable updateTable;

  late final _i1.ColumnInt clubSessionId;

  _i2.ClubSessionTable? _clubSession;

  late final _i1.ColumnInt clientProfileId;

  _i3.UserProfileTable? _clientProfile;

  late final _i1.ColumnEnum<_i4.BookingStatus> status;

  late final _i1.ColumnDateTime createdAt;

  _i2.ClubSessionTable get clubSession {
    if (_clubSession != null) return _clubSession!;
    _clubSession = _i1.createRelationTable(
      relationFieldName: 'clubSession',
      field: SessionBooking.t.clubSessionId,
      foreignField: _i2.ClubSession.t.id,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _i2.ClubSessionTable(tableRelation: foreignTableRelation),
    );
    return _clubSession!;
  }

  _i3.UserProfileTable get clientProfile {
    if (_clientProfile != null) return _clientProfile!;
    _clientProfile = _i1.createRelationTable(
      relationFieldName: 'clientProfile',
      field: SessionBooking.t.clientProfileId,
      foreignField: _i3.UserProfile.t.id,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _i3.UserProfileTable(tableRelation: foreignTableRelation),
    );
    return _clientProfile!;
  }

  @override
  List<_i1.Column> get columns => [
    id,
    clubSessionId,
    clientProfileId,
    status,
    createdAt,
  ];

  @override
  _i1.Table? getRelationTable(String relationField) {
    if (relationField == 'clubSession') {
      return clubSession;
    }
    if (relationField == 'clientProfile') {
      return clientProfile;
    }
    return null;
  }
}

class SessionBookingInclude extends _i1.IncludeObject {
  SessionBookingInclude._({
    _i2.ClubSessionInclude? clubSession,
    _i3.UserProfileInclude? clientProfile,
  }) {
    _clubSession = clubSession;
    _clientProfile = clientProfile;
  }

  _i2.ClubSessionInclude? _clubSession;

  _i3.UserProfileInclude? _clientProfile;

  @override
  Map<String, _i1.Include?> get includes => {
    'clubSession': _clubSession,
    'clientProfile': _clientProfile,
  };

  @override
  _i1.Table<int?> get table => SessionBooking.t;
}

class SessionBookingIncludeList extends _i1.IncludeList {
  SessionBookingIncludeList._({
    _i1.WhereExpressionBuilder<SessionBookingTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(SessionBooking.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<int?> get table => SessionBooking.t;
}

class SessionBookingRepository {
  const SessionBookingRepository._();

  final attachRow = const SessionBookingAttachRowRepository._();

  /// Returns a list of [SessionBooking]s matching the given query parameters.
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
  Future<List<SessionBooking>> find(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<SessionBookingTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<SessionBookingTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<SessionBookingTable>? orderByList,
    _i1.Transaction? transaction,
    SessionBookingInclude? include,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<SessionBooking>(
      where: where?.call(SessionBooking.t),
      orderBy: orderBy?.call(SessionBooking.t),
      orderByList: orderByList?.call(SessionBooking.t),
      orderDescending: orderDescending,
      limit: limit,
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [SessionBooking] matching the given query parameters.
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
  Future<SessionBooking?> findFirstRow(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<SessionBookingTable>? where,
    int? offset,
    _i1.OrderByBuilder<SessionBookingTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<SessionBookingTable>? orderByList,
    _i1.Transaction? transaction,
    SessionBookingInclude? include,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<SessionBooking>(
      where: where?.call(SessionBooking.t),
      orderBy: orderBy?.call(SessionBooking.t),
      orderByList: orderByList?.call(SessionBooking.t),
      orderDescending: orderDescending,
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [SessionBooking] by its [id] or null if no such row exists.
  Future<SessionBooking?> findById(
    _i1.DatabaseSession session,
    int id, {
    _i1.Transaction? transaction,
    SessionBookingInclude? include,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<SessionBooking>(
      id,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [SessionBooking]s in the list and returns the inserted rows.
  ///
  /// The returned [SessionBooking]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  ///
  /// If [ignoreConflicts] is set to `true`, rows that conflict with existing
  /// rows are silently skipped, and only the successfully inserted rows are
  /// returned.
  Future<List<SessionBooking>> insert(
    _i1.DatabaseSession session,
    List<SessionBooking> rows, {
    _i1.Transaction? transaction,
    bool ignoreConflicts = false,
  }) async {
    return session.db.insert<SessionBooking>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
    );
  }

  /// Inserts a single [SessionBooking] and returns the inserted row.
  ///
  /// The returned [SessionBooking] will have its `id` field set.
  Future<SessionBooking> insertRow(
    _i1.DatabaseSession session,
    SessionBooking row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<SessionBooking>(
      row,
      transaction: transaction,
    );
  }

  /// Updates all [SessionBooking]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  Future<List<SessionBooking>> update(
    _i1.DatabaseSession session,
    List<SessionBooking> rows, {
    _i1.ColumnSelections<SessionBookingTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.update<SessionBooking>(
      rows,
      columns: columns?.call(SessionBooking.t),
      transaction: transaction,
    );
  }

  /// Updates a single [SessionBooking]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<SessionBooking> updateRow(
    _i1.DatabaseSession session,
    SessionBooking row, {
    _i1.ColumnSelections<SessionBookingTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<SessionBooking>(
      row,
      columns: columns?.call(SessionBooking.t),
      transaction: transaction,
    );
  }

  /// Updates a single [SessionBooking] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<SessionBooking?> updateById(
    _i1.DatabaseSession session,
    int id, {
    required _i1.ColumnValueListBuilder<SessionBookingUpdateTable> columnValues,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateById<SessionBooking>(
      id,
      columnValues: columnValues(SessionBooking.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [SessionBooking]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  Future<List<SessionBooking>> updateWhere(
    _i1.DatabaseSession session, {
    required _i1.ColumnValueListBuilder<SessionBookingUpdateTable> columnValues,
    required _i1.WhereExpressionBuilder<SessionBookingTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<SessionBookingTable>? orderBy,
    _i1.OrderByListBuilder<SessionBookingTable>? orderByList,
    bool orderDescending = false,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateWhere<SessionBooking>(
      columnValues: columnValues(SessionBooking.t.updateTable),
      where: where(SessionBooking.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(SessionBooking.t),
      orderByList: orderByList?.call(SessionBooking.t),
      orderDescending: orderDescending,
      transaction: transaction,
    );
  }

  /// Deletes all [SessionBooking]s in the list and returns the deleted rows.
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  Future<List<SessionBooking>> delete(
    _i1.DatabaseSession session,
    List<SessionBooking> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<SessionBooking>(
      rows,
      transaction: transaction,
    );
  }

  /// Deletes a single [SessionBooking].
  Future<SessionBooking> deleteRow(
    _i1.DatabaseSession session,
    SessionBooking row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<SessionBooking>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  Future<List<SessionBooking>> deleteWhere(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<SessionBookingTable> where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteWhere<SessionBooking>(
      where: where(SessionBooking.t),
      transaction: transaction,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<SessionBookingTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<SessionBooking>(
      where: where?.call(SessionBooking.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [SessionBooking] rows matching the [where] expression.
  Future<void> lockRows(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<SessionBookingTable> where,
    required _i1.LockMode lockMode,
    required _i1.Transaction transaction,
    _i1.LockBehavior lockBehavior = _i1.LockBehavior.wait,
  }) async {
    return session.db.lockRows<SessionBooking>(
      where: where(SessionBooking.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

class SessionBookingAttachRowRepository {
  const SessionBookingAttachRowRepository._();

  /// Creates a relation between the given [SessionBooking] and [ClubSession]
  /// by setting the [SessionBooking]'s foreign key `clubSessionId` to refer to the [ClubSession].
  Future<void> clubSession(
    _i1.DatabaseSession session,
    SessionBooking sessionBooking,
    _i2.ClubSession clubSession, {
    _i1.Transaction? transaction,
  }) async {
    if (sessionBooking.id == null) {
      throw ArgumentError.notNull('sessionBooking.id');
    }
    if (clubSession.id == null) {
      throw ArgumentError.notNull('clubSession.id');
    }

    var $sessionBooking = sessionBooking.copyWith(
      clubSessionId: clubSession.id,
    );
    await session.db.updateRow<SessionBooking>(
      $sessionBooking,
      columns: [SessionBooking.t.clubSessionId],
      transaction: transaction,
    );
  }

  /// Creates a relation between the given [SessionBooking] and [UserProfile]
  /// by setting the [SessionBooking]'s foreign key `clientProfileId` to refer to the [UserProfile].
  Future<void> clientProfile(
    _i1.DatabaseSession session,
    SessionBooking sessionBooking,
    _i3.UserProfile clientProfile, {
    _i1.Transaction? transaction,
  }) async {
    if (sessionBooking.id == null) {
      throw ArgumentError.notNull('sessionBooking.id');
    }
    if (clientProfile.id == null) {
      throw ArgumentError.notNull('clientProfile.id');
    }

    var $sessionBooking = sessionBooking.copyWith(
      clientProfileId: clientProfile.id,
    );
    await session.db.updateRow<SessionBooking>(
      $sessionBooking,
      columns: [SessionBooking.t.clientProfileId],
      transaction: transaction,
    );
  }
}
