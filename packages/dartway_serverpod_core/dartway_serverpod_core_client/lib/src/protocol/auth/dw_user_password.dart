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

abstract class DwUserPassword implements _i1.SerializableModel {
  DwUserPassword._({
    this.id,
    required this.userId,
    required this.passwordHash,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DwUserPassword({
    int? id,
    required int userId,
    required String passwordHash,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _DwUserPasswordImpl;

  factory DwUserPassword.fromJson(Map<String, dynamic> jsonSerialization) {
    return DwUserPassword(
      id: jsonSerialization['id'] as int?,
      userId: jsonSerialization['userId'] as int,
      passwordHash: jsonSerialization['passwordHash'] as String,
      createdAt:
          _i1.DateTimeJsonExtension.fromJson(jsonSerialization['createdAt']),
      updatedAt:
          _i1.DateTimeJsonExtension.fromJson(jsonSerialization['updatedAt']),
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  int userId;

  String passwordHash;

  DateTime createdAt;

  DateTime updatedAt;

  /// Returns a shallow copy of this [DwUserPassword]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  DwUserPassword copyWith({
    int? id,
    int? userId,
    String? passwordHash,
    DateTime? createdAt,
    DateTime? updatedAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'userId': userId,
      'passwordHash': passwordHash,
      'createdAt': createdAt.toJson(),
      'updatedAt': updatedAt.toJson(),
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _DwUserPasswordImpl extends DwUserPassword {
  _DwUserPasswordImpl({
    int? id,
    required int userId,
    required String passwordHash,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) : super._(
          id: id,
          userId: userId,
          passwordHash: passwordHash,
          createdAt: createdAt,
          updatedAt: updatedAt,
        );

  /// Returns a shallow copy of this [DwUserPassword]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  DwUserPassword copyWith({
    Object? id = _Undefined,
    int? userId,
    String? passwordHash,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DwUserPassword(
      id: id is int? ? id : this.id,
      userId: userId ?? this.userId,
      passwordHash: passwordHash ?? this.passwordHash,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
