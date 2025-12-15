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
import 'dw_tinkoff_api_method.dart' as _i2;
import 'dw_tinkoff_log.dart' as _i3;
import 'dw_tinkoff_log_type.dart' as _i4;
import 'dw_tinkoff_payment.dart' as _i5;
import 'dw_tinkoff_payment_status.dart' as _i6;
import 'dw_tinkoff_registered_card.dart' as _i7;
export 'dw_tinkoff_api_method.dart';
export 'dw_tinkoff_log.dart';
export 'dw_tinkoff_log_type.dart';
export 'dw_tinkoff_payment.dart';
export 'dw_tinkoff_payment_status.dart';
export 'dw_tinkoff_registered_card.dart';
export 'client.dart';

class Protocol extends _i1.SerializationManager {
  Protocol._();

  factory Protocol() => _instance;

  static final Protocol _instance = Protocol._();

  @override
  T deserialize<T>(
    dynamic data, [
    Type? t,
  ]) {
    t ??= T;
    if (t == _i2.DwTinkoffApiMethod) {
      return _i2.DwTinkoffApiMethod.fromJson(data) as T;
    }
    if (t == _i3.DwTinkoffLog) {
      return _i3.DwTinkoffLog.fromJson(data) as T;
    }
    if (t == _i4.DwTinkoffLogType) {
      return _i4.DwTinkoffLogType.fromJson(data) as T;
    }
    if (t == _i5.DwTinkoffPayment) {
      return _i5.DwTinkoffPayment.fromJson(data) as T;
    }
    if (t == _i6.DwTinkoffPaymentStatus) {
      return _i6.DwTinkoffPaymentStatus.fromJson(data) as T;
    }
    if (t == _i7.DwTinkoffRegisteredCard) {
      return _i7.DwTinkoffRegisteredCard.fromJson(data) as T;
    }
    if (t == _i1.getType<_i2.DwTinkoffApiMethod?>()) {
      return (data != null ? _i2.DwTinkoffApiMethod.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i3.DwTinkoffLog?>()) {
      return (data != null ? _i3.DwTinkoffLog.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i4.DwTinkoffLogType?>()) {
      return (data != null ? _i4.DwTinkoffLogType.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i5.DwTinkoffPayment?>()) {
      return (data != null ? _i5.DwTinkoffPayment.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i6.DwTinkoffPaymentStatus?>()) {
      return (data != null ? _i6.DwTinkoffPaymentStatus.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i7.DwTinkoffRegisteredCard?>()) {
      return (data != null ? _i7.DwTinkoffRegisteredCard.fromJson(data) : null)
          as T;
    }
    return super.deserialize<T>(data, t);
  }

  @override
  String? getClassNameForObject(Object? data) {
    String? className = super.getClassNameForObject(data);
    if (className != null) return className;
    if (data is _i2.DwTinkoffApiMethod) {
      return 'DwTinkoffApiMethod';
    }
    if (data is _i3.DwTinkoffLog) {
      return 'DwTinkoffLog';
    }
    if (data is _i4.DwTinkoffLogType) {
      return 'DwTinkoffLogType';
    }
    if (data is _i5.DwTinkoffPayment) {
      return 'DwTinkoffPayment';
    }
    if (data is _i6.DwTinkoffPaymentStatus) {
      return 'DwTinkoffPaymentStatus';
    }
    if (data is _i7.DwTinkoffRegisteredCard) {
      return 'DwTinkoffRegisteredCard';
    }
    return null;
  }

  @override
  dynamic deserializeByClassName(Map<String, dynamic> data) {
    var dataClassName = data['className'];
    if (dataClassName is! String) {
      return super.deserializeByClassName(data);
    }
    if (dataClassName == 'DwTinkoffApiMethod') {
      return deserialize<_i2.DwTinkoffApiMethod>(data['data']);
    }
    if (dataClassName == 'DwTinkoffLog') {
      return deserialize<_i3.DwTinkoffLog>(data['data']);
    }
    if (dataClassName == 'DwTinkoffLogType') {
      return deserialize<_i4.DwTinkoffLogType>(data['data']);
    }
    if (dataClassName == 'DwTinkoffPayment') {
      return deserialize<_i5.DwTinkoffPayment>(data['data']);
    }
    if (dataClassName == 'DwTinkoffPaymentStatus') {
      return deserialize<_i6.DwTinkoffPaymentStatus>(data['data']);
    }
    if (dataClassName == 'DwTinkoffRegisteredCard') {
      return deserialize<_i7.DwTinkoffRegisteredCard>(data['data']);
    }
    return super.deserializeByClassName(data);
  }
}
