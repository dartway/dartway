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
import '../schedule/club_session.dart' as _i2;
import '../user_profile/user_profile.dart' as _i3;
import '../booking/enums/booking_status.dart' as _i4;
import 'package:dartway_example_client/src/protocol/protocol.dart' as _i5;

abstract class SessionBooking implements _i1.SerializableModel {
  SessionBooking._({
    this.id,
    required this.sessionId,
    this.session,
    required this.clientProfileId,
    this.clientProfile,
    required this.status,
    required this.createdAt,
  });

  factory SessionBooking({
    int? id,
    required int sessionId,
    _i2.ClubSession? session,
    required int clientProfileId,
    _i3.UserProfile? clientProfile,
    required _i4.BookingStatus status,
    required DateTime createdAt,
  }) = _SessionBookingImpl;

  factory SessionBooking.fromJson(Map<String, dynamic> jsonSerialization) {
    return SessionBooking(
      id: jsonSerialization['id'] as int?,
      sessionId: jsonSerialization['sessionId'] as int,
      session: jsonSerialization['session'] == null
          ? null
          : _i5.Protocol().deserialize<_i2.ClubSession>(
              jsonSerialization['session'],
            ),
      clientProfileId: jsonSerialization['clientProfileId'] as int,
      clientProfile: jsonSerialization['clientProfile'] == null
          ? null
          : _i5.Protocol().deserialize<_i3.UserProfile>(
              jsonSerialization['clientProfile'],
            ),
      status: _i4.BookingStatus.fromJson(
        (jsonSerialization['status'] as String),
      ),
      createdAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  int sessionId;

  _i2.ClubSession? session;

  int clientProfileId;

  _i3.UserProfile? clientProfile;

  _i4.BookingStatus status;

  DateTime createdAt;

  /// Returns a shallow copy of this [SessionBooking]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  SessionBooking copyWith({
    int? id,
    int? sessionId,
    _i2.ClubSession? session,
    int? clientProfileId,
    _i3.UserProfile? clientProfile,
    _i4.BookingStatus? status,
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'SessionBooking',
      if (id != null) 'id': id,
      'sessionId': sessionId,
      if (session != null) 'session': session?.toJson(),
      'clientProfileId': clientProfileId,
      if (clientProfile != null) 'clientProfile': clientProfile?.toJson(),
      'status': status.toJson(),
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _SessionBookingImpl extends SessionBooking {
  _SessionBookingImpl({
    int? id,
    required int sessionId,
    _i2.ClubSession? session,
    required int clientProfileId,
    _i3.UserProfile? clientProfile,
    required _i4.BookingStatus status,
    required DateTime createdAt,
  }) : super._(
         id: id,
         sessionId: sessionId,
         session: session,
         clientProfileId: clientProfileId,
         clientProfile: clientProfile,
         status: status,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [SessionBooking]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  SessionBooking copyWith({
    Object? id = _Undefined,
    int? sessionId,
    Object? session = _Undefined,
    int? clientProfileId,
    Object? clientProfile = _Undefined,
    _i4.BookingStatus? status,
    DateTime? createdAt,
  }) {
    return SessionBooking(
      id: id is int? ? id : this.id,
      sessionId: sessionId ?? this.sessionId,
      session: session is _i2.ClubSession? ? session : this.session?.copyWith(),
      clientProfileId: clientProfileId ?? this.clientProfileId,
      clientProfile: clientProfile is _i3.UserProfile?
          ? clientProfile
          : this.clientProfile?.copyWith(),
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
