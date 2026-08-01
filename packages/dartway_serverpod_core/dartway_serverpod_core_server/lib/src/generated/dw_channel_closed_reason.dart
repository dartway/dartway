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
import 'package:serverpod/serverpod.dart' as _i1;

/// Why the server ended a channel subscription. Serialized by name so a reason
/// added later cannot renumber the ones already on the wire.
enum DwChannelClosedReason implements _i1.SerializableModel {
  /// No declaration covers the channel, or the caller is not in its audience.
  /// Asking again with the same session will be refused again.
  notAllowed,

  /// The caller's authentication was revoked while it was listening — the
  /// account was deleted, banned or signed out everywhere.
  authenticationRevoked;

  static DwChannelClosedReason fromJson(String name) {
    switch (name) {
      case 'notAllowed':
        return DwChannelClosedReason.notAllowed;
      case 'authenticationRevoked':
        return DwChannelClosedReason.authenticationRevoked;
      default:
        throw ArgumentError(
          'Value "$name" cannot be converted to "DwChannelClosedReason"',
        );
    }
  }

  @override
  String toJson() => name;

  @override
  String toString() => name;
}
