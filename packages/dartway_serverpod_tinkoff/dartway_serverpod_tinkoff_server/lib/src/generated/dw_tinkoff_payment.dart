/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod/serverpod.dart' as _i1;
import 'dw_tinkoff_payment_status.dart' as _i2;

abstract class DwTinkoffPayment
    implements _i1.TableRow<int?>, _i1.ProtocolSerialization {
  DwTinkoffPayment._({
    this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.terminalKey,
    required this.tinkoffRawStatus,
    required this.tinkoffStatus,
    required this.tinkoffPaymentId,
    required this.tinkoffCustomerId,
    required this.orderIdentifier,
    required this.amount,
    required this.paymentUrl,
  });

  factory DwTinkoffPayment({
    int? id,
    required DateTime createdAt,
    required DateTime updatedAt,
    required String terminalKey,
    required String tinkoffRawStatus,
    required _i2.DwTinkoffPaymentStatus tinkoffStatus,
    required String tinkoffPaymentId,
    required String tinkoffCustomerId,
    required String orderIdentifier,
    required int amount,
    required String paymentUrl,
  }) = _DwTinkoffPaymentImpl;

  factory DwTinkoffPayment.fromJson(Map<String, dynamic> jsonSerialization) {
    return DwTinkoffPayment(
      id: jsonSerialization['id'] as int?,
      createdAt:
          _i1.DateTimeJsonExtension.fromJson(jsonSerialization['createdAt']),
      updatedAt:
          _i1.DateTimeJsonExtension.fromJson(jsonSerialization['updatedAt']),
      terminalKey: jsonSerialization['terminalKey'] as String,
      tinkoffRawStatus: jsonSerialization['tinkoffRawStatus'] as String,
      tinkoffStatus: _i2.DwTinkoffPaymentStatus.fromJson(
          (jsonSerialization['tinkoffStatus'] as String)),
      tinkoffPaymentId: jsonSerialization['tinkoffPaymentId'] as String,
      tinkoffCustomerId: jsonSerialization['tinkoffCustomerId'] as String,
      orderIdentifier: jsonSerialization['orderIdentifier'] as String,
      amount: jsonSerialization['amount'] as int,
      paymentUrl: jsonSerialization['paymentUrl'] as String,
    );
  }

  static final t = DwTinkoffPaymentTable();

  static const db = DwTinkoffPaymentRepository._();

  @override
  int? id;

  DateTime createdAt;

  DateTime updatedAt;

  String terminalKey;

  String tinkoffRawStatus;

  _i2.DwTinkoffPaymentStatus tinkoffStatus;

  String tinkoffPaymentId;

  String tinkoffCustomerId;

  String orderIdentifier;

  int amount;

  String paymentUrl;

  @override
  _i1.Table<int?> get table => t;

  /// Returns a shallow copy of this [DwTinkoffPayment]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  DwTinkoffPayment copyWith({
    int? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? terminalKey,
    String? tinkoffRawStatus,
    _i2.DwTinkoffPaymentStatus? tinkoffStatus,
    String? tinkoffPaymentId,
    String? tinkoffCustomerId,
    String? orderIdentifier,
    int? amount,
    String? paymentUrl,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'createdAt': createdAt.toJson(),
      'updatedAt': updatedAt.toJson(),
      'terminalKey': terminalKey,
      'tinkoffRawStatus': tinkoffRawStatus,
      'tinkoffStatus': tinkoffStatus.toJson(),
      'tinkoffPaymentId': tinkoffPaymentId,
      'tinkoffCustomerId': tinkoffCustomerId,
      'orderIdentifier': orderIdentifier,
      'amount': amount,
      'paymentUrl': paymentUrl,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      if (id != null) 'id': id,
      'createdAt': createdAt.toJson(),
      'updatedAt': updatedAt.toJson(),
      'terminalKey': terminalKey,
      'tinkoffRawStatus': tinkoffRawStatus,
      'tinkoffStatus': tinkoffStatus.toJson(),
      'tinkoffPaymentId': tinkoffPaymentId,
      'tinkoffCustomerId': tinkoffCustomerId,
      'orderIdentifier': orderIdentifier,
      'amount': amount,
      'paymentUrl': paymentUrl,
    };
  }

  static DwTinkoffPaymentInclude include() {
    return DwTinkoffPaymentInclude._();
  }

  static DwTinkoffPaymentIncludeList includeList({
    _i1.WhereExpressionBuilder<DwTinkoffPaymentTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<DwTinkoffPaymentTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<DwTinkoffPaymentTable>? orderByList,
    DwTinkoffPaymentInclude? include,
  }) {
    return DwTinkoffPaymentIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(DwTinkoffPayment.t),
      orderDescending: orderDescending,
      orderByList: orderByList?.call(DwTinkoffPayment.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _DwTinkoffPaymentImpl extends DwTinkoffPayment {
  _DwTinkoffPaymentImpl({
    int? id,
    required DateTime createdAt,
    required DateTime updatedAt,
    required String terminalKey,
    required String tinkoffRawStatus,
    required _i2.DwTinkoffPaymentStatus tinkoffStatus,
    required String tinkoffPaymentId,
    required String tinkoffCustomerId,
    required String orderIdentifier,
    required int amount,
    required String paymentUrl,
  }) : super._(
          id: id,
          createdAt: createdAt,
          updatedAt: updatedAt,
          terminalKey: terminalKey,
          tinkoffRawStatus: tinkoffRawStatus,
          tinkoffStatus: tinkoffStatus,
          tinkoffPaymentId: tinkoffPaymentId,
          tinkoffCustomerId: tinkoffCustomerId,
          orderIdentifier: orderIdentifier,
          amount: amount,
          paymentUrl: paymentUrl,
        );

  /// Returns a shallow copy of this [DwTinkoffPayment]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  DwTinkoffPayment copyWith({
    Object? id = _Undefined,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? terminalKey,
    String? tinkoffRawStatus,
    _i2.DwTinkoffPaymentStatus? tinkoffStatus,
    String? tinkoffPaymentId,
    String? tinkoffCustomerId,
    String? orderIdentifier,
    int? amount,
    String? paymentUrl,
  }) {
    return DwTinkoffPayment(
      id: id is int? ? id : this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      terminalKey: terminalKey ?? this.terminalKey,
      tinkoffRawStatus: tinkoffRawStatus ?? this.tinkoffRawStatus,
      tinkoffStatus: tinkoffStatus ?? this.tinkoffStatus,
      tinkoffPaymentId: tinkoffPaymentId ?? this.tinkoffPaymentId,
      tinkoffCustomerId: tinkoffCustomerId ?? this.tinkoffCustomerId,
      orderIdentifier: orderIdentifier ?? this.orderIdentifier,
      amount: amount ?? this.amount,
      paymentUrl: paymentUrl ?? this.paymentUrl,
    );
  }
}

