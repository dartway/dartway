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

enum DwTinkoffPaymentStatus implements _i1.SerializableModel {
  unknown,
  newPayment,
  formShowed,
  authorizing,
  authorized,
  confirming,
  confirmed,
  refunding,
  asyncRefunding,
  partialRefunded,
  refunded,
  canceled,
  deadlineExpired,
  attemptsExpired,
  rejected,
  authFail;

  static DwTinkoffPaymentStatus fromJson(String name) {
    switch (name) {
      case 'unknown':
        return DwTinkoffPaymentStatus.unknown;
      case 'newPayment':
        return DwTinkoffPaymentStatus.newPayment;
      case 'formShowed':
        return DwTinkoffPaymentStatus.formShowed;
      case 'authorizing':
        return DwTinkoffPaymentStatus.authorizing;
      case 'authorized':
        return DwTinkoffPaymentStatus.authorized;
      case 'confirming':
        return DwTinkoffPaymentStatus.confirming;
      case 'confirmed':
        return DwTinkoffPaymentStatus.confirmed;
      case 'refunding':
        return DwTinkoffPaymentStatus.refunding;
      case 'asyncRefunding':
        return DwTinkoffPaymentStatus.asyncRefunding;
      case 'partialRefunded':
        return DwTinkoffPaymentStatus.partialRefunded;
      case 'refunded':
        return DwTinkoffPaymentStatus.refunded;
      case 'canceled':
        return DwTinkoffPaymentStatus.canceled;
      case 'deadlineExpired':
        return DwTinkoffPaymentStatus.deadlineExpired;
      case 'attemptsExpired':
        return DwTinkoffPaymentStatus.attemptsExpired;
      case 'rejected':
        return DwTinkoffPaymentStatus.rejected;
      case 'authFail':
        return DwTinkoffPaymentStatus.authFail;
      default:
        throw ArgumentError(
            'Value "$name" cannot be converted to "DwTinkoffPaymentStatus"');
    }
  }

  @override
  String toJson() => name;

  @override
  String toString() => name;
}
