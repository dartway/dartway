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

enum DwAuthProvider implements _i1.SerializableModel {
  email,
  phone,
  google,
  apple,
  telegram,
  other;

  static DwAuthProvider fromJson(String name) {
    switch (name) {
      case 'email':
        return DwAuthProvider.email;
      case 'phone':
        return DwAuthProvider.phone;
      case 'google':
        return DwAuthProvider.google;
      case 'apple':
        return DwAuthProvider.apple;
      case 'telegram':
        return DwAuthProvider.telegram;
      case 'other':
        return DwAuthProvider.other;
      default:
        throw ArgumentError(
            'Value "$name" cannot be converted to "DwAuthProvider"');
    }
  }

  @override
  String toJson() => name;

  @override
  String toString() => name;
}
