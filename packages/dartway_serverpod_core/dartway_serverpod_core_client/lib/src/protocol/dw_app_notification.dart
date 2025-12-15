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

abstract class DwAppNotification implements _i1.SerializableModel {
  DwAppNotification._({
    this.id,
    required this.toUserId,
    this.identifier,
    DateTime? timestamp,
    required this.title,
    this.body,
    this.goToPath,
    bool? isRead,
  })  : timestamp = timestamp ?? DateTime.now(),
        isRead = isRead ?? false;

  factory DwAppNotification({
    int? id,
    required int toUserId,
    String? identifier,
    DateTime? timestamp,
    required String title,
    String? body,
    String? goToPath,
    bool? isRead,
  }) = _DwAppNotificationImpl;

  factory DwAppNotification.fromJson(Map<String, dynamic> jsonSerialization) {
    return DwAppNotification(
      id: jsonSerialization['id'] as int?,
      toUserId: jsonSerialization['toUserId'] as int,
      identifier: jsonSerialization['identifier'] as String?,
      timestamp:
          _i1.DateTimeJsonExtension.fromJson(jsonSerialization['timestamp']),
      title: jsonSerialization['title'] as String,
      body: jsonSerialization['body'] as String?,
      goToPath: jsonSerialization['goToPath'] as String?,
      isRead: jsonSerialization['isRead'] as bool,
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  int toUserId;

  String? identifier;

  DateTime timestamp;

  String title;

  String? body;

  String? goToPath;

  bool isRead;

  /// Returns a shallow copy of this [DwAppNotification]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  DwAppNotification copyWith({
    int? id,
    int? toUserId,
    String? identifier,
    DateTime? timestamp,
    String? title,
    String? body,
    String? goToPath,
    bool? isRead,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'toUserId': toUserId,
      if (identifier != null) 'identifier': identifier,
      'timestamp': timestamp.toJson(),
      'title': title,
      if (body != null) 'body': body,
      if (goToPath != null) 'goToPath': goToPath,
      'isRead': isRead,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _DwAppNotificationImpl extends DwAppNotification {
  _DwAppNotificationImpl({
    int? id,
    required int toUserId,
    String? identifier,
    DateTime? timestamp,
    required String title,
    String? body,
    String? goToPath,
    bool? isRead,
  }) : super._(
          id: id,
          toUserId: toUserId,
          identifier: identifier,
          timestamp: timestamp,
          title: title,
          body: body,
          goToPath: goToPath,
          isRead: isRead,
        );

  /// Returns a shallow copy of this [DwAppNotification]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  DwAppNotification copyWith({
    Object? id = _Undefined,
    int? toUserId,
    Object? identifier = _Undefined,
    DateTime? timestamp,
    String? title,
    Object? body = _Undefined,
    Object? goToPath = _Undefined,
    bool? isRead,
  }) {
    return DwAppNotification(
      id: id is int? ? id : this.id,
      toUserId: toUserId ?? this.toUserId,
      identifier: identifier is String? ? identifier : this.identifier,
      timestamp: timestamp ?? this.timestamp,
      title: title ?? this.title,
      body: body is String? ? body : this.body,
      goToPath: goToPath is String? ? goToPath : this.goToPath,
      isRead: isRead ?? this.isRead,
    );
  }
}
