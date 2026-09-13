import 'package:dartway_core/dartway_core.dart';

part 'booking_view.dw.dart';

enum BookingStatus { booked, cancelled }

/// Hand-written in the exact shape `dartway generate` produces, so the core's
/// contract with generated code is exercised without the generator.
final class BookingView extends DwDataObject with _$BookingView {
  const BookingView({
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

final class ListMyBookings extends DwListRequest<BookingView>
    with _$ListMyBookings {
  const ListMyBookings({this.status});

  final BookingStatus? status;

  @override
  bool matches(BookingView object) => status == null || object.status == status;
}

final class RenameBooking extends DwCommand<BookingView> with _$RenameBooking {
  const RenameBooking({required this.bookingId, this.note = const DwPatch.keep()});

  final int bookingId;
  final DwPatch<String> note;
}