class DwTinkoffPaymentTable extends _i1.Table<int?> {
  DwTinkoffPaymentTable({super.tableRelation})
      : super(tableName: 'dw_tinkoff_payment') {
    createdAt = _i1.ColumnDateTime(
      'createdAt',
      this,
    );
    updatedAt = _i1.ColumnDateTime(
      'updatedAt',
      this,
    );
    terminalKey = _i1.ColumnString(
      'terminalKey',
      this,
    );
    tinkoffRawStatus = _i1.ColumnString(
      'tinkoffRawStatus',
      this,
    );
    tinkoffStatus = _i1.ColumnEnum(
      'tinkoffStatus',
      this,
      _i1.EnumSerialization.byName,
    );
    tinkoffPaymentId = _i1.ColumnString(
      'tinkoffPaymentId',
      this,
    );
    tinkoffCustomerId = _i1.ColumnString(
      'tinkoffCustomerId',
      this,
    );
    orderIdentifier = _i1.ColumnString(
      'orderIdentifier',
      this,
    );
    amount = _i1.ColumnInt(
      'amount',
      this,
    );
    paymentUrl = _i1.ColumnString(
      'paymentUrl',
      this,
    );
  }

  late final _i1.ColumnDateTime createdAt;

  late final _i1.ColumnDateTime updatedAt;

  late final _i1.ColumnString terminalKey;

  late final _i1.ColumnString tinkoffRawStatus;

  late final _i1.ColumnEnum<_i2.DwTinkoffPaymentStatus> tinkoffStatus;

  late final _i1.ColumnString tinkoffPaymentId;

  late final _i1.ColumnString tinkoffCustomerId;

  late final _i1.ColumnString orderIdentifier;

  late final _i1.ColumnInt amount;

  late final _i1.ColumnString paymentUrl;

  @override
  List<_i1.Column> get columns => [
        id,
        createdAt,
        updatedAt,
        terminalKey,
        tinkoffRawStatus,
        tinkoffStatus,
        tinkoffPaymentId,
        tinkoffCustomerId,
        orderIdentifier,
        amount,
        paymentUrl,
      ];
}

class DwTinkoffPaymentInclude extends _i1.IncludeObject {
  DwTinkoffPaymentInclude._();

  @override
  Map<String, _i1.Include?> get includes => {};

  @override
  _i1.Table<int?> get table => DwTinkoffPayment.t;
}

