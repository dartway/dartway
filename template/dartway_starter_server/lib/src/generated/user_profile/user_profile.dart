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
import '../user_profile/enums/user_role.dart' as _i2;
import '../user_profile/user_gender.dart' as _i3;

abstract class UserProfile
    implements _i1.TableRow<int?>, _i1.ProtocolSerialization {
  UserProfile._({
    this.id,
    required this.userIdentifier,
    required this.phone,
    required this.agreedForMarketingCommunications,
    required this.conditionsAcceptedAt,
    required this.firstName,
    this.lastName,
    this.imageUrl,
    this.gender,
    _i2.UserRole? role,
    this.testVerificationCode,
  }) : role = role ?? _i2.UserRole.user;

  factory UserProfile({
    int? id,
    required String userIdentifier,
    required String phone,
    required bool agreedForMarketingCommunications,
    required DateTime conditionsAcceptedAt,
    required String firstName,
    String? lastName,
    String? imageUrl,
    _i3.UserGender? gender,
    _i2.UserRole? role,
    String? testVerificationCode,
  }) = _UserProfileImpl;

  factory UserProfile.fromJson(Map<String, dynamic> jsonSerialization) {
    return UserProfile(
      id: jsonSerialization['id'] as int?,
      userIdentifier: jsonSerialization['userIdentifier'] as String,
      phone: jsonSerialization['phone'] as String,
      agreedForMarketingCommunications: _i1.BoolJsonExtension.fromJson(
        jsonSerialization['agreedForMarketingCommunications'],
      ),
      conditionsAcceptedAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['conditionsAcceptedAt'],
      ),
      firstName: jsonSerialization['firstName'] as String,
      lastName: jsonSerialization['lastName'] as String?,
      imageUrl: jsonSerialization['imageUrl'] as String?,
      gender: jsonSerialization['gender'] == null
          ? null
          : _i3.UserGender.fromJson((jsonSerialization['gender'] as String)),
      role: jsonSerialization['role'] == null
          ? null
          : _i2.UserRole.fromJson((jsonSerialization['role'] as String)),
      testVerificationCode:
          jsonSerialization['testVerificationCode'] as String?,
    );
  }

  static final t = UserProfileTable();

  static const db = UserProfileRepository._();

  @override
  int? id;

  String userIdentifier;

  String phone;

  bool agreedForMarketingCommunications;

  DateTime conditionsAcceptedAt;

  String firstName;

  String? lastName;

  String? imageUrl;

  _i3.UserGender? gender;

  _i2.UserRole role;

  String? testVerificationCode;

  @override
  _i1.Table<int?> get table => t;

  /// Returns a shallow copy of this [UserProfile]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  UserProfile copyWith({
    int? id,
    String? userIdentifier,
    String? phone,
    bool? agreedForMarketingCommunications,
    DateTime? conditionsAcceptedAt,
    String? firstName,
    String? lastName,
    String? imageUrl,
    _i3.UserGender? gender,
    _i2.UserRole? role,
    String? testVerificationCode,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'UserProfile',
      if (id != null) 'id': id,
      'userIdentifier': userIdentifier,
      'phone': phone,
      'agreedForMarketingCommunications': agreedForMarketingCommunications,
      'conditionsAcceptedAt': conditionsAcceptedAt.toJson(),
      'firstName': firstName,
      if (lastName != null) 'lastName': lastName,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (gender != null) 'gender': gender?.toJson(),
      'role': role.toJson(),
      if (testVerificationCode != null)
        'testVerificationCode': testVerificationCode,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'UserProfile',
      if (id != null) 'id': id,
      'userIdentifier': userIdentifier,
      'phone': phone,
      'agreedForMarketingCommunications': agreedForMarketingCommunications,
      'conditionsAcceptedAt': conditionsAcceptedAt.toJson(),
      'firstName': firstName,
      if (lastName != null) 'lastName': lastName,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (gender != null) 'gender': gender?.toJson(),
      'role': role.toJson(),
    };
  }

  static UserProfileInclude include() {
    return UserProfileInclude._();
  }

  static UserProfileIncludeList includeList({
    _i1.WhereExpressionBuilder<UserProfileTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<UserProfileTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<UserProfileTable>? orderByList,
    UserProfileInclude? include,
  }) {
    return UserProfileIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(UserProfile.t),
      orderDescending: orderDescending,
      orderByList: orderByList?.call(UserProfile.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _UserProfileImpl extends UserProfile {
  _UserProfileImpl({
    int? id,
    required String userIdentifier,
    required String phone,
    required bool agreedForMarketingCommunications,
    required DateTime conditionsAcceptedAt,
    required String firstName,
    String? lastName,
    String? imageUrl,
    _i3.UserGender? gender,
    _i2.UserRole? role,
    String? testVerificationCode,
  }) : super._(
         id: id,
         userIdentifier: userIdentifier,
         phone: phone,
         agreedForMarketingCommunications: agreedForMarketingCommunications,
         conditionsAcceptedAt: conditionsAcceptedAt,
         firstName: firstName,
         lastName: lastName,
         imageUrl: imageUrl,
         gender: gender,
         role: role,
         testVerificationCode: testVerificationCode,
       );

  /// Returns a shallow copy of this [UserProfile]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  UserProfile copyWith({
    Object? id = _Undefined,
    String? userIdentifier,
    String? phone,
    bool? agreedForMarketingCommunications,
    DateTime? conditionsAcceptedAt,
    String? firstName,
    Object? lastName = _Undefined,
    Object? imageUrl = _Undefined,
    Object? gender = _Undefined,
    _i2.UserRole? role,
    Object? testVerificationCode = _Undefined,
  }) {
    return UserProfile(
      id: id is int? ? id : this.id,
      userIdentifier: userIdentifier ?? this.userIdentifier,
      phone: phone ?? this.phone,
      agreedForMarketingCommunications:
          agreedForMarketingCommunications ??
          this.agreedForMarketingCommunications,
      conditionsAcceptedAt: conditionsAcceptedAt ?? this.conditionsAcceptedAt,
      firstName: firstName ?? this.firstName,
      lastName: lastName is String? ? lastName : this.lastName,
      imageUrl: imageUrl is String? ? imageUrl : this.imageUrl,
      gender: gender is _i3.UserGender? ? gender : this.gender,
      role: role ?? this.role,
      testVerificationCode: testVerificationCode is String?
          ? testVerificationCode
          : this.testVerificationCode,
    );
  }
}

