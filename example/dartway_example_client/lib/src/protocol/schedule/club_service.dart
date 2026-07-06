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

abstract class ClubService implements _i1.SerializableModel {
  ClubService._({
    this.id,
    required this.title,
    required this.description,
    required this.durationMinutes,
    required this.price,
    this.imageUrl,
  });

  factory ClubService({
    int? id,
    required String title,
    required String description,
    required int durationMinutes,
    required int price,
    String? imageUrl,
  }) = _ClubServiceImpl;

  factory ClubService.fromJson(Map<String, dynamic> jsonSerialization) {
    return ClubService(
      id: jsonSerialization['id'] as int?,
      title: jsonSerialization['title'] as String,
      description: jsonSerialization['description'] as String,
      durationMinutes: jsonSerialization['durationMinutes'] as int,
      price: jsonSerialization['price'] as int,
      imageUrl: jsonSerialization['imageUrl'] as String?,
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  String title;

  String description;

  int durationMinutes;

  int price;

  String? imageUrl;

  /// Returns a shallow copy of this [ClubService]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  ClubService copyWith({
    int? id,
    String? title,
    String? description,
    int? durationMinutes,
    int? price,
    String? imageUrl,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'ClubService',
      if (id != null) 'id': id,
      'title': title,
      'description': description,
      'durationMinutes': durationMinutes,
      'price': price,
      if (imageUrl != null) 'imageUrl': imageUrl,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _ClubServiceImpl extends ClubService {
  _ClubServiceImpl({
    int? id,
    required String title,
    required String description,
    required int durationMinutes,
    required int price,
    String? imageUrl,
  }) : super._(
         id: id,
         title: title,
         description: description,
         durationMinutes: durationMinutes,
         price: price,
         imageUrl: imageUrl,
       );

  /// Returns a shallow copy of this [ClubService]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  ClubService copyWith({
    Object? id = _Undefined,
    String? title,
    String? description,
    int? durationMinutes,
    int? price,
    Object? imageUrl = _Undefined,
  }) {
    return ClubService(
      id: id is int? ? id : this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      price: price ?? this.price,
      imageUrl: imageUrl is String? ? imageUrl : this.imageUrl,
    );
  }
}
