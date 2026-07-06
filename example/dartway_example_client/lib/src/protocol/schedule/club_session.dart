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
import '../schedule/club_service.dart' as _i2;
import '../user_profile/user_profile.dart' as _i3;
import 'package:dartway_example_client/src/protocol/protocol.dart' as _i4;

abstract class ClubSession implements _i1.SerializableModel {
  ClubSession._({
    this.id,
    required this.serviceId,
    this.service,
    required this.coachProfileId,
    this.coachProfile,
    required this.startsAt,
    required this.capacity,
  });

  factory ClubSession({
    int? id,
    required int serviceId,
    _i2.ClubService? service,
    required int coachProfileId,
    _i3.UserProfile? coachProfile,
    required DateTime startsAt,
    required int capacity,
  }) = _ClubSessionImpl;

  factory ClubSession.fromJson(Map<String, dynamic> jsonSerialization) {
    return ClubSession(
      id: jsonSerialization['id'] as int?,
      serviceId: jsonSerialization['serviceId'] as int,
      service: jsonSerialization['service'] == null
          ? null
          : _i4.Protocol().deserialize<_i2.ClubService>(
              jsonSerialization['service'],
            ),
      coachProfileId: jsonSerialization['coachProfileId'] as int,
      coachProfile: jsonSerialization['coachProfile'] == null
          ? null
          : _i4.Protocol().deserialize<_i3.UserProfile>(
              jsonSerialization['coachProfile'],
            ),
      startsAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['startsAt'],
      ),
      capacity: jsonSerialization['capacity'] as int,
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  int serviceId;

  _i2.ClubService? service;

  int coachProfileId;

  _i3.UserProfile? coachProfile;

  DateTime startsAt;

  int capacity;

  /// Returns a shallow copy of this [ClubSession]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  ClubSession copyWith({
    int? id,
    int? serviceId,
    _i2.ClubService? service,
    int? coachProfileId,
    _i3.UserProfile? coachProfile,
    DateTime? startsAt,
    int? capacity,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'ClubSession',
      if (id != null) 'id': id,
      'serviceId': serviceId,
      if (service != null) 'service': service?.toJson(),
      'coachProfileId': coachProfileId,
      if (coachProfile != null) 'coachProfile': coachProfile?.toJson(),
      'startsAt': startsAt.toJson(),
      'capacity': capacity,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _ClubSessionImpl extends ClubSession {
  _ClubSessionImpl({
    int? id,
    required int serviceId,
    _i2.ClubService? service,
    required int coachProfileId,
    _i3.UserProfile? coachProfile,
    required DateTime startsAt,
    required int capacity,
  }) : super._(
         id: id,
         serviceId: serviceId,
         service: service,
         coachProfileId: coachProfileId,
         coachProfile: coachProfile,
         startsAt: startsAt,
         capacity: capacity,
       );

  /// Returns a shallow copy of this [ClubSession]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  ClubSession copyWith({
    Object? id = _Undefined,
    int? serviceId,
    Object? service = _Undefined,
    int? coachProfileId,
    Object? coachProfile = _Undefined,
    DateTime? startsAt,
    int? capacity,
  }) {
    return ClubSession(
      id: id is int? ? id : this.id,
      serviceId: serviceId ?? this.serviceId,
      service: service is _i2.ClubService? ? service : this.service?.copyWith(),
      coachProfileId: coachProfileId ?? this.coachProfileId,
      coachProfile: coachProfile is _i3.UserProfile?
          ? coachProfile
          : this.coachProfile?.copyWith(),
      startsAt: startsAt ?? this.startsAt,
      capacity: capacity ?? this.capacity,
    );
  }
}
