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
import 'package:serverpod_client/serverpod_client.dart' as _i1;

abstract class ChatChannel implements _i1.SerializableModel {
  ChatChannel._({
    this.id,
    required this.title,
    required this.createdAt,
  });

  factory ChatChannel({
    int? id,
    required String title,
    required DateTime createdAt,
  }) = _ChatChannelImpl;

  factory ChatChannel.fromJson(Map<String, dynamic> jsonSerialization) {
    return ChatChannel(
      id: jsonSerialization['id'] as int?,
      title: jsonSerialization['title'] as String,
      createdAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  String title;

  DateTime createdAt;

  /// Returns a shallow copy of this [ChatChannel]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  ChatChannel copyWith({
    int? id,
    String? title,
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'ChatChannel',
      if (id != null) 'id': id,
      'title': title,
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _ChatChannelImpl extends ChatChannel {
  _ChatChannelImpl({
    int? id,
    required String title,
    required DateTime createdAt,
  }) : super._(
         id: id,
         title: title,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [ChatChannel]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  ChatChannel copyWith({
    Object? id = _Undefined,
    String? title,
    DateTime? createdAt,
  }) {
    return ChatChannel(
      id: id is int? ? id : this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
