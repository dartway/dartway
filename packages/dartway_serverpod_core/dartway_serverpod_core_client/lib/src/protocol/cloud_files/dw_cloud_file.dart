/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod_client/serverpod_client.dart' as _i1;

abstract class DwCloudFile implements _i1.SerializableModel {
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

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  int? createdBy;

  String bucket;

  String path;

  String publicUrl;

  int? size;

  String? mimeType;

  DateTime createdAt;

  DateTime? verifiedAt;

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
