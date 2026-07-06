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
import '../schedule/club_service.dart' as _i2;
import '../user_profile/user_profile.dart' as _i3;
import 'package:dartway_example_server/src/generated/protocol.dart' as _i4;

abstract class ClubSession
    implements _i1.TableRow<int?>, _i1.ProtocolSerialization {
  ClubSession._({
    this.id,
    required this.serviceId,
    this.service,
    required this.coachProfileId,
    this.coachProfile,
    required this.startsAt,
    required this.capacity,
  });

  factory ClubSession({
    int? id,
    required int serviceId,
    _i2.ClubService? service,
    required int coachProfileId,
    _i3.UserProfile? coachProfile,
    required DateTime startsAt,
    required int capacity,
  }) = _ClubSessionImpl;

  factory ClubSession.fromJson(Map<String, dynamic> jsonSerialization) {
    return ClubSession(
      id: jsonSerialization['id'] as int?,
      serviceId: jsonSerialization['serviceId'] as int,
      service: jsonSerialization['service'] == null
          ? null
          : _i4.Protocol().deserialize<_i2.ClubService>(
              jsonSerialization['service'],
            ),
      coachProfileId: jsonSerialization['coachProfileId'] as int,
      coachProfile: jsonSerialization['coachProfile'] == null
          ? null
          : _i4.Protocol().deserialize<_i3.UserProfile>(
              jsonSerialization['coachProfile'],
            ),
      startsAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['startsAt'],
      ),
      capacity: jsonSerialization['capacity'] as int,
    );
  }

  static final t = ClubSessionTable();

  static const db = ClubSessionRepository._();

  @override
  int? id;

  int serviceId;

  _i2.ClubService? service;

  int coachProfileId;

  _i3.UserProfile? coachProfile;

  DateTime startsAt;

  int capacity;

  @override
  _i1.Table<int?> get table => t;

  /// Returns a shallow copy of this [ClubSession]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  ClubSession copyWith({
    int? id,
    int? serviceId,
    _i2.ClubService? service,
    int? coachProfileId,
    _i3.UserProfile? coachProfile,
    DateTime? startsAt,
    int? capacity,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'ClubSession',
      if (id != null) 'id': id,
      'serviceId': serviceId,
      if (service != null) 'service': service?.toJson(),
      'coachProfileId': coachProfileId,
      if (coachProfile != null) 'coachProfile': coachProfile?.toJson(),
      'startsAt': startsAt.toJson(),
      'capacity': capacity,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'ClubSession',
      if (id != null) 'id': id,
      'serviceId': serviceId,
      if (service != null) 'service': service?.toJsonForProtocol(),
      'coachProfileId': coachProfileId,
      if (coachProfile != null)
        'coachProfile': coachProfile?.toJsonForProtocol(),
      'startsAt': startsAt.toJson(),
      'capacity': capacity,
    };
  }

  static ClubSessionInclude include({
    _i2.ClubServiceInclude? service,
    _i3.UserProfileInclude? coachProfile,
  }) {
    return ClubSessionInclude._(
      service: service,
      coachProfile: coachProfile,
    );
  }

  static ClubSessionIncludeList includeList({
    _i1.WhereExpressionBuilder<ClubSessionTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<ClubSessionTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<ClubSessionTable>? orderByList,
    ClubSessionInclude? include,
  }) {
    return ClubSessionIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(ClubSession.t),
      orderDescending: orderDescending,
      orderByList: orderByList?.call(ClubSession.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _ClubSessionImpl extends ClubSession {
  _ClubSessionImpl({
    int? id,
    required int serviceId,
    _i2.ClubService? service,
    required int coachProfileId,
    _i3.UserProfile? coachProfile,
    required DateTime startsAt,
    required int capacity,
  }) : super._(
         id: id,
         serviceId: serviceId,
         service: service,
         coachProfileId: coachProfileId,
         coachProfile: coachProfile,
         startsAt: startsAt,
         capacity: capacity,
       );

  /// Returns a shallow copy of this [ClubSession]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  ClubSession copyWith({
    Object? id = _Undefined,
    int? serviceId,
    Object? service = _Undefined,
    int? coachProfileId,
    Object? coachProfile = _Undefined,
    DateTime? startsAt,
    int? capacity,
  }) {
    return ClubSession(
      id: id is int? ? id : this.id,
      serviceId: serviceId ?? this.serviceId,
      service: service is _i2.ClubService? ? service : this.service?.copyWith(),
      coachProfileId: coachProfileId ?? this.coachProfileId,
      coachProfile: coachProfile is _i3.UserProfile?
          ? coachProfile
          : this.coachProfile?.copyWith(),
      startsAt: startsAt ?? this.startsAt,
      capacity: capacity ?? this.capacity,
    );
  }
}

class ClubSessionUpdateTable extends _i1.UpdateTable<ClubSessionTable> {
  ClubSessionUpdateTable(super.table);

  _i1.ColumnValue<int, int> serviceId(int value) => _i1.ColumnValue(
    table.serviceId,
    value,
  );

