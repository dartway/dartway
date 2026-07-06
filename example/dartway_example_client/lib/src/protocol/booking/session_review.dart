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
import '../booking/session_booking.dart' as _i2;
import 'package:dartway_example_client/src/protocol/protocol.dart' as _i3;

abstract class SessionReview implements _i1.SerializableModel {
  SessionReview._({
    this.id,
    required this.bookingId,
    this.booking,
    required this.rating,
    this.reviewText,
    required this.createdAt,
  });

  factory SessionReview({
    int? id,
    required int bookingId,
    _i2.SessionBooking? booking,
    required int rating,
    String? reviewText,
    required DateTime createdAt,
  }) = _SessionReviewImpl;

  factory SessionReview.fromJson(Map<String, dynamic> jsonSerialization) {
    return SessionReview(
      id: jsonSerialization['id'] as int?,
      bookingId: jsonSerialization['bookingId'] as int,
      booking: jsonSerialization['booking'] == null
          ? null
          : _i3.Protocol().deserialize<_i2.SessionBooking>(
              jsonSerialization['booking'],
            ),
      rating: jsonSerialization['rating'] as int,
      reviewText: jsonSerialization['reviewText'] as String?,
      createdAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  int bookingId;

  _i2.SessionBooking? booking;

  int rating;

  String? reviewText;

  DateTime createdAt;

  /// Returns a shallow copy of this [SessionReview]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  SessionReview copyWith({
    int? id,
    int? bookingId,
    _i2.SessionBooking? booking,
    int? rating,
    String? reviewText,
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'SessionReview',
      if (id != null) 'id': id,
      'bookingId': bookingId,
      if (booking != null) 'booking': booking?.toJson(),
      'rating': rating,
      if (reviewText != null) 'reviewText': reviewText,
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _SessionReviewImpl extends SessionReview {
  _SessionReviewImpl({
    int? id,
    required int bookingId,
    _i2.SessionBooking? booking,
    required int rating,
    String? reviewText,
    required DateTime createdAt,
  }) : super._(
         id: id,
         bookingId: bookingId,
         booking: booking,
         rating: rating,
         reviewText: reviewText,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [SessionReview]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  SessionReview copyWith({
    Object? id = _Undefined,
    int? bookingId,
    Object? booking = _Undefined,
    int? rating,
    Object? reviewText = _Undefined,
    DateTime? createdAt,
  }) {
    return SessionReview(
      id: id is int? ? id : this.id,
      bookingId: bookingId ?? this.bookingId,
      booking: booking is _i2.SessionBooking?
          ? booking
          : this.booking?.copyWith(),
      rating: rating ?? this.rating,
      reviewText: reviewText is String? ? reviewText : this.reviewText,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
