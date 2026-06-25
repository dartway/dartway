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
import '../user_profile/user_profile.dart' as _i2;

abstract class FeedPost implements _i1.SerializableModel {
  FeedPost._({
    this.id,
    required this.authorProfileId,
    this.authorProfile,
    required this.title,
    required this.text,
    required this.createdAt,
  });

  factory FeedPost({
    int? id,
    required int authorProfileId,
    _i2.UserProfile? authorProfile,
    required String title,
    required String text,
    required DateTime createdAt,
  }) = _FeedPostImpl;

  factory FeedPost.fromJson(Map<String, dynamic> jsonSerialization) {
    return FeedPost(
      id: jsonSerialization['id'] as int?,
      authorProfileId: jsonSerialization['authorProfileId'] as int,
      authorProfile: jsonSerialization['authorProfile'] == null
          ? null
          : _i2.UserProfile.fromJson(
              (jsonSerialization['authorProfile'] as Map<String, dynamic>)),
      title: jsonSerialization['title'] as String,
      text: jsonSerialization['text'] as String,
      createdAt:
          _i1.DateTimeJsonExtension.fromJson(jsonSerialization['createdAt']),
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  int authorProfileId;

  _i2.UserProfile? authorProfile;

  String title;

  String text;

  DateTime createdAt;

  /// Returns a shallow copy of this [FeedPost]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  FeedPost copyWith({
    int? id,
    int? authorProfileId,
    _i2.UserProfile? authorProfile,
    String? title,
    String? text,
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'authorProfileId': authorProfileId,
      if (authorProfile != null) 'authorProfile': authorProfile?.toJson(),
      'title': title,
      'text': text,
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _FeedPostImpl extends FeedPost {
  _FeedPostImpl({
    int? id,
    required int authorProfileId,
    _i2.UserProfile? authorProfile,
    required String title,
    required String text,
    required DateTime createdAt,
  }) : super._(
          id: id,
          authorProfileId: authorProfileId,
          authorProfile: authorProfile,
          title: title,
          text: text,
          createdAt: createdAt,
        );

  /// Returns a shallow copy of this [FeedPost]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  FeedPost copyWith({
    Object? id = _Undefined,
    int? authorProfileId,
    Object? authorProfile = _Undefined,
    String? title,
    String? text,
    DateTime? createdAt,
  }) {
    return FeedPost(
      id: id is int? ? id : this.id,
      authorProfileId: authorProfileId ?? this.authorProfileId,
      authorProfile: authorProfile is _i2.UserProfile?
          ? authorProfile
          : this.authorProfile?.copyWith(),
      title: title ?? this.title,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