class DwTinkoffPaymentIncludeList extends _i1.IncludeList {
  DwTinkoffPaymentIncludeList._({
    _i1.WhereExpressionBuilder<DwTinkoffPaymentTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(DwTinkoffPayment.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<int?> get table => DwTinkoffPayment.t;
}

class DwTinkoffPaymentRepository {
  const DwTinkoffPaymentRepository._();

  /// Returns a list of [DwTinkoffPayment]s matching the given query parameters.
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
  Future<List<DwTinkoffPayment>> find(
    _i1.Session session, {
    _i1.WhereExpressionBuilder<DwTinkoffPaymentTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<DwTinkoffPaymentTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<DwTinkoffPaymentTable>? orderByList,
    _i1.Transaction? transaction,
  }) async {
    return session.db.find<DwTinkoffPayment>(
      where: where?.call(DwTinkoffPayment.t),
      orderBy: orderBy?.call(DwTinkoffPayment.t),
      orderByList: orderByList?.call(DwTinkoffPayment.t),
      orderDescending: orderDescending,
      limit: limit,
      offset: offset,
      transaction: transaction,
    );
  }

  /// Returns the first matching [DwTinkoffPayment] matching the given query parameters.
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
  Future<DwTinkoffPayment?> findFirstRow(
    _i1.Session session, {
    _i1.WhereExpressionBuilder<DwTinkoffPaymentTable>? where,
    int? offset,
    _i1.OrderByBuilder<DwTinkoffPaymentTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<DwTinkoffPaymentTable>? orderByList,
    _i1.Transaction? transaction,
  }) async {
    return session.db.findFirstRow<DwTinkoffPayment>(
      where: where?.call(DwTinkoffPayment.t),
      orderBy: orderBy?.call(DwTinkoffPayment.t),
      orderByList: orderByList?.call(DwTinkoffPayment.t),
      orderDescending: orderDescending,
      offset: offset,
      transaction: transaction,
    );
  }

  /// Finds a single [DwTinkoffPayment] by its [id] or null if no such row exists.
  Future<DwTinkoffPayment?> findById(
    _i1.Session session,
    int id, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.findById<DwTinkoffPayment>(
      id,
      transaction: transaction,
    );
  }

  /// Inserts all [DwTinkoffPayment]s in the list and returns the inserted rows.
  ///
  /// The returned [DwTinkoffPayment]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  Future<List<DwTinkoffPayment>> insert(
    _i1.Session session,
    List<DwTinkoffPayment> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insert<DwTinkoffPayment>(
      rows,
      transaction: transaction,
    );
  }

  /// Inserts a single [DwTinkoffPayment] and returns the inserted row.
  ///
  /// The returned [DwTinkoffPayment] will have its `id` field set.
  Future<DwTinkoffPayment> insertRow(
    _i1.Session session,
    DwTinkoffPayment row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<DwTinkoffPayment>(
      row,
      transaction: transaction,
    );
  }

  /// Updates all [DwTinkoffPayment]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  Future<List<DwTinkoffPayment>> update(
    _i1.Session session,
    List<DwTinkoffPayment> rows, {
    _i1.ColumnSelections<DwTinkoffPaymentTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.update<DwTinkoffPayment>(
      rows,
      columns: columns?.call(DwTinkoffPayment.t),
      transaction: transaction,
    );
  }

  /// Updates a single [DwTinkoffPayment]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<DwTinkoffPayment> updateRow(
    _i1.Session session,
    DwTinkoffPayment row, {
    _i1.ColumnSelections<DwTinkoffPaymentTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<DwTinkoffPayment>(
      row,
      columns: columns?.call(DwTinkoffPayment.t),
      transaction: transaction,
    );
  }

  /// Deletes all [DwTinkoffPayment]s in the list and returns the deleted rows.
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  Future<List<DwTinkoffPayment>> delete(
    _i1.Session session,
    List<DwTinkoffPayment> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<DwTinkoffPayment>(
      rows,
      transaction: transaction,
    );
  }

  /// Deletes a single [DwTinkoffPayment].
  Future<DwTinkoffPayment> deleteRow(
    _i1.Session session,
    DwTinkoffPayment row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<DwTinkoffPayment>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  Future<List<DwTinkoffPayment>> deleteWhere(
    _i1.Session session, {
    required _i1.WhereExpressionBuilder<DwTinkoffPaymentTable> where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteWhere<DwTinkoffPayment>(
      where: where(DwTinkoffPayment.t),
      transaction: transaction,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.Session session, {
    _i1.WhereExpressionBuilder<DwTinkoffPaymentTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<DwTinkoffPayment>(
      where: where?.call(DwTinkoffPayment.t),
      limit: limit,
      transaction: transaction,
    );
  }
}
