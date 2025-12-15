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

abstract class DwCloudFile
    implements _i1.TableRow<int?>, _i1.ProtocolSerialization {
  DwCloudFile._({
    this.id,
    this.createdBy,
    required this.bucket,
    required this.path,
    required this.publicUrl,
    this.size,
    this.mimeType,
    required this.createdAt,
    this.verifiedAt,
  });

  factory DwCloudFile({
    int? id,
    int? createdBy,
    required String bucket,
    required String path,
    required String publicUrl,
    int? size,
    String? mimeType,
    required DateTime createdAt,
    DateTime? verifiedAt,
  }) = _DwCloudFileImpl;

  factory DwCloudFile.fromJson(Map<String, dynamic> jsonSerialization) {
    return DwCloudFile(
      id: jsonSerialization['id'] as int?,
      createdBy: jsonSerialization['createdBy'] as int?,
      bucket: jsonSerialization['bucket'] as String,
      path: jsonSerialization['path'] as String,
      publicUrl: jsonSerialization['publicUrl'] as String,
      size: jsonSerialization['size'] as int?,
      mimeType: jsonSerialization['mimeType'] as String?,
      createdAt:
          _i1.DateTimeJsonExtension.fromJson(jsonSerialization['createdAt']),
      verifiedAt: jsonSerialization['verifiedAt'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(jsonSerialization['verifiedAt']),
    );
  }

  static final t = DwCloudFileTable();

  static const db = DwCloudFileRepository._();

  @override
  int? id;

  int? createdBy;

  String bucket;

  String path;

  String publicUrl;

  int? size;

  String? mimeType;

  DateTime createdAt;

  DateTime? verifiedAt;

  @override
  _i1.Table<int?> get table => t;

  /// Returns a shallow copy of this [DwCloudFile]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  DwCloudFile copyWith({
    int? id,
    int? createdBy,
    String? bucket,
    String? path,
    String? publicUrl,
    int? size,
    String? mimeType,
    DateTime? createdAt,
    DateTime? verifiedAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (createdBy != null) 'createdBy': createdBy,
      'bucket': bucket,
      'path': path,
      'publicUrl': publicUrl,
      if (size != null) 'size': size,
      if (mimeType != null) 'mimeType': mimeType,
      'createdAt': createdAt.toJson(),
      if (verifiedAt != null) 'verifiedAt': verifiedAt?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      if (id != null) 'id': id,
      if (createdBy != null) 'createdBy': createdBy,
      'bucket': bucket,
      'path': path,
      'publicUrl': publicUrl,
      if (size != null) 'size': size,
      if (mimeType != null) 'mimeType': mimeType,
      'createdAt': createdAt.toJson(),
      if (verifiedAt != null) 'verifiedAt': verifiedAt?.toJson(),
    };
  }

  static DwCloudFileInclude include() {
    return DwCloudFileInclude._();
  }

  static DwCloudFileIncludeList includeList({
    _i1.WhereExpressionBuilder<DwCloudFileTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<DwCloudFileTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<DwCloudFileTable>? orderByList,
    DwCloudFileInclude? include,
  }) {
    return DwCloudFileIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(DwCloudFile.t),
      orderDescending: orderDescending,
      orderByList: orderByList?.call(DwCloudFile.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _DwCloudFileImpl extends DwCloudFile {
  _DwCloudFileImpl({
    int? id,
    int? createdBy,
    required String bucket,
    required String path,
    required String publicUrl,
    int? size,
    String? mimeType,
    required DateTime createdAt,
    DateTime? verifiedAt,
  }) : super._(
          id: id,
          createdBy: createdBy,
          bucket: bucket,
          path: path,
          publicUrl: publicUrl,
          size: size,
          mimeType: mimeType,
          createdAt: createdAt,
          verifiedAt: verifiedAt,
        );

  /// Returns a shallow copy of this [DwCloudFile]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  DwCloudFile copyWith({
    Object? id = _Undefined,
    Object? createdBy = _Undefined,
    String? bucket,
    String? path,
    String? publicUrl,
    Object? size = _Undefined,
    Object? mimeType = _Undefined,
    DateTime? createdAt,
    Object? verifiedAt = _Undefined,
  }) {
    return DwCloudFile(
      id: id is int? ? id : this.id,
      createdBy: createdBy is int? ? createdBy : this.createdBy,
      bucket: bucket ?? this.bucket,
      path: path ?? this.path,
      publicUrl: publicUrl ?? this.publicUrl,
      size: size is int? ? size : this.size,
      mimeType: mimeType is String? ? mimeType : this.mimeType,
      createdAt: createdAt ?? this.createdAt,
      verifiedAt: verifiedAt is DateTime? ? verifiedAt : this.verifiedAt,
    );
  }
}

class DwCloudFileTable extends _i1.Table<int?> {
  DwCloudFileTable({super.tableRelation}) : super(tableName: 'dw_cloud_file') {
    createdBy = _i1.ColumnInt(
      'createdBy',
      this,
    );
    bucket = _i1.ColumnString(
      'bucket',
      this,
    );
    path = _i1.ColumnString(
      'path',
      this,
    );
    publicUrl = _i1.ColumnString(
      'publicUrl',
      this,
    );
    size = _i1.ColumnInt(
      'size',
      this,
    );
    mimeType = _i1.ColumnString(
      'mimeType',
      this,
    );
    createdAt = _i1.ColumnDateTime(
      'createdAt',
      this,
    );
    verifiedAt = _i1.ColumnDateTime(
      'verifiedAt',
      this,
    );
  }

