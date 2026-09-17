import 'package:dartway_core_shared/dartway_core_shared.dart';
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

    test('a defaulted field may be absent: decoded to its default, and a '
        'value equal to it is omitted (D-041)', () {
      final json = booking.toJson();
      expect(json.containsKey('seats'), isFalse);
      expect(
        protocol.decodeAs<ClubBooking>(roundTrip(json)).seats,
        booking.seats,
      );
      final twoSeats = ClubBooking(
        id: 8,
        status: BookingStatus.booked,
        startsAt: DateTime.utc(2026, 9, 14),
        seats: 2,
      );
      expect(twoSeats.toJson()['seats'], 2);
      expect(
        protocol.decodeAs<ClubBooking>(roundTrip(twoSeats.toJson())),
        twoSeats,
      );

      expect(const ListMyBookings().toJson(), isEmpty);
      expect(
        protocol.decodeAs<ListMyBookings>(<String, Object?>{}),
        const ListMyBookings(),
      );
      expect(const ListMyBookings(includePast: true).toJson(), {
        'includePast': true,
      });
      expect(
        protocol.decodeAs<ListMyBookings>(
          roundTrip(const ListMyBookings(includePast: true).toJson()),
        ),
        const ListMyBookings(includePast: true),
      );

      // A required field without a default stays required.
      expect(
        () => protocol.decodeAs<ClubBooking>(<String, Object?>{
          'id': 1,
          'startsAt': 0,
        }),
        throwsA(anything),
      );
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
      Map<String, Object?> wire(DwFieldPatch<String> p) =>
          roundTrip(RenameBooking(bookingId: 1, note: p).toJson())
              as Map<String, Object?>;

      expect(wire(const DwFieldPatch.keep()).containsKey('note'), isFalse);
      expect(wire(const DwFieldPatch.clear())['note'], isNull);
      expect(wire(const DwFieldPatch.clear()).containsKey('note'), isTrue);

      for (final patch in const [
        DwFieldPatch<String>.keep(),
        DwFieldPatch<String>.set('late'),
        DwFieldPatch<String>.clear(),
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
    R wire<R>(DwActionCommand<R> command, R value) => command.decodeResult(
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
      const session = DwAuthSession(id: 5, token: 't', isNewAccount: true);
      const verify = DwVerifyCode(ticketId: 'x', code: '1');
      expect(wire(verify, session), session);
    });

    test('the identity and session key DTOs round-trip, absent optional '
        'fields omitted, and never carry a token', () {
      final created = DateTime.utc(2026, 9, 14, 12);
      final identity = DwIdentityInfo(
        id: 3,
        accountId: 7,
        kind: DwIdentifierKind.phone,
        value: '+15550001111',
        createdAt: created,
      );
      expect(identity.toJson().containsKey('verifiedAt'), isFalse);
      const confirm = DwConfirmIdentifier(ticketId: 't', code: '1234');
      expect(wire(confirm, identity), identity);
      final verified = DwIdentityInfo(
        id: 3,
        accountId: 7,
        kind: DwIdentifierKind.phone,
        value: '+15550001111',
        createdAt: created,
        verifiedAt: created.add(const Duration(minutes: 1)),
      );
      expect(wire(confirm, verified), verified);

      final key = DwSessionKeyInfo(
        id: 9,
        accountId: 7,
        kind: DwSessionKeyKind.personal,
        label: 'Claude Code',
        createdAt: created,
        lastUsedAt: created,
      );
      expect(key.toJson().keys, [
        'id',
        'accountId',
        'kind',
        'label',
        'createdAt',
        'lastUsedAt',
      ]);
      expect(DwSessionKeyInfo.fromJson(key.toJson()), key);
      expect(protocol.decodeValue<DwSessionKeyInfo>(key.toJson()), key);
      final revoked = DwSessionKeyInfo(
        id: 9,
        accountId: 7,
        kind: DwSessionKeyKind.personal,
        label: 'Claude Code',
        createdAt: created,
        lastUsedAt: created,
        revokedAt: created,
      );
      expect(DwSessionKeyInfo.fromJson(revoked.toJson()), revoked);
      expect(revoked.isRevoked, isTrue);

      for (final command in [
        const DwRequestIdentifierCode(
          kind: DwIdentifierKind.email,
          identifier: 'a@b.c',
        ),
        confirm,
        const DwConfirmIdentifier(ticketId: 't', code: '1', replace: true),
      ]) {
        final entry = protocol.entryNamed(command.dwTypeName)!;
        expect(entry.fromJson(command.toJson()), command);
      }
      expect(confirm.toJson().containsKey('replace'), isFalse);
      expect(DwAuthRefusal.identifierTaken.code, 'dw.identifierTaken');
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
        'DwDeletedObject',
        'DwRequestCode',
        'DwCodeTicket',
        'DwVerifyCode',
        'DwAuthSession',
        'DwSignOut',
        'DwDeleteMyAccount',
        'DwRequestIdentifierCode',
        'DwConfirmIdentifier',
        'DwIdentityInfo',
        'DwSessionKeyInfo',
        'DwStartUpload',
        'DwUploadTicket',
        'DwFinishUpload',
        'DwStoredFile',
        'DwGetFileLink',
        'DwFileLink',
        'ClubBooking',
        'ListMyBookings',
        'RenameBooking',
        'CoachNote',
      ]);
      expect(
        {for (final e in protocol.entries) e.name: e.kind},
        {
          'DwDeletedObject': DwWireObjectKind.other,
          'DwRequestCode': DwWireObjectKind.command,
          'DwCodeTicket': DwWireObjectKind.dataObject,
          'DwVerifyCode': DwWireObjectKind.command,
          'DwAuthSession': DwWireObjectKind.dataObject,
          'DwSignOut': DwWireObjectKind.command,
          'DwDeleteMyAccount': DwWireObjectKind.command,
          'DwRequestIdentifierCode': DwWireObjectKind.command,
          'DwConfirmIdentifier': DwWireObjectKind.command,
          'DwIdentityInfo': DwWireObjectKind.dataObject,
          'DwSessionKeyInfo': DwWireObjectKind.dataObject,
          'DwStartUpload': DwWireObjectKind.command,
          'DwUploadTicket': DwWireObjectKind.dataObject,
          'DwFinishUpload': DwWireObjectKind.command,
          'DwStoredFile': DwWireObjectKind.dataObject,
          'DwGetFileLink': DwWireObjectKind.request,
          'DwFileLink': DwWireObjectKind.dataObject,
          'ClubBooking': DwWireObjectKind.dataObject,
          'ListMyBookings': DwWireObjectKind.request,
          'RenameBooking': DwWireObjectKind.command,
          'CoachNote': DwWireObjectKind.dataObject,
        },
      );
      expect(protocol.entryNamed('ClubBooking')?.type, ClubBooking);
      expect(protocol.entryNamed('Nope'), isNull);
    });

    test('every request kind reads as a request', () {
      final entries = [
        DwProtocolEntry<GetBooking>('GetBooking', (_) => const GetBooking()),
        DwProtocolEntry<FindBooking>(
          'FindBooking',
          (_) => const FindBooking(1),
        ),
        DwProtocolEntry<FeedBookings>(
          'FeedBookings',
          (_) => const FeedBookings(),
        ),
        DwProtocolEntry<ListBookingTable>(
          'ListBookingTable',
          (_) => const ListBookingTable(),
        ),
        DwProtocolEntry<BookingHistory>(
          'BookingHistory',
          (_) => const BookingHistory(),
        ),
      ];
      expect(
        entries.map((e) => e.kind),
        everyElement(DwWireObjectKind.request),
      );
    });

    test('two classes under one wire name are refused', () {
      expect(
        () => DwWireProtocol([
          const DwProtocolEntry<ClubBooking>('Same', $ClubBookingFromJson),
          const DwProtocolEntry<ListMyBookings>(
            'Same',
            $ListMyBookingsFromJson,
          ),
        ]),
        throwsStateError,
      );
    });

    test('one class under two names is refused', () {
      expect(
        () => DwWireProtocol([
          const DwProtocolEntry<ClubBooking>('One', $ClubBookingFromJson),
          const DwProtocolEntry<ClubBooking>('Two', $ClubBookingFromJson),
        ]),
        throwsStateError,
      );
    });

    test(
      'an entry whose type argument was inferred, not written, is refused',
      () {
        // In a list literal the type argument comes from the list, not from the
        // factory: this entry registers DwWireObject.
        expect(
          () => DwWireProtocol([
            DwProtocolEntry('ClubBooking', $ClubBookingFromJson),
          ]),
          throwsArgumentError,
        );
        expect(
          () => DwWireProtocol([
            DwProtocolEntry<DwDataObject>('ClubBooking', $ClubBookingFromJson),
          ]),
          throwsArgumentError,
        );
      },
    );
  });

  group('refusals', () {
    test('a refusal carries a code and string params, never a sentence', () {
      final refusal = DwCallRefusal(
        DwCoreRefusal.invalid,
        params: {'max': 5, 'skip': null},
        field: 'rating',
      );
      final back = DwCallRefusal.fromJson(roundTrip(refusal.toJson()));
      expect(back, refusal);
      expect(back.code, 'dw.invalid');
      expect(back.params, {'max': '5'});
      expect(back.isCode(DwCoreRefusal.invalid), isTrue);
    });

    test('tooManyRequests carries whole seconds, rounded up, at least one', () {
      final refusal = DwCallRefusal.tooManyRequests(
        const Duration(milliseconds: 2001),
      );
      expect(refusal.code, 'dw.tooManyRequests');
      expect(refusal.params, {'retryAfter': '3'});
      expect(
        DwCallRefusal.fromJson(roundTrip(refusal.toJson())).retryAfter,
        const Duration(seconds: 3),
      );
      expect(
        DwCallRefusal.tooManyRequests(Duration.zero).retryAfter,
        const Duration(seconds: 1),
      );
      expect(
        DwCallRefusal(
          DwCoreRefusal.invalid,
          params: {'retryAfter': 5},
        ).retryAfter,
        isNull,
      );
    });

    test('the incompatibility codes', () {
      expect(
        DwCallRefusal(DwCoreRefusal.updateRequired).code,
        'dw.updateRequired',
      );
      expect(
        DwCallRefusal(DwCoreRefusal.protocolUnsupported).code,
        'dw.protocolUnsupported',
      );
    });
  });

  test('a validatable DTO answers its refusals', () {
    expect(const _Rating(3).validate(), isEmpty);
    expect(const _Rating(9).validate(), [
      DwCallRefusal(DwCoreRefusal.invalid, field: 'stars', params: {'max': 5}),
    ]);
  });

  test('channel wire names', () {
    expect(dwParseChannelName('chat:7'), (kind: 'chat', key: '7'));
    expect(dwParseChannelName('news'), (kind: 'news', key: null));
    expect(const DwLiveChannel(_Channel.chat, 7).wireName, 'chat:7');
    expect(const DwLiveChannel(_Channel.news).wireName, 'news');
  });

  group('caller channels (D-037)', () {
    const mine = DwLiveChannel.ofCaller(_Channel.bookings);

    test('resolve to the account that watches', () {
      expect(mine.isOfCaller, isTrue);
      expect(mine.key, isNull);
      final resolved = mine.resolvedFor(7);
      expect(resolved.wireName, 'bookings:7');
      expect(resolved.isOfCaller, isFalse);
      expect(resolved, const DwLiveChannel.forAccount(_Channel.bookings, 7));
      expect(resolved, const DwLiveChannel(_Channel.bookings, 7));
    });

    test('any other channel resolves to itself', () {
      const chat = DwLiveChannel(_Channel.chat, 3);
      expect(chat.resolvedFor(7), same(chat));
    });

    test('have no wire name until resolved', () {
      expect(() => mine.wireName, throwsStateError);
      expect(mine.toString(), 'DwLiveChannel.ofCaller(bookings)');
    });

    test('are equal by kind, and never to a keyed channel', () {
      expect(mine, const DwLiveChannel.ofCaller(_Channel.bookings));
      expect(
        mine.hashCode,
        const DwLiveChannel.ofCaller(_Channel.bookings).hashCode,
      );
      expect(mine, isNot(const DwLiveChannel(_Channel.bookings)));
      expect(mine, isNot(const DwLiveChannel.ofCaller(_Channel.chat)));
    });
  });
}

enum _Channel with DwChannelKind { chat, news, bookings }

final class _Command<R> extends DwActionCommand<R> {
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

final class _Rating extends DwActionCommand<void> implements DwSelfValidating {
  const _Rating(this.stars);

  final int stars;

  @override
  List<DwCallRefusal> validate() => [
    if (stars > 5)
      DwCallRefusal(DwCoreRefusal.invalid, field: 'stars', params: {'max': 5}),
  ];

  @override
  String get dwTypeName => '_Rating';

  @override
  Map<String, Object?> toJson() => {'stars': stars};
}
