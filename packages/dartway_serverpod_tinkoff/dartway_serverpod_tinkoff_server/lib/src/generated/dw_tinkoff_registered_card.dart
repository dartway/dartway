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

abstract class DwTinkoffRegisteredCard
    implements _i1.TableRow<int?>, _i1.ProtocolSerialization {
  DwTinkoffRegisteredCard._({
    this.id,
    required this.tinkoffCustomerId,
    required this.cardPan,
    required this.status,
    required this.tinkoffCardId,
    this.rebillId,
  });

  factory DwTinkoffRegisteredCard({
    int? id,
    required String tinkoffCustomerId,
    required String cardPan,
    required String status,
    required String tinkoffCardId,
    String? rebillId,
  }) = _DwTinkoffRegisteredCardImpl;

  factory DwTinkoffRegisteredCard.fromJson(
      Map<String, dynamic> jsonSerialization) {
    return DwTinkoffRegisteredCard(
      id: jsonSerialization['id'] as int?,
      tinkoffCustomerId: jsonSerialization['tinkoffCustomerId'] as String,
      cardPan: jsonSerialization['cardPan'] as String,
      status: jsonSerialization['status'] as String,
      tinkoffCardId: jsonSerialization['tinkoffCardId'] as String,
      rebillId: jsonSerialization['rebillId'] as String?,
    );
  }

  static final t = DwTinkoffRegisteredCardTable();

  static const db = DwTinkoffRegisteredCardRepository._();

  @override
  int? id;

  String tinkoffCustomerId;

  String cardPan;

  String status;

  String tinkoffCardId;

  String? rebillId;

  @override
  _i1.Table<int?> get table => t;

  /// Returns a shallow copy of this [DwTinkoffRegisteredCard]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  DwTinkoffRegisteredCard copyWith({
    int? id,
    String? tinkoffCustomerId,
    String? cardPan,
    String? status,
    String? tinkoffCardId,
    String? rebillId,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'tinkoffCustomerId': tinkoffCustomerId,
      'cardPan': cardPan,
      'status': status,
      'tinkoffCardId': tinkoffCardId,
      if (rebillId != null) 'rebillId': rebillId,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      if (id != null) 'id': id,
      'tinkoffCustomerId': tinkoffCustomerId,
      'cardPan': cardPan,
      'status': status,
      'tinkoffCardId': tinkoffCardId,
      if (rebillId != null) 'rebillId': rebillId,
    };
  }

  static DwTinkoffRegisteredCardInclude include() {
    return DwTinkoffRegisteredCardInclude._();
  }

  static DwTinkoffRegisteredCardIncludeList includeList({
    _i1.WhereExpressionBuilder<DwTinkoffRegisteredCardTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<DwTinkoffRegisteredCardTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<DwTinkoffRegisteredCardTable>? orderByList,
    DwTinkoffRegisteredCardInclude? include,
  }) {
    return DwTinkoffRegisteredCardIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(DwTinkoffRegisteredCard.t),
      orderDescending: orderDescending,
      orderByList: orderByList?.call(DwTinkoffRegisteredCard.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _DwTinkoffRegisteredCardImpl extends DwTinkoffRegisteredCard {
  _DwTinkoffRegisteredCardImpl({
    int? id,
    required String tinkoffCustomerId,
    required String cardPan,
    required String status,
    required String tinkoffCardId,
    String? rebillId,
  }) : super._(
          id: id,
          tinkoffCustomerId: tinkoffCustomerId,
          cardPan: cardPan,
          status: status,
          tinkoffCardId: tinkoffCardId,
          rebillId: rebillId,
        );

  /// Returns a shallow copy of this [DwTinkoffRegisteredCard]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  DwTinkoffRegisteredCard copyWith({
    Object? id = _Undefined,
    String? tinkoffCustomerId,
    String? cardPan,
    String? status,
    String? tinkoffCardId,
    Object? rebillId = _Undefined,
  }) {
    return DwTinkoffRegisteredCard(
      id: id is int? ? id : this.id,
      tinkoffCustomerId: tinkoffCustomerId ?? this.tinkoffCustomerId,
      cardPan: cardPan ?? this.cardPan,
      status: status ?? this.status,
      tinkoffCardId: tinkoffCardId ?? this.tinkoffCardId,
      rebillId: rebillId is String? ? rebillId : this.rebillId,
    );
  }
}

class DwTinkoffRegisteredCardTable extends _i1.Table<int?> {
  DwTinkoffRegisteredCardTable({super.tableRelation})
      : super(tableName: 'dw_tinkoff_registered_card') {
    tinkoffCustomerId = _i1.ColumnString(
      'tinkoffCustomerId',
      this,
    );
    cardPan = _i1.ColumnString(
      'cardPan',
      this,
    );
    status = _i1.ColumnString(
      'status',
      this,
    );
    tinkoffCardId = _i1.ColumnString(
      'tinkoffCardId',
      this,
    );
    rebillId = _i1.ColumnString(
      'rebillId',
      this,
    );
  }

  late final _i1.ColumnString tinkoffCustomerId;

  late final _i1.ColumnString cardPan;

  late final _i1.ColumnString status;

  late final _i1.ColumnString tinkoffCardId;

  late final _i1.ColumnString rebillId;

  @override
  List<_i1.Column> get columns => [
        id,
        tinkoffCustomerId,
        cardPan,
        status,
        tinkoffCardId,
        rebillId,
      ];
}

class DwTinkoffRegisteredCardInclude extends _i1.IncludeObject {
  DwTinkoffRegisteredCardInclude._();

