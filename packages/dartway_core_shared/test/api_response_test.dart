import 'package:dartway_core_shared/dartway_core_shared.dart';
import 'package:test/test.dart';

import 'support/protocol.dart';

void main() {
  DwApiResponse back(DwApiResponse response) =>
      DwApiResponse.fromJson(roundTrip(response.toJson()), protocol);

  group('JSON (docs/2-core/wire-and-versions.md)', () {
    test('ok: the result untagged, updates grouped by channel then type', () {
      final updates = DwUpdateTransport([
        ('myBookings:3', booking),
        ('myBookings:3', DwDeletedObject.of<ClubBooking>(3, protocol)),
        ('notes', const CoachNote(1)),
      ]);
      final response = DwApiResponse.ok(
        const ListMyBookings().encodeResult([booking], protocol),
        updates: updates,
      );
      expect(roundTrip(response.toJson()), {
        'status': 'ok',
        'result': [booking.toJson()],
        'updates': {
          'myBookings:3': {
            'ClubBooking': [booking.toJson()],
            'DwDeletedObject': [
              {'type': 'ClubBooking', 'id': 3},
            ],
          },
          'notes': {
            'CoachNote': [
              {'id': 1},
            ],
          },
        },
      });
      final decoded = back(response) as DwApiOk;
      expect(decoded.result, [booking.toJson()]);
      expect(decoded.updates, updates);
    });

    test('ok: a null result and empty updates are omitted', () {
      expect(const DwApiResponse.ok(null).toJson(), {'status': 'ok'});
      final decoded = back(const DwApiResponse.ok(null)) as DwApiOk;
      expect(decoded.result, isNull);
      expect(decoded.updates, DwUpdateTransport.empty);
    });

    test('refused, unauthenticated, failed, incompatible', () {
      final refused = DwApiResponse.refused(
        DwCallRefusal(DwCoreRefusal.invalid, field: 'note', params: {'max': 3}),
      );
      expect(refused.toJson(), {
        'status': 'refused',
        'refusal': {
          'code': 'dw.invalid',
          'params': {'max': '3'},
          'field': 'note',
        },
      });
      expect(
        (back(refused) as DwApiRefused).refusal,
        (refused as DwApiRefused).refusal,
      );

      expect(const DwApiResponse.unauthenticated().toJson(), {
        'status': 'unauthenticated',
      });
      expect(
        back(const DwApiResponse.unauthenticated()),
        isA<DwApiUnauthenticated>(),
      );

      const failed = DwApiResponse.failed('inc-1');
      expect(failed.toJson(), {'status': 'failed', 'incidentId': 'inc-1'});
      final failedBack = back(failed) as DwApiFailed;
      expect(failedBack.incidentId, 'inc-1');
      expect(failedBack.failure, DwFailureKind.internal);

      const malformed = DwApiResponse.failed(
        'inc-2',
        failure: DwFailureKind.malformedCall,
      );
      expect(
        (back(malformed) as DwApiFailed).failure,
        DwFailureKind.malformedCall,
      );

      final incompatible = DwApiResponse.incompatible(
        DwCallRefusal(DwCoreRefusal.updateRequired),
      );
      expect(incompatible.toJson(), {
        'status': 'incompatible',
        'refusal': {'code': 'dw.updateRequired'},
      });
      expect(
        (back(incompatible) as DwApiIncompatible).refusal.code,
        'dw.updateRequired',
      );
    });

    test(
      'the spec example with explicit empty params and null field reads',
      () {
        final response = DwApiResponse.fromJson(
          roundTrip({
            'status': 'refused',
            'refusal': {'code': 'noSpotsLeft', 'params': {}, 'field': null},
          }),
          protocol,
        );
        expect(
          (response as DwApiRefused).refusal,
          const DwCallRefusal.raw('noSpotsLeft'),
        );
      },
    );

    test(
      'an incompatibility is never refused, and only it is incompatible',
      () {
        expect(
          () => DwApiResponse.refused(
            DwCallRefusal(DwCoreRefusal.protocolUnsupported),
          ),
          throwsArgumentError,
        );
        expect(
          () => DwApiResponse.incompatible(
            DwCallRefusal(DwCoreRefusal.forbidden),
          ),
          throwsArgumentError,
        );
        expect(
          () => DwApiResponse.fromJson({
            'status': 'refused',
            'refusal': {'code': 'dw.updateRequired'},
          }, protocol),
          throwsFormatException,
        );
        expect(
          DwCallRefusal(DwCoreRefusal.updateRequired).isIncompatibility,
          isTrue,
        );
        expect(
          DwCallRefusal(DwCoreRefusal.conflict).isIncompatibility,
          isFalse,
        );
      },
    );

    test('a malformed body is a FormatException', () {
      for (final json in <Object?>[
        null,
        'ok',
        <String, Object?>{},
        {'status': 'maybe'},
        {'status': 'ok', 'value': 1},
        {'status': 'ok', 'updates': []},
        {'status': 'refused'},
        {
          'status': 'refused',
          'refusal': {
            'code': 'x',
            'params': {'n': 1},
          },
        },
        {'status': 'failed'},
        {'status': 'failed', 'incidentId': 'i', 'failure': 'unknown'},
        {'status': 'unauthenticated', 'incidentId': 'i'},
      ]) {
        expect(
          () => DwApiResponse.fromJson(roundTrip(json), protocol),
          throwsFormatException,
          reason: '$json',
        );
      }
    });
  });

  group('HTTP status (docs/2-core/refusals-and-statuses.md honest statuses)', () {
    int status(DwApiResponse response) => dwHttpStatusFor(response);
    DwApiResponse refused(DwRefusalCode code) =>
        DwApiResponse.refused(DwCallRefusal(code));

    test('every outcome maps to its status', () {
      expect(status(const DwApiResponse.ok(null)), 200);
      expect(status(refused(DwCoreRefusal.invalid)), 422);
      expect(status(refused(DwCoreRefusal.codeExpired)), 422);
      expect(
        status(DwApiResponse.refused(const DwCallRefusal.raw('noSpotsLeft'))),
        422,
      );
      expect(status(refused(DwCoreRefusal.forbidden)), 403);
      expect(status(refused(DwCoreRefusal.notFound)), 404);
      expect(status(refused(DwCoreRefusal.conflict)), 409);
      expect(
        status(
          DwApiResponse.refused(
            DwCallRefusal.tooManyRequests(const Duration(seconds: 4)),
          ),
        ),
        429,
      );
      expect(status(const DwApiResponse.unauthenticated()), 401);
      expect(status(const DwApiResponse.failed('i')), 500);
      expect(
        status(
          const DwApiResponse.failed('i', failure: DwFailureKind.malformedCall),
        ),
        400,
      );
      expect(
        status(
          const DwApiResponse.failed('i', failure: DwFailureKind.unknownCall),
        ),
        404,
      );
      expect(
        status(
          DwApiResponse.incompatible(
            DwCallRefusal(DwCoreRefusal.updateRequired),
          ),
        ),
        426,
      );
      expect(
        DwApiResponse.incompatible(
          DwCallRefusal(DwCoreRefusal.protocolUnsupported),
        ).httpStatus,
        426,
      );
    });

    test(
      'a project code named like a framework code is not mistaken for it',
      () {
        expect(
          status(DwApiResponse.refused(const DwCallRefusal.raw('forbidden'))),
          422,
        );
      },
    );

    test('Retry-After accompanies tooManyRequests only', () {
      expect(
        dwHttpHeadersFor(
          DwApiResponse.refused(
            DwCallRefusal.tooManyRequests(const Duration(milliseconds: 2500)),
          ),
        ),
        {'Retry-After': '3'},
      );
      expect(dwHttpHeadersFor(refused(DwCoreRefusal.forbidden)), isEmpty);
      expect(dwHttpHeadersFor(const DwApiResponse.ok(null)), isEmpty);
    });

    test('the client refuses a body whose status disagrees', () {
      final json = roundTrip(const DwApiResponse.unauthenticated().toJson());
      expect(
        DwApiResponse.fromHttp(401, json, protocol),
        isA<DwApiUnauthenticated>(),
      );
      expect(
        () => DwApiResponse.fromHttp(200, json, protocol),
        throwsFormatException,
      );
    });
  });

  group('client decoding into DwCallResult', () {
    test('ok decodes with the call class, typed', () {
      const request = ListMyBookings();
      final response = DwApiResponse.fromJson(
        roundTrip(
          DwApiResponse.ok(request.encodeResult([booking], protocol)).toJson(),
        ),
        protocol,
      );
      final result = response.toResult(request, protocol);
      expect(result, isA<DwCallOk<List<ClubBooking>>>());
      expect(result.valueOrNull, [booking]);

      const command = RenameBooking(bookingId: 7);
      final commandResult = DwApiResponse.fromJson(
        roundTrip(
          DwApiResponse.ok(command.encodeResult(booking, protocol)).toJson(),
        ),
        protocol,
      ).toResult(command, protocol);
      expect(commandResult.valueOrNull, booking);
    });

    test('the other outcomes', () {
      const request = GetBooking();
      expect(
        DwApiResponse.refused(
          DwCallRefusal(DwCoreRefusal.notFound),
        ).toResult(request, protocol),
        isA<DwCallRefused<ClubBooking>>(),
      );
      final incompatible = DwApiResponse.incompatible(
        DwCallRefusal(DwCoreRefusal.updateRequired),
      ).toResult(request, protocol);
      expect(
        (incompatible as DwCallRefused<ClubBooking>).refusal.isCode(
          DwCoreRefusal.updateRequired,
        ),
        isTrue,
      );
      expect(
        const DwApiResponse.unauthenticated().toResult(request, protocol),
        isA<DwNotAuthenticated<ClubBooking>>(),
      );
      final failed = const DwApiResponse.failed(
        'inc',
      ).toResult(request, protocol);
      expect((failed as DwCallFailed<ClubBooking>).incidentId, 'inc');
    });

    test('a result that does not decode as the call is a FormatException', () {
      expect(
        () => const DwApiResponse.ok(
          'text',
        ).toResult(const GetBooking(), protocol),
        throwsFormatException,
      );
    });
  });
}
