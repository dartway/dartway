import 'package:dartway_core_shared/dartway_core_shared.dart';

part 'club_booking.dw.dart';

enum BookingStatus { booked, cancelled }

/// Hand-written in the exact shape `dartway generate` produces, so the core's
/// contract with generated code is exercised without the generator.
final class ClubBooking extends DwDataObject with _$ClubBooking {
  const ClubBooking({
    required this.id,
    required this.status,
    required this.startsAt,
    this.note,
    this.tags = const [],
  });

  @override
  final int id;
  final BookingStatus status;
  final DateTime startsAt;
  final String? note;
  final List<String> tags;
}

final class ListMyBookings extends DwListRequest<ClubBooking>
    with _$ListMyBookings {
  const ListMyBookings({this.status});

  final BookingStatus? status;

  @override
  bool matches(ClubBooking item) => status == null || item.status == status;
}

final class RenameBooking extends DwActionCommand<ClubBooking>
    with _$RenameBooking {
  const RenameBooking({
    required this.bookingId,
    this.note = const DwFieldPatch.keep(),
  });

  final int bookingId;
  final DwFieldPatch<String> note;
}
