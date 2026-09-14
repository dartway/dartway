import 'package:dartway_core/dartway_core.dart';
import 'package:test/test.dart';

import 'support/protocol.dart';

void main() {
  DwApiResponse back(DwApiResponse response) =>
      DwApiResponse.fromJson(roundTrip(response.toJson()), protocol);

  group('JSON (R2.2)', () {
    test('ok: the result untagged, updates as a transport', () {
      final updates = DwTransport([
        booking,
        DwDeleted.of<ClubBooking>(3, protocol),
      ]);
      final response = DwApiResponse.ok(
        const ListMyBookings().encodeResult([booking], protocol),
        updates: updates,
      );
      expect(roundTrip(response.toJson()), {
        'status': 'ok',
        'result': [booking.toJson()],
        'updates': {
          'ClubBooking': [booking.toJson()],
          'DwDeleted': [
            {'type': 'ClubBooking', 'id': 3},
          ],
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
      expect(decoded.updates, DwTransport.empty);
    });

    test('refused, unauthenticated, failed, incompatible', () {
      final refused = DwApiResponse.refused(
        DwRefusal(DwCoreRefusal.invalid, field: 'note', params: {'max': 3}),
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
      expect(failedBack.failure, DwFailure.internal);

      const malformed = DwApiResponse.failed(
        'inc-2',
        failure: DwFailure.malformedCall,
      );
      expect((back(malformed) as DwApiFailed).failure, DwFailure.malformedCall);

      final incompatible = DwApiResponse.incompatible(
        DwRefusal(DwCoreRefusal.updateRequired),
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
          const DwRefusal.raw('noSpotsLeft'),
        );
      },
    );

    test(
      'an incompatibility is never refused, and only it is incompatible',
      () {
        expect(
          () => DwApiResponse.refused(
            DwRefusal(DwCoreRefusal.protocolUnsupported),
          ),
          throwsArgumentError,
        );
        expect(
          () => DwApiResponse.incompatible(DwRefusal(DwCoreRefusal.forbidden)),
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
          DwRefusal(DwCoreRefusal.updateRequired).isIncompatibility,
          isTrue,
        );
        expect(DwRefusal(DwCoreRefusal.conflict).isIncompatibility, isFalse);
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

  group('HTTP status (R2.2 honest statuses)', () {
    int status(DwApiResponse response) => dwHttpStatusFor(response);
    DwApiResponse refused(DwRefusalCode code) =>
        DwApiResponse.refused(DwRefusal(code));

    test('every outcome maps to its status', () {
      expect(status(const DwApiResponse.ok(null)), 200);
      expect(status(refused(DwCoreRefusal.invalid)), 422);
      expect(status(refused(DwCoreRefusal.codeExpired)), 422);
      expect(
        status(DwApiResponse.refused(const DwRefusal.raw('noSpotsLeft'))),
        422,
      );
      expect(status(refused(DwCoreRefusal.forbidden)), 403);
      expect(status(refused(DwCoreRefusal.notFound)), 404);
      expect(status(refused(DwCoreRefusal.conflict)), 409);
      expect(
        status(
          DwApiResponse.refused(
            DwRefusal.tooManyRequests(const Duration(seconds: 4)),
          ),
        ),
        429,
      );
      expect(status(const DwApiResponse.unauthenticated()), 401);
      expect(status(const DwApiResponse.failed('i')), 500);
      expect(
        status(
          const DwApiResponse.failed('i', failure: DwFailure.malformedCall),
        ),
        400,
      );
      expect(
        status(const DwApiResponse.failed('i', failure: DwFailure.unknownCall)),
        404,
      );
      expect(
        status(
          DwApiResponse.incompatible(DwRefusal(DwCoreRefusal.updateRequired)),
        ),
        426,
      );
      expect(
        DwApiResponse.incompatible(
          DwRefusal(DwCoreRefusal.protocolUnsupported),
        ).httpStatus,
        426,
      );
    });

    test(
      'a project code named like a framework code is not mistaken for it',
      () {
        expect(
          status(DwApiResponse.refused(const DwRefusal.raw('forbidden'))),
          422,
        );
      },
    );

    test('Retry-After accompanies tooManyRequests only', () {
      expect(
        dwHttpHeadersFor(
          DwApiResponse.refused(
            DwRefusal.tooManyRequests(const Duration(milliseconds: 2500)),
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

  group('client decoding into DwResult', () {
    test('ok decodes with the call class, typed', () {
      const request = ListMyBookings();
      final response = DwApiResponse.fromJson(
        roundTrip(
          DwApiResponse.ok(request.encodeResult([booking], protocol)).toJson(),
        ),
        protocol,
      );
      final result = response.toResult(request, protocol);
      expect(result, isA<DwOk<List<ClubBooking>>>());
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
          DwRefusal(DwCoreRefusal.notFound),
        ).toResult(request, protocol),
        isA<DwRefused<ClubBooking>>(),
      );
      final incompatible = DwApiResponse.incompatible(
        DwRefusal(DwCoreRefusal.updateRequired),
      ).toResult(request, protocol);
      expect(
        (incompatible as DwRefused<ClubBooking>).refusal.isCode(
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
      expect((failed as DwFailed<ClubBooking>).incidentId, 'inc');
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