class UserProfileUpdateTable extends _i1.UpdateTable<UserProfileTable> {
  UserProfileUpdateTable(super.table);

  _i1.ColumnValue<String, String> userIdentifier(String value) =>
      _i1.ColumnValue(
        table.userIdentifier,
        value,
      );

  _i1.ColumnValue<String, String> phone(String value) => _i1.ColumnValue(
    table.phone,
    value,
  );

  _i1.ColumnValue<bool, bool> agreedForMarketingCommunications(bool value) =>
      _i1.ColumnValue(
        table.agreedForMarketingCommunications,
        value,
      );

  _i1.ColumnValue<DateTime, DateTime> conditionsAcceptedAt(DateTime value) =>
      _i1.ColumnValue(
        table.conditionsAcceptedAt,
        value,
      );

  _i1.ColumnValue<String, String> firstName(String value) => _i1.ColumnValue(
    table.firstName,
    value,
  );

  _i1.ColumnValue<String, String> lastName(String? value) => _i1.ColumnValue(
    table.lastName,
    value,
  );

  _i1.ColumnValue<String, String> imageUrl(String? value) => _i1.ColumnValue(
    table.imageUrl,
    value,
  );

  _i1.ColumnValue<_i3.UserGender, _i3.UserGender> gender(
    _i3.UserGender? value,
  ) => _i1.ColumnValue(
    table.gender,
    value,
  );

  _i1.ColumnValue<_i2.UserRole, _i2.UserRole> role(_i2.UserRole value) =>
      _i1.ColumnValue(
        table.role,
        value,
      );

  _i1.ColumnValue<String, String> testVerificationCode(String? value) =>
      _i1.ColumnValue(
        table.testVerificationCode,
        value,
      );
}

class UserProfileTable extends _i1.Table<int?> {
  UserProfileTable({super.tableRelation}) : super(tableName: 'user_profile') {
    updateTable = UserProfileUpdateTable(this);
    userIdentifier = _i1.ColumnString(
      'userIdentifier',
      this,
    );
    phone = _i1.ColumnString(
      'phone',
      this,
    );
    agreedForMarketingCommunications = _i1.ColumnBool(
      'agreedForMarketingCommunications',
      this,
    );
    conditionsAcceptedAt = _i1.ColumnDateTime(
      'conditionsAcceptedAt',
      this,
    );
    firstName = _i1.ColumnString(
      'firstName',
      this,
    );
    lastName = _i1.ColumnString(
      'lastName',
      this,
    );
    imageUrl = _i1.ColumnString(
      'imageUrl',
      this,
    );
    gender = _i1.ColumnEnum(
      'gender',
      this,
      _i1.EnumSerialization.byName,
    );
    role = _i1.ColumnEnum(
      'role',
      this,
      _i1.EnumSerialization.byName,
      hasDefault: true,
    );
    testVerificationCode = _i1.ColumnString(
      'testVerificationCode',
      this,
    );
  }

  late final UserProfileUpdateTable updateTable;

  late final _i1.ColumnString userIdentifier;

  late final _i1.ColumnString phone;

  late final _i1.ColumnBool agreedForMarketingCommunications;

  late final _i1.ColumnDateTime conditionsAcceptedAt;

  late final _i1.ColumnString firstName;

  late final _i1.ColumnString lastName;

  late final _i1.ColumnString imageUrl;

  late final _i1.ColumnEnum<_i3.UserGender> gender;

  late final _i1.ColumnEnum<_i2.UserRole> role;

  late final _i1.ColumnString testVerificationCode;

  @override
  List<_i1.Column> get columns => [
    id,
    userIdentifier,
    phone,
    agreedForMarketingCommunications,
    conditionsAcceptedAt,
    firstName,
    lastName,
    imageUrl,
    gender,
    role,
    testVerificationCode,
  ];
}

