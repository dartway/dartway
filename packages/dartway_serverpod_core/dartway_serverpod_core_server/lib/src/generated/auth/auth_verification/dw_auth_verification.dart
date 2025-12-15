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

import '../auth_request/dw_auth_request.dart' as _i2;
import '../dw_auth_fail_reason.dart' as _i3;

abstract class DwAuthVerification
    implements _i1.TableRow<int?>, _i1.ProtocolSerialization {
  DwAuthVerification._({
    this.id,
    required this.dwAuthRequestId,
    this.dwAuthRequest,
    DateTime? createdAt,
    this.verificationCode,
    this.failReason,
    this.accessToken,
  }) : createdAt = createdAt ?? DateTime.now();

  factory DwAuthVerification({
    int? id,
    required int dwAuthRequestId,
    _i2.DwAuthRequest? dwAuthRequest,
    DateTime? createdAt,
    String? verificationCode,
    _i3.DwAuthFailReason? failReason,
    String? accessToken,
  }) = _DwAuthVerificationImpl;

  factory DwAuthVerification.fromJson(Map<String, dynamic> jsonSerialization) {
    return DwAuthVerification(
      id: jsonSerialization['id'] as int?,
      dwAuthRequestId: jsonSerialization['dwAuthRequestId'] as int,
      dwAuthRequest: jsonSerialization['dwAuthRequest'] == null
          ? null
          : _i2.DwAuthRequest.fromJson(
              (jsonSerialization['dwAuthRequest'] as Map<String, dynamic>)),
      createdAt:
          _i1.DateTimeJsonExtension.fromJson(jsonSerialization['createdAt']),
      verificationCode: jsonSerialization['verificationCode'] as String?,
      failReason: jsonSerialization['failReason'] == null
          ? null
          : _i3.DwAuthFailReason.fromJson(
              (jsonSerialization['failReason'] as String)),
      accessToken: jsonSerialization['accessToken'] as String?,
    );
  }

  static final t = DwAuthVerificationTable();

  static const db = DwAuthVerificationRepository._();

  @override
  int? id;

  int dwAuthRequestId;

  _i2.DwAuthRequest? dwAuthRequest;

  DateTime createdAt;

  String? verificationCode;

  _i3.DwAuthFailReason? failReason;

  String? accessToken;

  @override
  _i1.Table<int?> get table => t;

  /// Returns a shallow copy of this [DwAuthVerification]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  DwAuthVerification copyWith({
    int? id,
    int? dwAuthRequestId,
    _i2.DwAuthRequest? dwAuthRequest,
    DateTime? createdAt,
    String? verificationCode,
    _i3.DwAuthFailReason? failReason,
    String? accessToken,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'dwAuthRequestId': dwAuthRequestId,
      if (dwAuthRequest != null) 'dwAuthRequest': dwAuthRequest?.toJson(),
      'createdAt': createdAt.toJson(),
      if (verificationCode != null) 'verificationCode': verificationCode,
      if (failReason != null) 'failReason': failReason?.toJson(),
      if (accessToken != null) 'accessToken': accessToken,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      if (id != null) 'id': id,
      'dwAuthRequestId': dwAuthRequestId,
      if (dwAuthRequest != null)
        'dwAuthRequest': dwAuthRequest?.toJsonForProtocol(),
      'createdAt': createdAt.toJson(),
      if (verificationCode != null) 'verificationCode': verificationCode,
      if (failReason != null) 'failReason': failReason?.toJson(),
      if (accessToken != null) 'accessToken': accessToken,
    };
  }

  static DwAuthVerificationInclude include(
      {_i2.DwAuthRequestInclude? dwAuthRequest}) {
    return DwAuthVerificationInclude._(dwAuthRequest: dwAuthRequest);
  }

  static DwAuthVerificationIncludeList includeList({
    _i1.WhereExpressionBuilder<DwAuthVerificationTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<DwAuthVerificationTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<DwAuthVerificationTable>? orderByList,
    DwAuthVerificationInclude? include,
  }) {
    return DwAuthVerificationIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(DwAuthVerification.t),
      orderDescending: orderDescending,
      orderByList: orderByList?.call(DwAuthVerification.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _DwAuthVerificationImpl extends DwAuthVerification {
  _DwAuthVerificationImpl({
    int? id,
    required int dwAuthRequestId,
    _i2.DwAuthRequest? dwAuthRequest,
    DateTime? createdAt,
    String? verificationCode,
    _i3.DwAuthFailReason? failReason,
    String? accessToken,
  }) : super._(
          id: id,
          dwAuthRequestId: dwAuthRequestId,
          dwAuthRequest: dwAuthRequest,
          createdAt: createdAt,
          verificationCode: verificationCode,
          failReason: failReason,
          accessToken: accessToken,
        );

  /// Returns a shallow copy of this [DwAuthVerification]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  DwAuthVerification copyWith({
    Object? id = _Undefined,
    int? dwAuthRequestId,
    Object? dwAuthRequest = _Undefined,
    DateTime? createdAt,
    Object? verificationCode = _Undefined,
    Object? failReason = _Undefined,
    Object? accessToken = _Undefined,
  }) {
    return DwAuthVerification(
      id: id is int? ? id : this.id,
      dwAuthRequestId: dwAuthRequestId ?? this.dwAuthRequestId,
      dwAuthRequest: dwAuthRequest is _i2.DwAuthRequest?
          ? dwAuthRequest
          : this.dwAuthRequest?.copyWith(),
      createdAt: createdAt ?? this.createdAt,
      verificationCode: verificationCode is String?
          ? verificationCode
          : this.verificationCode,
      failReason:
          failReason is _i3.DwAuthFailReason? ? failReason : this.failReason,
      accessToken: accessToken is String? ? accessToken : this.accessToken,
    );
  }
}

