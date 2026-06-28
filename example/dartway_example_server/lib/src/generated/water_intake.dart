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
import 'user_profile/user_profile.dart' as _i2;
import 'package:dartway_example_server/src/generated/protocol.dart' as _i3;

abstract class WaterIntake
    implements _i1.TableRow<int?>, _i1.ProtocolSerialization {
  WaterIntake._({
    this.id,
    required this.userProfileId,
    this.userProfile,
    required this.intakeAmount,
    required this.intakeTime,
  });

  factory WaterIntake({
    int? id,
    required int userProfileId,
    _i2.UserProfile? userProfile,
    required int intakeAmount,
    required DateTime intakeTime,
  }) = _WaterIntakeImpl;

  factory WaterIntake.fromJson(Map<String, dynamic> jsonSerialization) {
    return WaterIntake(
      id: jsonSerialization['id'] as int?,
      userProfileId: jsonSerialization['userProfileId'] as int,
      userProfile: jsonSerialization['userProfile'] == null
          ? null
          : _i3.Protocol().deserialize<_i2.UserProfile>(
              jsonSerialization['userProfile'],
            ),
      intakeAmount: jsonSerialization['intakeAmount'] as int,
      intakeTime: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['intakeTime'],
      ),
    );
  }

  static final t = WaterIntakeTable();

  static const db = WaterIntakeRepository._();

  @override
  int? id;

  int userProfileId;

  _i2.UserProfile? userProfile;

  int intakeAmount;

  DateTime intakeTime;

  @override
  _i1.Table<int?> get table => t;

  /// Returns a shallow copy of this [WaterIntake]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  WaterIntake copyWith({
    int? id,
    int? userProfileId,
    _i2.UserProfile? userProfile,
    int? intakeAmount,
    DateTime? intakeTime,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'WaterIntake',
      if (id != null) 'id': id,
      'userProfileId': userProfileId,
      if (userProfile != null) 'userProfile': userProfile?.toJson(),
      'intakeAmount': intakeAmount,
      'intakeTime': intakeTime.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'WaterIntake',
      if (id != null) 'id': id,
      'userProfileId': userProfileId,
      if (userProfile != null) 'userProfile': userProfile?.toJsonForProtocol(),
      'intakeAmount': intakeAmount,
      'intakeTime': intakeTime.toJson(),
    };
  }

  static WaterIntakeInclude include({_i2.UserProfileInclude? userProfile}) {
    return WaterIntakeInclude._(userProfile: userProfile);
  }

  static WaterIntakeIncludeList includeList({
    _i1.WhereExpressionBuilder<WaterIntakeTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<WaterIntakeTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<WaterIntakeTable>? orderByList,
    WaterIntakeInclude? include,
  }) {
    return WaterIntakeIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(WaterIntake.t),
      orderDescending: orderDescending,
      orderByList: orderByList?.call(WaterIntake.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _WaterIntakeImpl extends WaterIntake {
  _WaterIntakeImpl({
    int? id,
    required int userProfileId,
    _i2.UserProfile? userProfile,
    required int intakeAmount,
    required DateTime intakeTime,
  }) : super._(
         id: id,
         userProfileId: userProfileId,
         userProfile: userProfile,
         intakeAmount: intakeAmount,
         intakeTime: intakeTime,
       );

  /// Returns a shallow copy of this [WaterIntake]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  WaterIntake copyWith({
    Object? id = _Undefined,
    int? userProfileId,
    Object? userProfile = _Undefined,
    int? intakeAmount,
    DateTime? intakeTime,
  }) {
    return WaterIntake(
      id: id is int? ? id : this.id,
      userProfileId: userProfileId ?? this.userProfileId,
      userProfile: userProfile is _i2.UserProfile?
          ? userProfile
          : this.userProfile?.copyWith(),
      intakeAmount: intakeAmount ?? this.intakeAmount,
      intakeTime: intakeTime ?? this.intakeTime,
    );
  }
}

class WaterIntakeUpdateTable extends _i1.UpdateTable<WaterIntakeTable> {
  WaterIntakeUpdateTable(super.table);

  _i1.ColumnValue<int, int> userProfileId(int value) => _i1.ColumnValue(
    table.userProfileId,
    value,
  );

