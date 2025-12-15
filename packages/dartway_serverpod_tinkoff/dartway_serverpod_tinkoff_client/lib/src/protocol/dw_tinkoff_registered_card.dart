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

abstract class DwTinkoffRegisteredCard implements _i1.SerializableModel {
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

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  String tinkoffCustomerId;

  String cardPan;

  String status;

  String tinkoffCardId;

  String? rebillId;

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
