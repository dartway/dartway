import 'package:dartway_core/dartway_core.dart';
import 'package:test/test.dart';

import 'support/protocol.dart';

void main() {
  group('generated-shape DTO', () {
    test('omits absent optional fields and round-trips untagged', () {
      final json = booking.toJson();
      expect(json.containsKey('note'), isFalse);
      expect(json.containsKey('@t'), isFalse);
      final back = protocol.decodeAs<ClubBooking>(roundTrip(json));
      expect(back, booking);
      expect(back.hashCode, booking.hashCode);
      expect(protocol.decodeNamed('ClubBooking', roundTrip(json)), booking);
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
          roundTrip(RenameBooking(bookingId: 1, note: p).toJson())
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
            protocol.decodeNamed('RenameBooking', wire(patch)) as RenameBooking;
        expect(decoded.note, patch);
      }
    });

    test(
      'decoding by an unknown name or a non-object is a FormatException',
      () {
        expect(() => protocol.decodeNamed('Nope', {}), throwsFormatException);
        expect(
          () => protocol.decodeNamed('ClubBooking', [1]),
          throwsFormatException,
        );
        expect(
          () => protocol.decodeAs<ClubBooking>('x'),
          throwsFormatException,
        );
      },
    );
  });

  group('command results: one untagged value typed by R', () {
    R wire<R>(DwCommand<R> command, R value) => command.decodeResult(
      roundTrip(command.encodeResult(value, protocol)),
      protocol,
    );

    test('a DTO result travels as its own JSON and decodes to R', () {
      const command = RenameBooking(bookingId: 7);
      expect(command.encodeResult(booking, protocol), booking.toJson());
      expect(wire(command, booking), booking);
    });

    test('a nullable DTO result', () {
      const command = _Command<ClubBooking?>();
      expect(wire(command, booking), booking);
      expect(command.encodeResult(null, protocol), isNull);
      expect(wire<ClubBooking?>(command, null), isNull);
    });

    test('a framework DTO result (the auth commands)', () {
      const session = DwSession(id: 5, token: 't', isNewAccount: true);
      const verify = DwVerifyCode(ticketId: 'x', code: '1');
      expect(wire(verify, session), session);
    });

    test('primitives, nullable primitives and void', () {
      expect(wire(const _Command<int>(), 42), 42);
      expect(wire(const _Command<String>(), 'ok'), 'ok');
      expect(wire(const _Command<bool>(), false), isFalse);
      expect(wire<int?>(const _Command<int?>(), null), isNull);
      expect(wire(const _Command<num>(), 2.5), 2.5);
      // A whole double is written as a JSON integer; R reads it back.
      final whole = wire(const _Command<double>(), 3.0);
      expect(whole, 3.0);
      expect(whole, isA<double>());
      const signOut = DwSignOut();
      expect(signOut.encodeResult(null, protocol), isNull);
      expect(() => signOut.decodeResult(null, protocol), returnsNormally);
    });

    test('a value that is not R is a FormatException', () {
      expect(
        () => const _Command<int>().decodeResult(null, protocol),
        throwsFormatException,
      );
      expect(
        () => const _Command<int>().decodeResult('42', protocol),
        throwsFormatException,
      );
      expect(
        () => const _Command<String>().decodeResult(booking.toJson(), protocol),
        throwsFormatException,
      );
      expect(
        () => const RenameBooking(bookingId: 1).decodeResult(42, protocol),
        throwsFormatException,
      );
      expect(
        () => const RenameBooking(bookingId: 1).decodeResult(null, protocol),
        throwsFormatException,
      );
    });

    test('an unregistered DTO result type is a StateError', () {
      expect(
        () => const _Command<_Unregistered>().decodeResult({'id': 1}, protocol),
        throwsStateError,
      );
    });

    test('a collection result is refused when encoding', () {
      expect(
        () => const _Command<Object?>().encodeResult([booking], protocol),
        throwsArgumentError,
      );
    });
  });

  group('registry', () {
    test('every entry is listed once with its kind, core entries first', () {
      expect(protocol.entries.map((e) => e.name), [
        'DwDeleted',
        'DwRequestCode',
        'DwCodeTicket',
        'DwVerifyCode',
        'DwSession',
        'DwSignOut',
        'ClubBooking',
        'ListMyBookings',
        'RenameBooking',
        'CoachNote',
      ]);
      expect(
        {for (final e in protocol.entries) e.name: e.kind},
        {
          'DwDeleted': DwDtoKind.other,
          'DwRequestCode': DwDtoKind.command,
          'DwCodeTicket': DwDtoKind.dataObject,
          'DwVerifyCode': DwDtoKind.command,
          'DwSession': DwDtoKind.dataObject,
          'DwSignOut': DwDtoKind.command,
          'ClubBooking': DwDtoKind.dataObject,
          'ListMyBookings': DwDtoKind.request,
          'RenameBooking': DwDtoKind.command,
          'CoachNote': DwDtoKind.dataObject,
        },
      );
      expect(protocol.entryNamed('ClubBooking')?.type, ClubBooking);
      expect(protocol.entryNamed('Nope'), isNull);
    });

    test('every request kind reads as a request', () {
      final entries = [
        DwDtoEntry<GetBooking>('GetBooking', (_) => const GetBooking()),
        DwDtoEntry<FindBooking>('FindBooking', (_) => const FindBooking(1)),
        DwDtoEntry<FeedBookings>('FeedBookings', (_) => const FeedBookings()),
        DwDtoEntry<ListBookingTable>(
          'ListBookingTable',
          (_) => const ListBookingTable(),
        ),
        DwDtoEntry<BookingHistory>(
          'BookingHistory',
          (_) => const BookingHistory(),
        ),
      ];
      expect(entries.map((e) => e.kind), everyElement(DwDtoKind.request));
    });

    test('two classes under one wire name are refused', () {
      expect(
        () => DwProtocol([
          const DwDtoEntry<ClubBooking>('Same', $ClubBookingFromJson),
          const DwDtoEntry<ListMyBookings>('Same', $ListMyBookingsFromJson),
        ]),
        throwsStateError,
      );
    });

    test('one class under two names is refused', () {
      expect(
        () => DwProtocol([
          const DwDtoEntry<ClubBooking>('One', $ClubBookingFromJson),
          const DwDtoEntry<ClubBooking>('Two', $ClubBookingFromJson),
        ]),
        throwsStateError,
      );
    });

    test(
      'an entry whose type argument was inferred, not written, is refused',
      () {
        // In a list literal the type argument comes from the list, not from the
        // factory: this entry registers DwDto.
        expect(
          () => DwProtocol([DwDtoEntry('ClubBooking', $ClubBookingFromJson)]),
          throwsArgumentError,
        );
        expect(
          () => DwProtocol([
            DwDtoEntry<DwDataObject>('ClubBooking', $ClubBookingFromJson),
          ]),
          throwsArgumentError,
        );
      },
    );
  });

  group('refusals', () {
    test('a refusal carries a code and string params, never a sentence', () {
      final refusal = DwRefusal(
        DwCoreRefusal.invalid,
        params: {'max': 5, 'skip': null},
        field: 'rating',
      );
      final back = DwRefusal.fromJson(roundTrip(refusal.toJson()));
      expect(back, refusal);
      expect(back.code, 'dw.invalid');
      expect(back.params, {'max': '5'});
      expect(back.isCode(DwCoreRefusal.invalid), isTrue);
    });

    test('tooManyRequests carries whole seconds, rounded up, at least one', () {
      final refusal = DwRefusal.tooManyRequests(
        const Duration(milliseconds: 2001),
      );
      expect(refusal.code, 'dw.tooManyRequests');
      expect(refusal.params, {'retryAfter': '3'});
      expect(
        DwRefusal.fromJson(roundTrip(refusal.toJson())).retryAfter,
        const Duration(seconds: 3),
      );
      expect(
        DwRefusal.tooManyRequests(Duration.zero).retryAfter,
        const Duration(seconds: 1),
      );
      expect(
        DwRefusal(DwCoreRefusal.invalid, params: {'retryAfter': 5}).retryAfter,
        isNull,
      );
    });

    test('the incompatibility codes', () {
      expect(DwRefusal(DwCoreRefusal.updateRequired).code, 'dw.updateRequired');
      expect(
        DwRefusal(DwCoreRefusal.protocolUnsupported).code,
        'dw.protocolUnsupported',
      );
    });
  });

  test('a validatable DTO answers its refusals', () {
    expect(const _Rating(3).validate(), isEmpty);
    expect(const _Rating(9).validate(), [
      DwRefusal(DwCoreRefusal.invalid, field: 'stars', params: {'max': 5}),
    ]);
  });

  test('channel wire names', () {
    expect(dwParseChannelName('chat:7'), (kind: 'chat', key: '7'));
    expect(dwParseChannelName('news'), (kind: 'news', key: null));
  });
}

final class _Command<R> extends DwCommand<R> {
  const _Command();

  @override
  String get dwTypeName => '_Command';

  @override
  Map<String, Object?> toJson() => const {};
}

final class _Unregistered extends DwDataObject {
  const _Unregistered();

  @override
  Object get id => 1;

  @override
  String get dwTypeName => '_Unregistered';

  @override
  Map<String, Object?> toJson() => const {'id': 1};
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
