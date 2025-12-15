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

/// Provides a method of access for a user to authenticate with the server.
abstract class DwAuthKey implements _i1.SerializableModel {
  DwAuthKey._({
    this.id,
    required this.userId,
    required this.hash,
    this.key,
  });

  factory DwAuthKey({
    int? id,
    required int userId,
    required String hash,
    String? key,
  }) = _DwAuthKeyImpl;

  factory DwAuthKey.fromJson(Map<String, dynamic> jsonSerialization) {
    return DwAuthKey(
      id: jsonSerialization['id'] as int?,
      userId: jsonSerialization['userId'] as int,
      hash: jsonSerialization['hash'] as String,
      key: jsonSerialization['key'] as String?,
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  /// The id of the user to provide access to.
  int userId;

  /// The hashed version of the key.
  String hash;

  /// The key sent to the server to authenticate.
  String? key;

  /// Returns a shallow copy of this [DwAuthKey]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  DwAuthKey copyWith({
    int? id,
    int? userId,
    String? hash,
    String? key,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'userId': userId,
      'hash': hash,
      if (key != null) 'key': key,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _DwAuthKeyImpl extends DwAuthKey {
  _DwAuthKeyImpl({
    int? id,
    required int userId,
    required String hash,
    String? key,
  }) : super._(
          id: id,
          userId: userId,
          hash: hash,
          key: key,
        );

  /// Returns a shallow copy of this [DwAuthKey]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  DwAuthKey copyWith({
    Object? id = _Undefined,
    int? userId,
    String? hash,
    Object? key = _Undefined,
  }) {
    return DwAuthKey(
      id: id is int? ? id : this.id,
      userId: userId ?? this.userId,
      hash: hash ?? this.hash,
      key: key is String? ? key : this.key,
    );
  }
}
