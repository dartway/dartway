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
        final decoded = protocol.decodeTagged(wire(patch)) as RenameBooking;
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

    test('a subscription refusal is refused, unauthenticated or failed', () {
      DwSubscriptionRefusedMessage back(DwSubscriptionRefusedMessage message) =>
          DwServerMessage.fromJson(
                roundTrip(message.toJson(protocol))! as Map<String, Object?>,
                protocol,
              )
              as DwSubscriptionRefusedMessage;

      final refused = back(
        DwSubscriptionRefusedMessage.refused(
          'chat:7',
          DwRefusal(DwCoreRefusal.forbidden),
        ),
      );
      expect(refused.refusal, DwRefusal(DwCoreRefusal.forbidden));
      expect(refused.incidentId, isNull);
      expect(refused.isUnauthenticated, isFalse);

      final anonymous = back(
        const DwSubscriptionRefusedMessage.unauthenticated('chat:7'),
      );
      expect(anonymous.isUnauthenticated, isTrue);

      final failed = back(
        const DwSubscriptionRefusedMessage.failed('chat:7', 'inc-1'),
      );
      expect(failed.incidentId, 'inc-1');
      expect(failed.refusal, isNull);
      expect(failed.isUnauthenticated, isFalse);

      expect(
        () => DwServerMessage.fromJson({
          'k': 'subno',
          'ch': 'chat:7',
          'r': {'code': 'dw.forbidden'},
          'x': 'inc-1',
        }, protocol),
        throwsFormatException,
      );
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

  group('refusal codes', () {
    test('tooManyRequests carries whole seconds, rounded up, at least one', () {
      final refusal = DwRefusal.tooManyRequests(
        const Duration(milliseconds: 2001),
      );
      expect(refusal.code, 'dw.tooManyRequests');
      expect(refusal.params, {'retryAfter': '3'});
      final back = DwRefusal.fromJson(
        roundTrip(refusal.toJson())! as Map<String, Object?>,
      );
      expect(back.retryAfter, const Duration(seconds: 3));
      expect(
        DwRefusal.tooManyRequests(Duration.zero).retryAfter,
        const Duration(seconds: 1),
      );
    });

    test('retryAfter belongs to tooManyRequests only', () {
      expect(
        DwRefusal(DwCoreRefusal.invalid, params: {'retryAfter': 5}).retryAfter,
        isNull,
      );
      expect(
        DwRefusal(DwCoreRefusal.codeExpired, field: 'code').code,
        'dw.codeExpired',
      );
    });
  });

  group('validation', () {
    test('a validatable DTO answers its refusals', () {
      expect(const _Rating(3).validate(), isEmpty);
      expect(const _Rating(9).validate(), [
        DwRefusal(DwCoreRefusal.invalid, field: 'stars', params: {'max': 5}),
      ]);
    });
  });

  group('protocol enumeration', () {
    test('every entry is listed once with its kind, core entries first', () {
      final kinds = {
        for (final entry in protocol.entries) entry.name: entry.kind,
      };
      expect(protocol.entries.map((e) => e.name), [
        'DwDeleted',
        'DwRequestCode',
        'DwCodeTicket',
        'DwVerifyCode',
        'DwSession',
        'DwSignOut',
        'BookingView',
        'ListMyBookings',
        'RenameBooking',
      ]);
      expect(kinds, {
        'DwDeleted': DwDtoKind.other,
        'DwRequestCode': DwDtoKind.command,
        'DwCodeTicket': DwDtoKind.dataObject,
        'DwVerifyCode': DwDtoKind.command,
        'DwSession': DwDtoKind.dataObject,
        'DwSignOut': DwDtoKind.command,
        'BookingView': DwDtoKind.dataObject,
        'ListMyBookings': DwDtoKind.request,
        'RenameBooking': DwDtoKind.command,
      });
    });

    test('a kind is read from the factory of every request kind', () {
      final entries = [
        DwDtoEntry(_One, '_One', (json) => const _One()),
        DwDtoEntry(_Maybe, '_Maybe', (json) => const _Maybe()),
        DwDtoEntry(_Pages, '_Pages', (json) => const _Pages()),
        DwDtoEntry(_Older, '_Older', (json) => const _Older()),
      ];
      expect(entries.map((e) => e.kind), everyElement(DwDtoKind.request));
    });
  });

  group('acceptsItem', () {
    final other = _Other();
    test('each request kind accepts exactly its item type', () {
      for (final request in <DwRequest<Object?>>[
        const ListMyBookings(),
        const _One(),
        const _Maybe(),
        const _Pages(),
        const _Older(),
      ]) {
        expect(request.acceptsItem(view), isTrue, reason: '$request');
        expect(request.acceptsItem(other), isFalse, reason: '$request');
        expect(request.acceptsItem(null), isFalse, reason: '$request');
      }
    });
  });

  test('channel wire names', () {
    expect(dwParseChannelName('chat:7'), (kind: 'chat', key: '7'));
    expect(dwParseChannelName('news'), (kind: 'news', key: null));
  });
}

final class _Rating extends DwCommand<void> implements DwValidatable {
  const _Rating(this.stars);

  final int stars;

  @override
  List<DwRefusal> validate() => [
    if (stars > 5)
      DwRefusal(DwCoreRefusal.invalid, field: 'stars', params: {'max': 5}),
  ];

  @override
  String get dwTypeName => '_Rating';

  @override
  Map<String, Object?> toJson() => {'stars': stars};
}

final class _Other extends DwDataObject {
  @override
  Object get id => 1;

  @override
  String get dwTypeName => '_Other';

  @override
  Map<String, Object?> toJson() => const {'id': 1};
}

final class _One extends DwSingleRequest<BookingView> {
  const _One();

  @override
  String get dwTypeName => '_One';

  @override
  Map<String, Object?> toJson() => const {};
}

final class _Maybe extends DwMaybeRequest<BookingView> {
  const _Maybe();

  @override
  String get dwTypeName => '_Maybe';

  @override
  Map<String, Object?> toJson() => const {};
}

final class _Pages extends DwPageRequest<BookingView> {
  const _Pages();

  @override
  int get pageSize => 10;

  @override
  String get dwTypeName => '_Pages';

  @override
  Map<String, Object?> toJson() => const {};
}

final class _Older extends DwCursorRequest<BookingView> {
  const _Older();

  @override
  int get pageSize => 10;

  @override
  String get dwTypeName => '_Older';

  @override
  Map<String, Object?> toJson() => const {};
}