  _i1.ColumnValue<int, int> coachProfileId(int value) => _i1.ColumnValue(
    table.coachProfileId,
    value,
  );

  _i1.ColumnValue<DateTime, DateTime> startsAt(DateTime value) =>
      _i1.ColumnValue(
        table.startsAt,
        value,
      );

  _i1.ColumnValue<int, int> capacity(int value) => _i1.ColumnValue(
    table.capacity,
    value,
  );
}

class ClubSessionTable extends _i1.Table<int?> {
  ClubSessionTable({super.tableRelation}) : super(tableName: 'club_session') {
    updateTable = ClubSessionUpdateTable(this);
    serviceId = _i1.ColumnInt(
      'serviceId',
      this,
    );
    coachProfileId = _i1.ColumnInt(
      'coachProfileId',
      this,
    );
    startsAt = _i1.ColumnDateTime(
      'startsAt',
      this,
    );
    capacity = _i1.ColumnInt(
      'capacity',
      this,
    );
  }

  late final ClubSessionUpdateTable updateTable;

  late final _i1.ColumnInt serviceId;

  _i2.ClubServiceTable? _service;

  late final _i1.ColumnInt coachProfileId;

  _i3.UserProfileTable? _coachProfile;

  late final _i1.ColumnDateTime startsAt;

  late final _i1.ColumnInt capacity;

  _i2.ClubServiceTable get service {
    if (_service != null) return _service!;
    _service = _i1.createRelationTable(
      relationFieldName: 'service',
      field: ClubSession.t.serviceId,
      foreignField: _i2.ClubService.t.id,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _i2.ClubServiceTable(tableRelation: foreignTableRelation),
    );
    return _service!;
  }

  _i3.UserProfileTable get coachProfile {
    if (_coachProfile != null) return _coachProfile!;
    _coachProfile = _i1.createRelationTable(
      relationFieldName: 'coachProfile',
      field: ClubSession.t.coachProfileId,
      foreignField: _i3.UserProfile.t.id,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _i3.UserProfileTable(tableRelation: foreignTableRelation),
    );
    return _coachProfile!;
  }

  @override
  List<_i1.Column> get columns => [
    id,
    serviceId,
    coachProfileId,
    startsAt,
    capacity,
  ];

  @override
  _i1.Table? getRelationTable(String relationField) {
    if (relationField == 'service') {
      return service;
    }
    if (relationField == 'coachProfile') {
      return coachProfile;
    }
    return null;
  }
}

class ClubSessionInclude extends _i1.IncludeObject {
  ClubSessionInclude._({
    _i2.ClubServiceInclude? service,
    _i3.UserProfileInclude? coachProfile,
  }) {
    _service = service;
    _coachProfile = coachProfile;
  }

  _i2.ClubServiceInclude? _service;

  _i3.UserProfileInclude? _coachProfile;

  @override
  Map<String, _i1.Include?> get includes => {
    'service': _service,
    'coachProfile': _coachProfile,
  };

  @override
  _i1.Table<int?> get table => ClubSession.t;
}