  @override
  Map<String, _i1.Include?> get includes => {};

  @override
  _i1.Table<int?> get table => DwTinkoffRegisteredCard.t;
}

class DwTinkoffRegisteredCardIncludeList extends _i1.IncludeList {
  DwTinkoffRegisteredCardIncludeList._({
    _i1.WhereExpressionBuilder<DwTinkoffRegisteredCardTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(DwTinkoffRegisteredCard.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<int?> get table => DwTinkoffRegisteredCard.t;
}

class DwTinkoffRegisteredCardRepository {
  const DwTinkoffRegisteredCardRepository._();

  /// Returns a list of [DwTinkoffRegisteredCard]s matching the given query parameters.
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
  Future<List<DwTinkoffRegisteredCard>> find(
    _i1.Session session, {
    _i1.WhereExpressionBuilder<DwTinkoffRegisteredCardTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<DwTinkoffRegisteredCardTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<DwTinkoffRegisteredCardTable>? orderByList,
    _i1.Transaction? transaction,
  }) async {
    return session.db.find<DwTinkoffRegisteredCard>(
      where: where?.call(DwTinkoffRegisteredCard.t),
      orderBy: orderBy?.call(DwTinkoffRegisteredCard.t),
      orderByList: orderByList?.call(DwTinkoffRegisteredCard.t),
      orderDescending: orderDescending,
      limit: limit,
      offset: offset,
      transaction: transaction,
    );
  }

  /// Returns the first matching [DwTinkoffRegisteredCard] matching the given query parameters.
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
  Future<DwTinkoffRegisteredCard?> findFirstRow(
    _i1.Session session, {
    _i1.WhereExpressionBuilder<DwTinkoffRegisteredCardTable>? where,
    int? offset,
    _i1.OrderByBuilder<DwTinkoffRegisteredCardTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<DwTinkoffRegisteredCardTable>? orderByList,
    _i1.Transaction? transaction,
  }) async {
    return session.db.findFirstRow<DwTinkoffRegisteredCard>(
      where: where?.call(DwTinkoffRegisteredCard.t),
      orderBy: orderBy?.call(DwTinkoffRegisteredCard.t),
      orderByList: orderByList?.call(DwTinkoffRegisteredCard.t),
      orderDescending: orderDescending,
      offset: offset,
      transaction: transaction,
    );
  }

  /// Finds a single [DwTinkoffRegisteredCard] by its [id] or null if no such row exists.
  Future<DwTinkoffRegisteredCard?> findById(
    _i1.Session session,
    int id, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.findById<DwTinkoffRegisteredCard>(
      id,
      transaction: transaction,
    );
  }

  /// Inserts all [DwTinkoffRegisteredCard]s in the list and returns the inserted rows.
  ///
  /// The returned [DwTinkoffRegisteredCard]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  Future<List<DwTinkoffRegisteredCard>> insert(
    _i1.Session session,
    List<DwTinkoffRegisteredCard> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insert<DwTinkoffRegisteredCard>(
      rows,
      transaction: transaction,
    );
  }

  /// Inserts a single [DwTinkoffRegisteredCard] and returns the inserted row.
  ///
  /// The returned [DwTinkoffRegisteredCard] will have its `id` field set.
  Future<DwTinkoffRegisteredCard> insertRow(
    _i1.Session session,
    DwTinkoffRegisteredCard row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<DwTinkoffRegisteredCard>(
      row,
      transaction: transaction,
    );
  }

  /// Updates all [DwTinkoffRegisteredCard]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  Future<List<DwTinkoffRegisteredCard>> update(
    _i1.Session session,
    List<DwTinkoffRegisteredCard> rows, {
    _i1.ColumnSelections<DwTinkoffRegisteredCardTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.update<DwTinkoffRegisteredCard>(
      rows,
      columns: columns?.call(DwTinkoffRegisteredCard.t),
      transaction: transaction,
    );
  }

  /// Updates a single [DwTinkoffRegisteredCard]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<DwTinkoffRegisteredCard> updateRow(
    _i1.Session session,
    DwTinkoffRegisteredCard row, {
    _i1.ColumnSelections<DwTinkoffRegisteredCardTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<DwTinkoffRegisteredCard>(
      row,
      columns: columns?.call(DwTinkoffRegisteredCard.t),
      transaction: transaction,
    );
  }

  /// Deletes all [DwTinkoffRegisteredCard]s in the list and returns the deleted rows.
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  Future<List<DwTinkoffRegisteredCard>> delete(
    _i1.Session session,
    List<DwTinkoffRegisteredCard> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<DwTinkoffRegisteredCard>(
      rows,
      transaction: transaction,
    );
  }

  /// Deletes a single [DwTinkoffRegisteredCard].
  Future<DwTinkoffRegisteredCard> deleteRow(
    _i1.Session session,
    DwTinkoffRegisteredCard row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<DwTinkoffRegisteredCard>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  Future<List<DwTinkoffRegisteredCard>> deleteWhere(
    _i1.Session session, {
    required _i1.WhereExpressionBuilder<DwTinkoffRegisteredCardTable> where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteWhere<DwTinkoffRegisteredCard>(
      where: where(DwTinkoffRegisteredCard.t),
      transaction: transaction,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.Session session, {
    _i1.WhereExpressionBuilder<DwTinkoffRegisteredCardTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<DwTinkoffRegisteredCard>(
      where: where?.call(DwTinkoffRegisteredCard.t),
      limit: limit,
      transaction: transaction,
    );
  }
}
