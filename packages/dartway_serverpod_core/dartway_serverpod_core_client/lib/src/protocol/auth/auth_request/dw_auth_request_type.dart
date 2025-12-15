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

enum DwAuthRequestType implements _i1.SerializableModel {
  login,
  register,
  changePassword,
  changeIdentifier,
  addAuthProvider,
  removeAuthProvider,
  custom;

  static DwAuthRequestType fromJson(String name) {
    switch (name) {
      case 'login':
        return DwAuthRequestType.login;
      case 'register':
        return DwAuthRequestType.register;
      case 'changePassword':
        return DwAuthRequestType.changePassword;
      case 'changeIdentifier':
        return DwAuthRequestType.changeIdentifier;
      case 'addAuthProvider':
        return DwAuthRequestType.addAuthProvider;
      case 'removeAuthProvider':
        return DwAuthRequestType.removeAuthProvider;
      case 'custom':
        return DwAuthRequestType.custom;
      default:
        throw ArgumentError(
            'Value "$name" cannot be converted to "DwAuthRequestType"');
    }
  }

  @override
  String toJson() => name;

  @override
  String toString() => name;
}