class ClubSessionIncludeList extends _i1.IncludeList {
  ClubSessionIncludeList._({
    _i1.WhereExpressionBuilder<ClubSessionTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(ClubSession.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<int?> get table => ClubSession.t;
}

class ClubSessionRepository {
  const ClubSessionRepository._();

  final attachRow = const ClubSessionAttachRowRepository._();

  /// Returns a list of [ClubSession]s matching the given query parameters.
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
  Future<List<ClubSession>> find(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<ClubSessionTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<ClubSessionTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<ClubSessionTable>? orderByList,
    _i1.Transaction? transaction,
    ClubSessionInclude? include,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<ClubSession>(
      where: where?.call(ClubSession.t),
      orderBy: orderBy?.call(ClubSession.t),
      orderByList: orderByList?.call(ClubSession.t),
      orderDescending: orderDescending,
      limit: limit,
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [ClubSession] matching the given query parameters.
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
  Future<ClubSession?> findFirstRow(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<ClubSessionTable>? where,
    int? offset,
    _i1.OrderByBuilder<ClubSessionTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<ClubSessionTable>? orderByList,
    _i1.Transaction? transaction,
    ClubSessionInclude? include,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<ClubSession>(
      where: where?.call(ClubSession.t),
      orderBy: orderBy?.call(ClubSession.t),
      orderByList: orderByList?.call(ClubSession.t),
      orderDescending: orderDescending,
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [ClubSession] by its [id] or null if no such row exists.
  Future<ClubSession?> findById(
    _i1.DatabaseSession session,
    int id, {
    _i1.Transaction? transaction,
    ClubSessionInclude? include,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<ClubSession>(
      id,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [ClubSession]s in the list and returns the inserted rows.
  ///
  /// The returned [ClubSession]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  ///
  /// If [ignoreConflicts] is set to `true`, rows that conflict with existing
  /// rows are silently skipped, and only the successfully inserted rows are
  /// returned.
  Future<List<ClubSession>> insert(
    _i1.DatabaseSession session,
    List<ClubSession> rows, {
    _i1.Transaction? transaction,
    bool ignoreConflicts = false,
  }) async {
    return session.db.insert<ClubSession>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
    );
  }

  /// Inserts a single [ClubSession] and returns the inserted row.
  ///
  /// The returned [ClubSession] will have its `id` field set.
  Future<ClubSession> insertRow(
    _i1.DatabaseSession session,
    ClubSession row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<ClubSession>(
      row,
      transaction: transaction,
    );
  }

  /// Updates all [ClubSession]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  Future<List<ClubSession>> update(
    _i1.DatabaseSession session,
    List<ClubSession> rows, {
    _i1.ColumnSelections<ClubSessionTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.update<ClubSession>(
      rows,
      columns: columns?.call(ClubSession.t),
      transaction: transaction,
    );
  }

  /// Updates a single [ClubSession]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<ClubSession> updateRow(
    _i1.DatabaseSession session,
    ClubSession row, {
    _i1.ColumnSelections<ClubSessionTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<ClubSession>(
      row,
      columns: columns?.call(ClubSession.t),
      transaction: transaction,
    );
  }

  /// Updates a single [ClubSession] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<ClubSession?> updateById(
    _i1.DatabaseSession session,
    int id, {
    required _i1.ColumnValueListBuilder<ClubSessionUpdateTable> columnValues,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateById<ClubSession>(
      id,
      columnValues: columnValues(ClubSession.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [ClubSession]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  Future<List<ClubSession>> updateWhere(
    _i1.DatabaseSession session, {
    required _i1.ColumnValueListBuilder<ClubSessionUpdateTable> columnValues,
    required _i1.WhereExpressionBuilder<ClubSessionTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<ClubSessionTable>? orderBy,
    _i1.OrderByListBuilder<ClubSessionTable>? orderByList,
    bool orderDescending = false,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateWhere<ClubSession>(
      columnValues: columnValues(ClubSession.t.updateTable),
      where: where(ClubSession.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(ClubSession.t),
      orderByList: orderByList?.call(ClubSession.t),
      orderDescending: orderDescending,
      transaction: transaction,
    );
  }

  /// Deletes all [ClubSession]s in the list and returns the deleted rows.
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  Future<List<ClubSession>> delete(
    _i1.DatabaseSession session,
    List<ClubSession> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<ClubSession>(
      rows,
      transaction: transaction,
    );
  }

  /// Deletes a single [ClubSession].
  Future<ClubSession> deleteRow(
    _i1.DatabaseSession session,
    ClubSession row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<ClubSession>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  Future<List<ClubSession>> deleteWhere(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<ClubSessionTable> where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteWhere<ClubSession>(
      where: where(ClubSession.t),
      transaction: transaction,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<ClubSessionTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<ClubSession>(
      where: where?.call(ClubSession.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [ClubSession] rows matching the [where] expression.
  Future<void> lockRows(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<ClubSessionTable> where,
    required _i1.LockMode lockMode,
    required _i1.Transaction transaction,
    _i1.LockBehavior lockBehavior = _i1.LockBehavior.wait,
  }) async {
    return session.db.lockRows<ClubSession>(
      where: where(ClubSession.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

class ClubSessionAttachRowRepository {
  const ClubSessionAttachRowRepository._();

  /// Creates a relation between the given [ClubSession] and [ClubService]
  /// by setting the [ClubSession]'s foreign key `serviceId` to refer to the [ClubService].
  Future<void> service(
    _i1.DatabaseSession session,
    ClubSession clubSession,
    _i2.ClubService service, {
    _i1.Transaction? transaction,
  }) async {
    if (clubSession.id == null) {
      throw ArgumentError.notNull('clubSession.id');
    }
    if (service.id == null) {
      throw ArgumentError.notNull('service.id');
    }

    var $clubSession = clubSession.copyWith(serviceId: service.id);
    await session.db.updateRow<ClubSession>(
      $clubSession,
      columns: [ClubSession.t.serviceId],
      transaction: transaction,
    );
  }

  /// Creates a relation between the given [ClubSession] and [UserProfile]
  /// by setting the [ClubSession]'s foreign key `coachProfileId` to refer to the [UserProfile].
  Future<void> coachProfile(
    _i1.DatabaseSession session,
    ClubSession clubSession,
    _i3.UserProfile coachProfile, {
    _i1.Transaction? transaction,
  }) async {
    if (clubSession.id == null) {
      throw ArgumentError.notNull('clubSession.id');
    }
    if (coachProfile.id == null) {
      throw ArgumentError.notNull('coachProfile.id');
    }

    var $clubSession = clubSession.copyWith(coachProfileId: coachProfile.id);
    await session.db.updateRow<ClubSession>(
      $clubSession,
      columns: [ClubSession.t.coachProfileId],
      transaction: transaction,
    );
  }
}
