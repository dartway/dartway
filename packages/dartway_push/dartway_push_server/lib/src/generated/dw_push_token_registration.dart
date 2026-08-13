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

/// A device reporting its push token to the server, or handing it back.
///
/// Not a table: this is the request itself, handled by the module's CRUD DTO
/// action, which decides what to store. The recipient is never a field — it
/// comes from the authenticated session, so a caller cannot register a token
/// against somebody else's account.
abstract class DwPushTokenRegistration
    implements _i1.SerializableModel, _i1.ProtocolSerialization {
  DwPushTokenRegistration._({
    required this.token,
    this.provider,
    required this.revoke,
  });

  factory DwPushTokenRegistration({
    required String token,
    String? provider,
    required bool revoke,
  }) = _DwPushTokenRegistrationImpl;

  factory DwPushTokenRegistration.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return DwPushTokenRegistration(
      token: jsonSerialization['token'] as String,
      provider: jsonSerialization['provider'] as String?,
      revoke: _i1.BoolJsonExtension.fromJson(jsonSerialization['revoke']),
    );
  }

  String token;

  /// Which transport issued the token ('fcm', 'rustore', ...). Optional: a
  /// client that cannot tell leaves it out and the server probes once.
  String? provider;

  /// True when the device is giving the token back — sign-out, or a token the
  /// platform has replaced.
  bool revoke;

  /// Returns a shallow copy of this [DwPushTokenRegistration]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  DwPushTokenRegistration copyWith({
    String? token,
    String? provider,
    bool? revoke,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'dartway_push.DwPushTokenRegistration',
      'token': token,
      if (provider != null) 'provider': provider,
      'revoke': revoke,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'dartway_push.DwPushTokenRegistration',
      'token': token,
      if (provider != null) 'provider': provider,
      'revoke': revoke,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _DwPushTokenRegistrationImpl extends DwPushTokenRegistration {
  _DwPushTokenRegistrationImpl({
    required String token,
    String? provider,
    required bool revoke,
  }) : super._(
         token: token,
         provider: provider,
         revoke: revoke,
       );

  /// Returns a shallow copy of this [DwPushTokenRegistration]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  DwPushTokenRegistration copyWith({
    String? token,
    Object? provider = _Undefined,
    bool? revoke,
  }) {
    return DwPushTokenRegistration(
      token: token ?? this.token,
      provider: provider is String? ? provider : this.provider,
      revoke: revoke ?? this.revoke,
    );
  }
}