class DwAuthVerificationTable extends _i1.Table<int?> {
  DwAuthVerificationTable({super.tableRelation})
      : super(tableName: 'dw_auth_verification') {
    dwAuthRequestId = _i1.ColumnInt(
      'dwAuthRequestId',
      this,
    );
    createdAt = _i1.ColumnDateTime(
      'createdAt',
      this,
      hasDefault: true,
    );
    failReason = _i1.ColumnEnum(
      'failReason',
      this,
      _i1.EnumSerialization.byName,
    );
    accessToken = _i1.ColumnString(
      'accessToken',
      this,
    );
  }

  late final _i1.ColumnInt dwAuthRequestId;

  _i2.DwAuthRequestTable? _dwAuthRequest;

  late final _i1.ColumnDateTime createdAt;

  late final _i1.ColumnEnum<_i3.DwAuthFailReason> failReason;

  late final _i1.ColumnString accessToken;

  _i2.DwAuthRequestTable get dwAuthRequest {
    if (_dwAuthRequest != null) return _dwAuthRequest!;
    _dwAuthRequest = _i1.createRelationTable(
      relationFieldName: 'dwAuthRequest',
      field: DwAuthVerification.t.dwAuthRequestId,
      foreignField: _i2.DwAuthRequest.t.id,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _i2.DwAuthRequestTable(tableRelation: foreignTableRelation),
    );
    return _dwAuthRequest!;
  }

  @override
  List<_i1.Column> get columns => [
        id,
        dwAuthRequestId,
        createdAt,
        failReason,
        accessToken,
      ];

  @override
  _i1.Table? getRelationTable(String relationField) {
    if (relationField == 'dwAuthRequest') {
      return dwAuthRequest;
    }
    return null;
  }
}

class DwAuthVerificationInclude extends _i1.IncludeObject {
  DwAuthVerificationInclude._({_i2.DwAuthRequestInclude? dwAuthRequest}) {
    _dwAuthRequest = dwAuthRequest;
  }

  _i2.DwAuthRequestInclude? _dwAuthRequest;

  @override
  Map<String, _i1.Include?> get includes => {'dwAuthRequest': _dwAuthRequest};

  @override
  _i1.Table<int?> get table => DwAuthVerification.t;
}

