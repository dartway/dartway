import 'dart:convert';

import 'package:dartway_core/dartway_core.dart';
import 'package:test/test.dart';

import 'fixtures/booking_view.dart';

final protocol = DwProtocol([
  DwDtoEntry(BookingView, 'BookingView', $BookingViewFromJson),
  DwDtoEntry(ListMyBookings, 'ListMyBookings', $ListMyBookingsFromJson),
  DwDtoEntry(RenameBooking, 'RenameBooking', $RenameBookingFromJson),
], include: DwProtocol.core);

Object? roundTrip(Object? json) => jsonDecode(jsonEncode(json));

void main() {
  final view = BookingView(
    id: 7,
    status: BookingStatus.booked,
    startsAt: DateTime.utc(2026, 9, 14, 10, 30),
    tags: const ['yoga'],
  );

  group('generated-shape DTO', () {
    test('omits absent optional fields and round-trips', () {
      final json = view.toJson();
      expect(json.containsKey('note'), isFalse);
      final back = protocol.decodeAs<BookingView>(roundTrip(json));
      expect(back, view);
      expect(back.hashCode, view.hashCode);
    });

    test('a request is a value: equal fields are an equal state key', () {
      expect(
        const ListMyBookings(status: BookingStatus.booked),
        const ListMyBookings(status: BookingStatus.booked),
      );
      expect(
        const ListMyBookings(),
        isNot(const ListMyBookings(status: BookingStatus.booked)),
      );
    });

    test('a patch distinguishes keep, set and clear on the wire', () {
      Map<String, Object?> wire(DwPatch<String> p) =>
          roundTrip(protocol.encodeTagged(RenameBooking(bookingId: 1, note: p)))
              as Map<String, Object?>;

      expect(wire(const DwPatch.keep()).containsKey('note'), isFalse);
      expect(wire(const DwPatch.clear())['note'], isNull);
      expect(wire(const DwPatch.clear()).containsKey('note'), isTrue);

      for (final patch in const [
        DwPatch<String>.keep(),
        DwPatch<String>.set('late'),
        DwPatch<String>.clear(),
      ]) {
        final decoded =
            protocol.decodeTagged(wire(patch)) as RenameBooking;
        expect(decoded.note, patch);
      }
    });
  });

  group('results', () {
    test('a list request encodes untagged and decodes typed', () {
      const request = ListMyBookings();
      final encoded = roundTrip(request.encodeResult([view], protocol));
      final decoded = request.decodeResult(encoded, protocol);
      expect(decoded, isA<List<BookingView>>());
      expect(decoded.single, view);
    });

    test('a command result is tagged and decodes to its type', () {
      const command = RenameBooking(bookingId: 7);
      final encoded = roundTrip(command.encodeResult(view, protocol));
      expect(command.decodeResult(encoded, protocol), view);
    });

    test('a refusal carries a code and string params, never a sentence', () {
      final refusal = DwRefusal(
        DwCoreRefusal.invalid,
        params: {'max': 5, 'skip': null},
        field: 'rating',
      );
      final back = DwRefusal.fromJson(
        roundTrip(refusal.toJson())! as Map<String, Object?>,
      );
      expect(back, refusal);
      expect(back.code, 'dw.invalid');
      expect(back.params, {'max': '5'});
      expect(back.isCode(DwCoreRefusal.invalid), isTrue);
    });
  });

  group('wire', () {
    test('client messages round-trip', () {
      final messages = <DwClientMessage>[
        const DwAuthenticateMessage('token'),
        const DwAuthenticateMessage(null),
        const DwRequestMessage(id: 1, request: ListMyBookings()),
        const DwRequestMessage(
          id: 2,
          request: ListMyBookings(),
          page: DwCursorParams(40),
        ),
        const DwCommandMessage(
          id: 3,
          idempotencyKey: 'k',
          command: RenameBooking(bookingId: 7, note: DwPatch.set('x')),
        ),
        const DwSubscribeMessage('chat:7'),
        const DwUnsubscribeMessage('chat:7'),
      ];
      for (final message in messages) {
        final back = DwClientMessage.fromJson(
          roundTrip(message.toJson(protocol))! as Map<String, Object?>,
          protocol,
        );
        expect(back.toJson(protocol), message.toJson(protocol));
      }
    });

    test('an update carries data objects and deletions tagged', () {
      final message = DwUpdateMessage(
        channel: 'myBookings:3',
        items: [view, DwDeleted.of<BookingView>(8, protocol)],
      );
      final back =
          DwServerMessage.fromJson(
                roundTrip(message.toJson(protocol))! as Map<String, Object?>,
                protocol,
              )
              as DwUpdateMessage;
      expect(back.items.first, view);
      final deleted = back.items.last as DwDeleted;
      expect(deleted.isOf<BookingView>(protocol), isTrue);
      expect(deleted.id, 8);
    });

    test('two classes under one wire name are refused at registration', () {
      expect(
        () => DwProtocol([
          DwDtoEntry(BookingView, 'Same', $BookingViewFromJson),
          DwDtoEntry(ListMyBookings, 'Same', $ListMyBookingsFromJson),
        ]),
        throwsStateError,
      );
    });
  });

  test('channel wire names', () {
    expect(dwParseChannelName('chat:7'), (kind: 'chat', key: '7'));
    expect(dwParseChannelName('news'), (kind: 'news', key: null));
  });
}
