import 'dart:convert';

import 'package:dartway_core_shared/dartway_core_shared.dart';

import '../fixtures/club_booking.dart';

export '../fixtures/club_booking.dart';

/// The fixture DTOs plus hand-written request kinds, as a project registry.
final protocol = DwWireProtocol([
  const DwProtocolEntry<ClubBooking>('ClubBooking', $ClubBookingFromJson),
  const DwProtocolEntry<ListMyBookings>(
    'ListMyBookings',
    $ListMyBookingsFromJson,
  ),
  const DwProtocolEntry<RenameBooking>('RenameBooking', $RenameBookingFromJson),
  DwProtocolEntry<CoachNote>('CoachNote', CoachNote.fromJson),
], include: DwWireProtocol.core);

/// Through real JSON text, as the wire carries it.
Object? roundTrip(Object? json) => jsonDecode(jsonEncode(json));

final booking = ClubBooking(
  id: 7,
  status: BookingStatus.booked,
  startsAt: DateTime.utc(2026, 9, 14, 10, 30),
  tags: const ['yoga'],
);

ClubBooking bookingWith(
  int id, {
  BookingStatus status = BookingStatus.booked,
}) => ClubBooking(id: id, status: status, startsAt: DateTime.utc(2026, 9, 14));

/// A second data object type, for the "not the item type" cases.
final class CoachNote extends DwDataObject {
  const CoachNote(this.id);

  static CoachNote fromJson(Map<String, Object?> json) =>
      CoachNote(json['id']! as int);

  @override
  final int id;

  @override
  String get dwTypeName => 'CoachNote';

  @override
  Map<String, Object?> toJson() => {'id': id};

  @override
  bool operator ==(Object other) => other is CoachNote && other.id == id;

  @override
  int get hashCode => id;
}

// One request of every kind, hand-written (no generated mixin needed for the
// kind contract).

abstract final class _NoFields {
  static const Map<String, Object?> json = {};
}

final class GetBooking extends DwSingleRequest<ClubBooking> {
  const GetBooking();

  @override
  String get dwTypeName => 'GetBooking';

  @override
  Map<String, Object?> toJson() => _NoFields.json;
}

final class FindBooking extends DwMaybeRequest<ClubBooking> {
  const FindBooking(this.bookingId);

  final int bookingId;

  @override
  bool matches(ClubBooking item) => item.id == bookingId;

  @override
  String get dwTypeName => 'FindBooking';

  @override
  Map<String, Object?> toJson() => {'bookingId': bookingId};
}

final class ListBookedOnly extends DwListRequest<ClubBooking> {
  const ListBookedOnly();

  @override
  bool matches(ClubBooking item) => item.status == BookingStatus.booked;

  @override
  String get dwTypeName => 'ListBookedOnly';

  @override
  Map<String, Object?> toJson() => _NoFields.json;
}

final class ListBookingsUpdateOnly extends DwListRequest<ClubBooking> {
  const ListBookingsUpdateOnly() : super.updateOnly();

  @override
  String get dwTypeName => 'ListBookingsUpdateOnly';

  @override
  Map<String, Object?> toJson() => _NoFields.json;
}

final class ListBookingStats extends DwListRequest<ClubBooking> {
  const ListBookingStats() : super.refetchOnUpdate();

  @override
  String get dwTypeName => 'ListBookingStats';

  @override
  Map<String, Object?> toJson() => _NoFields.json;
}

final class FeedBookings extends DwPageRequest<ClubBooking> {
  const FeedBookings() : super(pageSize: 20, maxPageSize: 100);

  @override
  String get dwTypeName => 'FeedBookings';

  @override
  Map<String, Object?> toJson() => _NoFields.json;
}

final class FeedBookingsUpdateOnly extends DwPageRequest<ClubBooking> {
  const FeedBookingsUpdateOnly() : super.updateOnly(pageSize: 10);

  @override
  String get dwTypeName => 'FeedBookingsUpdateOnly';

  @override
  Map<String, Object?> toJson() => _NoFields.json;
}

final class ListBookingTable extends DwTableRequest<ClubBooking> {
  const ListBookingTable({this.page = 1, this.pageSize = 20})
    : super(maxPageSize: 50);

  @override
  final int page;

  @override
  final int pageSize;

  @override
  String get dwTypeName => 'ListBookingTable';

  @override
  Map<String, Object?> toJson() => {'page': page, 'pageSize': pageSize};
}

final class BookingHistory extends DwWindowRequest<ClubBooking, DateTime, int> {
  const BookingHistory() : super(pageSize: 30);

  @override
  DwWindowPosition<DateTime, int> positionOf(ClubBooking item) =>
      (sortValue: item.startsAt, id: item.id);

  @override
  bool matches(ClubBooking item) => item.status == BookingStatus.booked;

  @override
  String get dwTypeName => 'BookingHistory';

  @override
  Map<String, Object?> toJson() => _NoFields.json;
}
