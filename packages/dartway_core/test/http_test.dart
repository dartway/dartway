import 'package:dartway_core/dartway_core.dart';
import 'package:test/test.dart';

import 'support/protocol.dart';

void main() {
  group('call contract', () {
    test('paths', () {
      expect(dwProtocolVersion, 1);
      expect(DwHttp.livePath, '/dw/live');
      expect(DwHttp.healthPath, '/health');
      expect(DwHttp.callPath('BookSession'), '/dw/BookSession');
      expect(DwHttp.wireNameOf('/dw/BookSession'), 'BookSession');
      for (final path in [
        '/dw/live',
        '/dw/',
        '/dw/a/b',
        '/health',
        '/x/Book',
      ]) {
        expect(DwHttp.wireNameOf(path), isNull, reason: path);
      }
    });

    test('header and parameter names', () {
      expect(DwHttp.authorizationHeader, 'Authorization');
      expect(DwHttp.idempotencyKeyHeader, 'Dw-Idempotency-Key');
      expect(DwHttp.protocolHeader, 'Dw-Protocol');
      expect(DwHttp.appVersionHeader, 'Dw-App-Version');
      expect(DwHttp.liveConnectionHeader, 'Dw-Live-Connection');
      expect(DwHttp.retryAfterHeader, 'Retry-After');
      expect(
        [
          DwHttp.offsetParameter,
          DwHttp.pageSizeParameter,
          DwHttp.anchorParameter,
          DwHttp.beforeParameter,
          DwHttp.afterParameter,
        ],
        ['offset', 'pageSize', 'anchor', 'before', 'after'],
      );
    });

    test('a DTO cannot be named like the live path or a non-identifier', () {
      expect(
        () => DwProtocol([DwDtoEntry<CoachNote>('live', CoachNote.fromJson)]),
        throwsArgumentError,
      );
      expect(
        () => DwProtocol([
          DwDtoEntry<CoachNote>('Coach/Note', CoachNote.fromJson),
        ]),
        throwsArgumentError,
      );
    });
  });

  group('app version', () {
    test('semver+build round-trips', () {
      final version = DwAppVersion.parse('1.4.2+87');
      expect(version.name, '1.4.2');
      expect(version.build, 87);
      expect('$version', '1.4.2+87');
      expect(DwAppVersion.parse('2.0.0-beta.1+3').name, '2.0.0-beta.1');
    });

    test('anything else is a FormatException', () {
      for (final text in [
        '1.4.2',
        '1.4+2',
        '+3',
        '1.4.2+',
        '1.4.2+x',
        '1.4.2+-1',
        '1.4.2+007',
      ]) {
        expect(
          () => DwAppVersion.parse(text),
          throwsFormatException,
          reason: text,
        );
      }
    });
  });

  group('page query', () {
    test('a page request takes an offset and a page size', () {
      const request = FeedBookings();
      expect(DwPageQuery.parse(request, {}), const DwOffsetQuery());
      const query = DwOffsetQuery(offset: 40, pageSize: 60);
      expect(query.toQuery(), {'offset': '40', 'pageSize': '60'});
      expect(DwPageQuery.parse(request, query.toQuery()), query);
      expect(const DwOffsetQuery().toQuery(), isEmpty);
    });

    test('a window request takes one direction and a page size', () {
      const request = BookingHistory();
      final cursor = DwWindowCursor.encode(DateTime.utc(2026), 7);
      final queries = <DwWindowQuery, Map<String, String>>{
        const DwWindowQuery.newest(): {},
        DwWindowQuery.around(cursor): {'anchor': cursor},
        DwWindowQuery.older(cursor, pageSize: 10): {
          'before': cursor,
          'pageSize': '10',
        },
        DwWindowQuery.newer(cursor): {'after': cursor},
      };
      for (final MapEntry(key: query, value: parameters) in queries.entries) {
        expect(query.toQuery(), parameters);
        expect(DwPageQuery.parse(request, parameters), query);
      }
      expect(
        (DwPageQuery.parse(request, {'before': cursor}) as DwWindowQuery)
            .direction,
        DwWindowDirection.older,
      );
    });

    test('the other kinds take no query', () {
      for (final request in <DwRequest<Object?>>[
        const GetBooking(),
        const FindBooking(1),
        const ListMyBookings(),
        const ListBookingTable(),
      ]) {
        expect(DwPageQuery.parse(request, {}), isNull);
        expect(
          () => DwPageQuery.parse(request, {'offset': '0'}),
          throwsFormatException,
        );
      }
    });

    test('a malformed query is a FormatException', () {
      const feed = FeedBookings();
      const history = BookingHistory();
      for (final (request, query)
          in <(DwRequest<Object?>, Map<String, String>)>[
            (feed, {'offset': '-1'}),
            (feed, {'offset': 'x'}),
            (feed, {'offset': '01'}),
            (feed, {'pageSize': '0'}),
            (feed, {'page': '2'}),
            (feed, {'before': 'c'}),
            (history, {'offset': '0'}),
            (history, {'before': 'a', 'after': 'b'}),
            (history, {'anchor': 'a', 'before': 'b'}),
            (history, {'pageSize': '-5'}),
          ]) {
        expect(
          () => DwPageQuery.parse(request, query),
          throwsFormatException,
          reason: '${request.dwTypeName} $query',
        );
      }
    });
  });
}