  _i1.ColumnValue<int, int> intakeAmount(int value) => _i1.ColumnValue(
    table.intakeAmount,
    value,
  );

  _i1.ColumnValue<DateTime, DateTime> intakeTime(DateTime value) =>
      _i1.ColumnValue(
        table.intakeTime,
        value,
      );
}

class WaterIntakeTable extends _i1.Table<int?> {
  WaterIntakeTable({super.tableRelation}) : super(tableName: 'water_intake') {
    updateTable = WaterIntakeUpdateTable(this);
    userProfileId = _i1.ColumnInt(
      'userProfileId',
      this,
    );
    intakeAmount = _i1.ColumnInt(
      'intakeAmount',
      this,
    );
    intakeTime = _i1.ColumnDateTime(
      'intakeTime',
      this,
    );
  }

  late final WaterIntakeUpdateTable updateTable;

  late final _i1.ColumnInt userProfileId;

  _i2.UserProfileTable? _userProfile;

  late final _i1.ColumnInt intakeAmount;

  late final _i1.ColumnDateTime intakeTime;

  _i2.UserProfileTable get userProfile {
    if (_userProfile != null) return _userProfile!;
    _userProfile = _i1.createRelationTable(
      relationFieldName: 'userProfile',
      field: WaterIntake.t.userProfileId,
      foreignField: _i2.UserProfile.t.id,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _i2.UserProfileTable(tableRelation: foreignTableRelation),
    );
    return _userProfile!;
  }

  @override
  List<_i1.Column> get columns => [
    id,
    userProfileId,
    intakeAmount,
    intakeTime,
  ];

  @override
  _i1.Table? getRelationTable(String relationField) {
    if (relationField == 'userProfile') {
      return userProfile;
    }
    return null;
  }
}

class WaterIntakeInclude extends _i1.IncludeObject {
  WaterIntakeInclude._({_i2.UserProfileInclude? userProfile}) {
    _userProfile = userProfile;
  }

  _i2.UserProfileInclude? _userProfile;

  @override
  Map<String, _i1.Include?> get includes => {'userProfile': _userProfile};

  @override
  _i1.Table<int?> get table => WaterIntake.t;
}

