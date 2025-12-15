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
import 'dw_tinkoff_payment_status.dart' as _i2;

abstract class DwTinkoffPayment implements _i1.SerializableModel {
  DwTinkoffPayment._({
    this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.terminalKey,
    required this.tinkoffRawStatus,
    required this.tinkoffStatus,
    required this.tinkoffPaymentId,
    required this.tinkoffCustomerId,
    required this.orderIdentifier,
    required this.amount,
    required this.paymentUrl,
  });

  factory DwTinkoffPayment({
    int? id,
    required DateTime createdAt,
    required DateTime updatedAt,
    required String terminalKey,
    required String tinkoffRawStatus,
    required _i2.DwTinkoffPaymentStatus tinkoffStatus,
    required String tinkoffPaymentId,
    required String tinkoffCustomerId,
    required String orderIdentifier,
    required int amount,
    required String paymentUrl,
  }) = _DwTinkoffPaymentImpl;

  factory DwTinkoffPayment.fromJson(Map<String, dynamic> jsonSerialization) {
    return DwTinkoffPayment(
      id: jsonSerialization['id'] as int?,
      createdAt:
          _i1.DateTimeJsonExtension.fromJson(jsonSerialization['createdAt']),
      updatedAt:
          _i1.DateTimeJsonExtension.fromJson(jsonSerialization['updatedAt']),
      terminalKey: jsonSerialization['terminalKey'] as String,
      tinkoffRawStatus: jsonSerialization['tinkoffRawStatus'] as String,
      tinkoffStatus: _i2.DwTinkoffPaymentStatus.fromJson(
          (jsonSerialization['tinkoffStatus'] as String)),
      tinkoffPaymentId: jsonSerialization['tinkoffPaymentId'] as String,
      tinkoffCustomerId: jsonSerialization['tinkoffCustomerId'] as String,
      orderIdentifier: jsonSerialization['orderIdentifier'] as String,
      amount: jsonSerialization['amount'] as int,
      paymentUrl: jsonSerialization['paymentUrl'] as String,
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  DateTime createdAt;

  DateTime updatedAt;

  String terminalKey;

  String tinkoffRawStatus;

  _i2.DwTinkoffPaymentStatus tinkoffStatus;

  String tinkoffPaymentId;

  String tinkoffCustomerId;

  String orderIdentifier;

  int amount;

  String paymentUrl;

  /// Returns a shallow copy of this [DwTinkoffPayment]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  DwTinkoffPayment copyWith({
    int? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? terminalKey,
    String? tinkoffRawStatus,
    _i2.DwTinkoffPaymentStatus? tinkoffStatus,
    String? tinkoffPaymentId,
    String? tinkoffCustomerId,
    String? orderIdentifier,
    int? amount,
    String? paymentUrl,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'createdAt': createdAt.toJson(),
      'updatedAt': updatedAt.toJson(),
      'terminalKey': terminalKey,
      'tinkoffRawStatus': tinkoffRawStatus,
      'tinkoffStatus': tinkoffStatus.toJson(),
      'tinkoffPaymentId': tinkoffPaymentId,
      'tinkoffCustomerId': tinkoffCustomerId,
      'orderIdentifier': orderIdentifier,
      'amount': amount,
      'paymentUrl': paymentUrl,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _DwTinkoffPaymentImpl extends DwTinkoffPayment {
  _DwTinkoffPaymentImpl({
    int? id,
    required DateTime createdAt,
    required DateTime updatedAt,
    required String terminalKey,
    required String tinkoffRawStatus,
    required _i2.DwTinkoffPaymentStatus tinkoffStatus,
    required String tinkoffPaymentId,
    required String tinkoffCustomerId,
    required String orderIdentifier,
    required int amount,
    required String paymentUrl,
  }) : super._(
          id: id,
          createdAt: createdAt,
          updatedAt: updatedAt,
          terminalKey: terminalKey,
          tinkoffRawStatus: tinkoffRawStatus,
          tinkoffStatus: tinkoffStatus,
          tinkoffPaymentId: tinkoffPaymentId,
          tinkoffCustomerId: tinkoffCustomerId,
          orderIdentifier: orderIdentifier,
          amount: amount,
          paymentUrl: paymentUrl,
        );

  /// Returns a shallow copy of this [DwTinkoffPayment]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  DwTinkoffPayment copyWith({
    Object? id = _Undefined,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? terminalKey,
    String? tinkoffRawStatus,
    _i2.DwTinkoffPaymentStatus? tinkoffStatus,
    String? tinkoffPaymentId,
    String? tinkoffCustomerId,
    String? orderIdentifier,
    int? amount,
    String? paymentUrl,
  }) {
    return DwTinkoffPayment(
      id: id is int? ? id : this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      terminalKey: terminalKey ?? this.terminalKey,
      tinkoffRawStatus: tinkoffRawStatus ?? this.tinkoffRawStatus,
      tinkoffStatus: tinkoffStatus ?? this.tinkoffStatus,
      tinkoffPaymentId: tinkoffPaymentId ?? this.tinkoffPaymentId,
      tinkoffCustomerId: tinkoffCustomerId ?? this.tinkoffCustomerId,
      orderIdentifier: orderIdentifier ?? this.orderIdentifier,
      amount: amount ?? this.amount,
      paymentUrl: paymentUrl ?? this.paymentUrl,
    );
  }
}