  late final _i1.ColumnInt createdBy;

  late final _i1.ColumnString bucket;

  late final _i1.ColumnString path;

  late final _i1.ColumnString publicUrl;

  late final _i1.ColumnInt size;

  late final _i1.ColumnString mimeType;

  late final _i1.ColumnDateTime createdAt;

  late final _i1.ColumnDateTime verifiedAt;

  @override
  List<_i1.Column> get columns => [
        id,
        createdBy,
        bucket,
        path,
        publicUrl,
        size,
        mimeType,
        createdAt,
        verifiedAt,
      ];
}

class DwCloudFileInclude extends _i1.IncludeObject {
  DwCloudFileInclude._();

  @override
  Map<String, _i1.Include?> get includes => {};

  @override
  _i1.Table<int?> get table => DwCloudFile.t;
}

class DwCloudFileIncludeList extends _i1.IncludeList {
  DwCloudFileIncludeList._({
    _i1.WhereExpressionBuilder<DwCloudFileTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(DwCloudFile.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<int?> get table => DwCloudFile.t;
}

class DwCloudFileRepository {
  const DwCloudFileRepository._();

  /// Returns a list of [DwCloudFile]s matching the given query parameters.
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
  Future<List<DwCloudFile>> find(
    _i1.Session session, {
    _i1.WhereExpressionBuilder<DwCloudFileTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<DwCloudFileTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<DwCloudFileTable>? orderByList,
    _i1.Transaction? transaction,
  }) async {
    return session.db.find<DwCloudFile>(
      where: where?.call(DwCloudFile.t),
      orderBy: orderBy?.call(DwCloudFile.t),
      orderByList: orderByList?.call(DwCloudFile.t),
      orderDescending: orderDescending,
      limit: limit,
      offset: offset,
      transaction: transaction,
    );
  }

  /// Returns the first matching [DwCloudFile] matching the given query parameters.
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
  Future<DwCloudFile?> findFirstRow(
    _i1.Session session, {
    _i1.WhereExpressionBuilder<DwCloudFileTable>? where,
    int? offset,
    _i1.OrderByBuilder<DwCloudFileTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<DwCloudFileTable>? orderByList,
    _i1.Transaction? transaction,
  }) async {
    return session.db.findFirstRow<DwCloudFile>(
      where: where?.call(DwCloudFile.t),
      orderBy: orderBy?.call(DwCloudFile.t),
      orderByList: orderByList?.call(DwCloudFile.t),
      orderDescending: orderDescending,
      offset: offset,
      transaction: transaction,
    );
  }

  /// Finds a single [DwCloudFile] by its [id] or null if no such row exists.
  Future<DwCloudFile?> findById(
    _i1.Session session,
    int id, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.findById<DwCloudFile>(
      id,
      transaction: transaction,
    );
  }

  /// Inserts all [DwCloudFile]s in the list and returns the inserted rows.
  ///
  /// The returned [DwCloudFile]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  Future<List<DwCloudFile>> insert(
    _i1.Session session,
    List<DwCloudFile> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insert<DwCloudFile>(
      rows,
      transaction: transaction,
    );
  }

  /// Inserts a single [DwCloudFile] and returns the inserted row.
  ///
  /// The returned [DwCloudFile] will have its `id` field set.
  Future<DwCloudFile> insertRow(
    _i1.Session session,
    DwCloudFile row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<DwCloudFile>(
      row,
      transaction: transaction,
    );
  }

  /// Updates all [DwCloudFile]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  Future<List<DwCloudFile>> update(
    _i1.Session session,
    List<DwCloudFile> rows, {
    _i1.ColumnSelections<DwCloudFileTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.update<DwCloudFile>(
      rows,
      columns: columns?.call(DwCloudFile.t),
      transaction: transaction,
    );
  }

  /// Updates a single [DwCloudFile]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<DwCloudFile> updateRow(
    _i1.Session session,
    DwCloudFile row, {
    _i1.ColumnSelections<DwCloudFileTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<DwCloudFile>(
      row,
      columns: columns?.call(DwCloudFile.t),
      transaction: transaction,
    );
  }

  /// Deletes all [DwCloudFile]s in the list and returns the deleted rows.
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  Future<List<DwCloudFile>> delete(
    _i1.Session session,
    List<DwCloudFile> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<DwCloudFile>(
      rows,
      transaction: transaction,
    );
  }

  /// Deletes a single [DwCloudFile].
  Future<DwCloudFile> deleteRow(
    _i1.Session session,
    DwCloudFile row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<DwCloudFile>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  Future<List<DwCloudFile>> deleteWhere(
    _i1.Session session, {
    required _i1.WhereExpressionBuilder<DwCloudFileTable> where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteWhere<DwCloudFile>(
      where: where(DwCloudFile.t),
      transaction: transaction,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.Session session, {
    _i1.WhereExpressionBuilder<DwCloudFileTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<DwCloudFile>(
      where: where?.call(DwCloudFile.t),
      limit: limit,
      transaction: transaction,
    );
  }
}