class WaterIntakeIncludeList extends _i1.IncludeList {
  WaterIntakeIncludeList._({
    _i1.WhereExpressionBuilder<WaterIntakeTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(WaterIntake.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<int?> get table => WaterIntake.t;
}

class WaterIntakeRepository {
  const WaterIntakeRepository._();

  final attachRow = const WaterIntakeAttachRowRepository._();

  /// Returns a list of [WaterIntake]s matching the given query parameters.
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
  Future<List<WaterIntake>> find(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<WaterIntakeTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<WaterIntakeTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<WaterIntakeTable>? orderByList,
    _i1.Transaction? transaction,
    WaterIntakeInclude? include,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<WaterIntake>(
      where: where?.call(WaterIntake.t),
      orderBy: orderBy?.call(WaterIntake.t),
      orderByList: orderByList?.call(WaterIntake.t),
      orderDescending: orderDescending,
      limit: limit,
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [WaterIntake] matching the given query parameters.
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
  Future<WaterIntake?> findFirstRow(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<WaterIntakeTable>? where,
    int? offset,
    _i1.OrderByBuilder<WaterIntakeTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<WaterIntakeTable>? orderByList,
    _i1.Transaction? transaction,
    WaterIntakeInclude? include,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<WaterIntake>(
      where: where?.call(WaterIntake.t),
      orderBy: orderBy?.call(WaterIntake.t),
      orderByList: orderByList?.call(WaterIntake.t),
      orderDescending: orderDescending,
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [WaterIntake] by its [id] or null if no such row exists.
  Future<WaterIntake?> findById(
    _i1.DatabaseSession session,
    int id, {
    _i1.Transaction? transaction,
    WaterIntakeInclude? include,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<WaterIntake>(
      id,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [WaterIntake]s in the list and returns the inserted rows.
  ///
  /// The returned [WaterIntake]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  ///
  /// If [ignoreConflicts] is set to `true`, rows that conflict with existing
  /// rows are silently skipped, and only the successfully inserted rows are
  /// returned.
  Future<List<WaterIntake>> insert(
    _i1.DatabaseSession session,
    List<WaterIntake> rows, {
    _i1.Transaction? transaction,
    bool ignoreConflicts = false,
  }) async {
    return session.db.insert<WaterIntake>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
    );
  }

  /// Inserts a single [WaterIntake] and returns the inserted row.
  ///
  /// The returned [WaterIntake] will have its `id` field set.
  Future<WaterIntake> insertRow(
    _i1.DatabaseSession session,
    WaterIntake row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<WaterIntake>(
      row,
      transaction: transaction,
    );
  }

  /// Updates all [WaterIntake]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  Future<List<WaterIntake>> update(
    _i1.DatabaseSession session,
    List<WaterIntake> rows, {
    _i1.ColumnSelections<WaterIntakeTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.update<WaterIntake>(
      rows,
      columns: columns?.call(WaterIntake.t),
      transaction: transaction,
    );
  }

  /// Updates a single [WaterIntake]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<WaterIntake> updateRow(
    _i1.DatabaseSession session,
    WaterIntake row, {
    _i1.ColumnSelections<WaterIntakeTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<WaterIntake>(
      row,
      columns: columns?.call(WaterIntake.t),
      transaction: transaction,
    );
  }

  /// Updates a single [WaterIntake] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<WaterIntake?> updateById(
    _i1.DatabaseSession session,
    int id, {
    required _i1.ColumnValueListBuilder<WaterIntakeUpdateTable> columnValues,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateById<WaterIntake>(
      id,
      columnValues: columnValues(WaterIntake.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [WaterIntake]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  Future<List<WaterIntake>> updateWhere(
    _i1.DatabaseSession session, {
    required _i1.ColumnValueListBuilder<WaterIntakeUpdateTable> columnValues,
    required _i1.WhereExpressionBuilder<WaterIntakeTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<WaterIntakeTable>? orderBy,
    _i1.OrderByListBuilder<WaterIntakeTable>? orderByList,
    bool orderDescending = false,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateWhere<WaterIntake>(
      columnValues: columnValues(WaterIntake.t.updateTable),
      where: where(WaterIntake.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(WaterIntake.t),
      orderByList: orderByList?.call(WaterIntake.t),
      orderDescending: orderDescending,
      transaction: transaction,
    );
  }

  /// Deletes all [WaterIntake]s in the list and returns the deleted rows.
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  Future<List<WaterIntake>> delete(
    _i1.DatabaseSession session,
    List<WaterIntake> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<WaterIntake>(
      rows,
      transaction: transaction,
    );
  }

  /// Deletes a single [WaterIntake].
  Future<WaterIntake> deleteRow(
    _i1.DatabaseSession session,
    WaterIntake row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<WaterIntake>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  Future<List<WaterIntake>> deleteWhere(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<WaterIntakeTable> where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteWhere<WaterIntake>(
      where: where(WaterIntake.t),
      transaction: transaction,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<WaterIntakeTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<WaterIntake>(
      where: where?.call(WaterIntake.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [WaterIntake] rows matching the [where] expression.
  Future<void> lockRows(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<WaterIntakeTable> where,
    required _i1.LockMode lockMode,
    required _i1.Transaction transaction,
    _i1.LockBehavior lockBehavior = _i1.LockBehavior.wait,
  }) async {
    return session.db.lockRows<WaterIntake>(
      where: where(WaterIntake.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

class WaterIntakeAttachRowRepository {
  const WaterIntakeAttachRowRepository._();

  /// Creates a relation between the given [WaterIntake] and [UserProfile]
  /// by setting the [WaterIntake]'s foreign key `userProfileId` to refer to the [UserProfile].
  Future<void> userProfile(
    _i1.DatabaseSession session,
    WaterIntake waterIntake,
    _i2.UserProfile userProfile, {
    _i1.Transaction? transaction,
  }) async {
    if (waterIntake.id == null) {
      throw ArgumentError.notNull('waterIntake.id');
    }
    if (userProfile.id == null) {
      throw ArgumentError.notNull('userProfile.id');
    }

    var $waterIntake = waterIntake.copyWith(userProfileId: userProfile.id);
    await session.db.updateRow<WaterIntake>(
      $waterIntake,
      columns: [WaterIntake.t.userProfileId],
      transaction: transaction,
    );
  }
}