class DwAuthVerificationIncludeList extends _i1.IncludeList {
  DwAuthVerificationIncludeList._({
    _i1.WhereExpressionBuilder<DwAuthVerificationTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(DwAuthVerification.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<int?> get table => DwAuthVerification.t;
}

class DwAuthVerificationRepository {
  const DwAuthVerificationRepository._();

  final attachRow = const DwAuthVerificationAttachRowRepository._();

  /// Returns a list of [DwAuthVerification]s matching the given query parameters.
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
  Future<List<DwAuthVerification>> find(
    _i1.Session session, {
    _i1.WhereExpressionBuilder<DwAuthVerificationTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<DwAuthVerificationTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<DwAuthVerificationTable>? orderByList,
    _i1.Transaction? transaction,
    DwAuthVerificationInclude? include,
  }) async {
    return session.db.find<DwAuthVerification>(
      where: where?.call(DwAuthVerification.t),
      orderBy: orderBy?.call(DwAuthVerification.t),
      orderByList: orderByList?.call(DwAuthVerification.t),
      orderDescending: orderDescending,
      limit: limit,
      offset: offset,
      transaction: transaction,
      include: include,
    );
  }

  /// Returns the first matching [DwAuthVerification] matching the given query parameters.
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
  Future<DwAuthVerification?> findFirstRow(
    _i1.Session session, {
    _i1.WhereExpressionBuilder<DwAuthVerificationTable>? where,
    int? offset,
    _i1.OrderByBuilder<DwAuthVerificationTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<DwAuthVerificationTable>? orderByList,
    _i1.Transaction? transaction,
    DwAuthVerificationInclude? include,
  }) async {
    return session.db.findFirstRow<DwAuthVerification>(
      where: where?.call(DwAuthVerification.t),
      orderBy: orderBy?.call(DwAuthVerification.t),
      orderByList: orderByList?.call(DwAuthVerification.t),
      orderDescending: orderDescending,
      offset: offset,
      transaction: transaction,
      include: include,
    );
  }

  /// Finds a single [DwAuthVerification] by its [id] or null if no such row exists.
  Future<DwAuthVerification?> findById(
    _i1.Session session,
    int id, {
    _i1.Transaction? transaction,
    DwAuthVerificationInclude? include,
  }) async {
    return session.db.findById<DwAuthVerification>(
      id,
      transaction: transaction,
      include: include,
    );
  }

  /// Inserts all [DwAuthVerification]s in the list and returns the inserted rows.
  ///
  /// The returned [DwAuthVerification]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  Future<List<DwAuthVerification>> insert(
    _i1.Session session,
    List<DwAuthVerification> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insert<DwAuthVerification>(
      rows,
      transaction: transaction,
    );
  }

  /// Inserts a single [DwAuthVerification] and returns the inserted row.
  ///
  /// The returned [DwAuthVerification] will have its `id` field set.
  Future<DwAuthVerification> insertRow(
    _i1.Session session,
    DwAuthVerification row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<DwAuthVerification>(
      row,
      transaction: transaction,
    );
  }

  /// Updates all [DwAuthVerification]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  Future<List<DwAuthVerification>> update(
    _i1.Session session,
    List<DwAuthVerification> rows, {
    _i1.ColumnSelections<DwAuthVerificationTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.update<DwAuthVerification>(
      rows,
      columns: columns?.call(DwAuthVerification.t),
      transaction: transaction,
    );
  }

  /// Updates a single [DwAuthVerification]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<DwAuthVerification> updateRow(
    _i1.Session session,
    DwAuthVerification row, {
    _i1.ColumnSelections<DwAuthVerificationTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<DwAuthVerification>(
      row,
      columns: columns?.call(DwAuthVerification.t),
      transaction: transaction,
    );
  }

  /// Deletes all [DwAuthVerification]s in the list and returns the deleted rows.
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  Future<List<DwAuthVerification>> delete(
    _i1.Session session,
    List<DwAuthVerification> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<DwAuthVerification>(
      rows,
      transaction: transaction,
    );
  }

  /// Deletes a single [DwAuthVerification].
  Future<DwAuthVerification> deleteRow(
    _i1.Session session,
    DwAuthVerification row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<DwAuthVerification>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  Future<List<DwAuthVerification>> deleteWhere(
    _i1.Session session, {
    required _i1.WhereExpressionBuilder<DwAuthVerificationTable> where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteWhere<DwAuthVerification>(
      where: where(DwAuthVerification.t),
      transaction: transaction,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.Session session, {
    _i1.WhereExpressionBuilder<DwAuthVerificationTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<DwAuthVerification>(
      where: where?.call(DwAuthVerification.t),
      limit: limit,
      transaction: transaction,
    );
  }
}

class DwAuthVerificationAttachRowRepository {
  const DwAuthVerificationAttachRowRepository._();

  /// Creates a relation between the given [DwAuthVerification] and [DwAuthRequest]
  /// by setting the [DwAuthVerification]'s foreign key `dwAuthRequestId` to refer to the [DwAuthRequest].
  Future<void> dwAuthRequest(
    _i1.Session session,
    DwAuthVerification dwAuthVerification,
    _i2.DwAuthRequest dwAuthRequest, {
    _i1.Transaction? transaction,
  }) async {
    if (dwAuthVerification.id == null) {
      throw ArgumentError.notNull('dwAuthVerification.id');
    }
    if (dwAuthRequest.id == null) {
      throw ArgumentError.notNull('dwAuthRequest.id');
    }

    var $dwAuthVerification =
        dwAuthVerification.copyWith(dwAuthRequestId: dwAuthRequest.id);
    await session.db.updateRow<DwAuthVerification>(
      $dwAuthVerification,
      columns: [DwAuthVerification.t.dwAuthRequestId],
      transaction: transaction,
    );
  }
}