class UserProfileInclude extends _i1.IncludeObject {
  UserProfileInclude._();

  @override
  Map<String, _i1.Include?> get includes => {};

  @override
  _i1.Table<int?> get table => UserProfile.t;
}

class UserProfileIncludeList extends _i1.IncludeList {
  UserProfileIncludeList._({
    _i1.WhereExpressionBuilder<UserProfileTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(UserProfile.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<int?> get table => UserProfile.t;
}

class UserProfileRepository {
  const UserProfileRepository._();

  /// Returns a list of [UserProfile]s matching the given query parameters.
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
  Future<List<UserProfile>> find(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<UserProfileTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<UserProfileTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<UserProfileTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<UserProfile>(
      where: where?.call(UserProfile.t),
      orderBy: orderBy?.call(UserProfile.t),
      orderByList: orderByList?.call(UserProfile.t),
      orderDescending: orderDescending,
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [UserProfile] matching the given query parameters.
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
  Future<UserProfile?> findFirstRow(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<UserProfileTable>? where,
    int? offset,
    _i1.OrderByBuilder<UserProfileTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<UserProfileTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<UserProfile>(
      where: where?.call(UserProfile.t),
      orderBy: orderBy?.call(UserProfile.t),
      orderByList: orderByList?.call(UserProfile.t),
      orderDescending: orderDescending,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [UserProfile] by its [id] or null if no such row exists.
  Future<UserProfile?> findById(
    _i1.DatabaseSession session,
    int id, {
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<UserProfile>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [UserProfile]s in the list and returns the inserted rows.
  ///
  /// The returned [UserProfile]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  ///
  /// If [ignoreConflicts] is set to `true`, rows that conflict with existing
  /// rows are silently skipped, and only the successfully inserted rows are
  /// returned.
  Future<List<UserProfile>> insert(
    _i1.DatabaseSession session,
    List<UserProfile> rows, {
    _i1.Transaction? transaction,
    bool ignoreConflicts = false,
  }) async {
    return session.db.insert<UserProfile>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
    );
  }

  /// Inserts a single [UserProfile] and returns the inserted row.
  ///
  /// The returned [UserProfile] will have its `id` field set.
  Future<UserProfile> insertRow(
    _i1.DatabaseSession session,
    UserProfile row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<UserProfile>(
      row,
      transaction: transaction,
    );
  }

  /// Updates all [UserProfile]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  Future<List<UserProfile>> update(
    _i1.DatabaseSession session,
    List<UserProfile> rows, {
    _i1.ColumnSelections<UserProfileTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.update<UserProfile>(
      rows,
      columns: columns?.call(UserProfile.t),
      transaction: transaction,
    );
  }

  /// Updates a single [UserProfile]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<UserProfile> updateRow(
    _i1.DatabaseSession session,
    UserProfile row, {
    _i1.ColumnSelections<UserProfileTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<UserProfile>(
      row,
      columns: columns?.call(UserProfile.t),
      transaction: transaction,
    );
  }

  /// Updates a single [UserProfile] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<UserProfile?> updateById(
    _i1.DatabaseSession session,
    int id, {
    required _i1.ColumnValueListBuilder<UserProfileUpdateTable> columnValues,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateById<UserProfile>(
      id,
      columnValues: columnValues(UserProfile.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [UserProfile]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  Future<List<UserProfile>> updateWhere(
    _i1.DatabaseSession session, {
    required _i1.ColumnValueListBuilder<UserProfileUpdateTable> columnValues,
    required _i1.WhereExpressionBuilder<UserProfileTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<UserProfileTable>? orderBy,
    _i1.OrderByListBuilder<UserProfileTable>? orderByList,
    bool orderDescending = false,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateWhere<UserProfile>(
      columnValues: columnValues(UserProfile.t.updateTable),
      where: where(UserProfile.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(UserProfile.t),
      orderByList: orderByList?.call(UserProfile.t),
      orderDescending: orderDescending,
      transaction: transaction,
    );
  }

  /// Deletes all [UserProfile]s in the list and returns the deleted rows.
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  Future<List<UserProfile>> delete(
    _i1.DatabaseSession session,
    List<UserProfile> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<UserProfile>(
      rows,
      transaction: transaction,
    );
  }

  /// Deletes a single [UserProfile].
  Future<UserProfile> deleteRow(
    _i1.DatabaseSession session,
    UserProfile row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<UserProfile>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  Future<List<UserProfile>> deleteWhere(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<UserProfileTable> where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteWhere<UserProfile>(
      where: where(UserProfile.t),
      transaction: transaction,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<UserProfileTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<UserProfile>(
      where: where?.call(UserProfile.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [UserProfile] rows matching the [where] expression.
  Future<void> lockRows(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<UserProfileTable> where,
    required _i1.LockMode lockMode,
    required _i1.Transaction transaction,
    _i1.LockBehavior lockBehavior = _i1.LockBehavior.wait,
  }) async {
    return session.db.lockRows<UserProfile>(
      where: where(UserProfile.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
