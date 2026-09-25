import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import 'support/test_app.dart';

/// The HTTP contract of a call (`docs/2-core/wire-and-versions.md`,
/// `docs/2-core/refusals-and-statuses.md`): paths, headers, bodies and the status
/// of every outcome.
void main() {
  final harness = useHarness();

  late DwTestCaller anonymous;
  late DwTestCaller signed;
  late DwAuthSession session;

  setUpAll(() async {
    anonymous = harness().caller();
    (signed, session) = await harness().signedIn('contract@example.com');
  });

  void expectFailure(DwTestAnswer answer, DwFailureKind kind, int status) {
    expect(answer.status, status, reason: answer.text);
    final response = answer.response;
    expect(response, isA<DwApiFailed>());
    expect((response as DwApiFailed).failure, kind);
    expect(response.incidentId, isNotEmpty);
  }

  group('every outcome has its status, and the body matches it', () {
    test('ok: 200, JSON, never cached', () async {
      final answer = await anonymous.call(const ListNotes(ownerId: -1));
      expect(answer.status, 200);
      expect(answer.reasonPhrase, 'OK');
      expect(answer.response, isA<DwApiOk>());
      expect(answer.json, {'status': 'ok', 'result': <Object?>[]});
      expect(answer.headers.contentType?.mimeType, 'application/json');
      expect(answer.headers.contentType?.charset, 'utf-8');
      expect(answer.headers.value('cache-control'), 'no-store');
    });

    test('a validation refusal: 422', () async {
      final answer = await signed.call(const CreateNote(''));
      expect(answer.status, 422);
      // dart:io has no phrase for 422 and would write "Status 422".
      expect(answer.reasonPhrase, 'Unprocessable Content');
      expect(
        answer.refusal,
        DwCallRefusal(DwCoreRefusal.invalid, field: 'text'),
      );
    });

    test('dw.forbidden: 403', () async {
      final answer = await signed.call(const NotesOfOwner(999999));
      expect(answer.status, 403);
      expect(answer.refusal.isCode(DwCoreRefusal.forbidden), isTrue);
    });

    test('dw.notFound: 404, with a refusal body', () async {
      final answer = await anonymous.call(const GetNote(-1));
      expect(answer.status, 404);
      expect(answer.refusal.isCode(DwCoreRefusal.notFound), isTrue);
    });

    test('dw.conflict: 409', () async {
      final answer = await anonymous.call(
        const Count('status-409', mode: 'refuse'),
      );
      expect(answer.status, 409);
    });

    test('dw.tooManyRequests: 429 with Retry-After', () async {
      const request = DwRequestCode(
        kind: DwIdentifierKind.email,
        identifier: 'status-429@example.com',
      );
      expect((await anonymous.call(request)).status, 200);
      final answer = await anonymous.call(request);
      expect(answer.status, 429);
      expect(answer.reasonPhrase, 'Too Many Requests');
      final retryAfter = int.parse(answer.headers.value('retry-after')!);
      expect(retryAfter, inInclusiveRange(28, 30));
      expect(answer.refusal.retryAfter, Duration(seconds: retryAfter));
    });

    test('unauthenticated: 401 with nothing else', () async {
      final answer = await anonymous.call(const MyNotes());
      expect(answer.status, 401);
      expect(answer.json, {'status': 'unauthenticated'});
    });

    test('a failure: 500 with the incident only, and an alert', () async {
      final answer = await anonymous.call(const ExplodingRequest('hunter2'));
      expectFailure(answer, DwFailureKind.internal, 500);
      expect(answer.text, isNot(contains('hunter2')));
      final incident = (answer.response as DwApiFailed).incidentId;
      await eventually(
        () => harness().app.alerts.incidents.any((i) => i.id == incident),
      );
      final alert = harness().app.alerts.incidents.firstWhere(
        (i) => i.id == incident,
      );
      expect(alert.where, 'request ExplodingRequest');
      expect('${alert.error}', contains('hunter2'));
    });

    test('refusals and client mistakes never alert', () async {
      final before = harness().app.alerts.incidents.length;
      await anonymous.call(const GetNote(-1));
      await anonymous.raw('POST', '/dw/NoSuchCall');
      await anonymous.call(const ListNotes(), body: utf8.encode('nope'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(harness().app.alerts.incidents.length, before);
    });
  });

  group('the path names the call', () {
    test('an unknown wire name: 404 failed unknownCall', () async {
      final answer = await anonymous.call(
        const ListNotes(),
        path: '/dw/NoSuchCall',
      );
      expectFailure(answer, DwFailureKind.unknownCall, 404);
    });

    test('a registered name that is not a call: 404', () async {
      for (final path in ['/dw/NoteView', '/dw/DwDeletedObject', '/dw/a/b']) {
        final answer = await anonymous.call(const ListNotes(), path: path);
        expectFailure(answer, DwFailureKind.unknownCall, 404);
      }
    });

    test('a method other than POST: 400', () async {
      final answer = await anonymous.raw(
        'GET',
        '/dw/ListNotes',
        headers: {DwHttpContract.protocolHeader: '$dwProtocolVersion'},
      );
      expectFailure(answer, DwFailureKind.malformedCall, 400);
    });
  });

  group('headers', () {
    test('Dw-Protocol missing: 400; another version: 426 '
        'dw.protocolUnsupported, before anything else is checked', () async {
      final missing = await anonymous.call(
        const ListNotes(),
        headers: {DwHttpContract.protocolHeader: null},
      );
      expectFailure(missing, DwFailureKind.malformedCall, 400);
      final other = await anonymous.raw(
        'GET',
        '/dw/NoSuchCall',
        headers: {DwHttpContract.protocolHeader: '${dwProtocolVersion + 1}'},
      );
      expect(other.status, 426);
      expect(other.reasonPhrase, 'Upgrade Required');
      expect(other.response, isA<DwApiIncompatible>());
      expect(other.refusal.isCode(DwCoreRefusal.protocolUnsupported), isTrue);
    });

    test('Dw-App-Version: absent is build 0, which a minimum of 0 accepts; '
        'malformed is 400', () async {
      final absent = await anonymous.call(
        const ListNotes(ownerId: -1),
        headers: {DwHttpContract.appVersionHeader: null},
      );
      expect(absent.status, 200);
      for (final value in ['1.0.0', '1.0+3', 'x+1', '1.0.0+-1']) {
        final malformed = await anonymous.call(
          const ListNotes(),
          headers: {DwHttpContract.appVersionHeader: value},
        );
        expectFailure(malformed, DwFailureKind.malformedCall, 400);
      }
    });

    test('Dw-Idempotency-Key: required for a command, forbidden for a '
        'request, bounded in length', () async {
      final missing = await anonymous.call(
        const Ping(),
        headers: {DwHttpContract.idempotencyKeyHeader: null},
      );
      expectFailure(missing, DwFailureKind.malformedCall, 400);
      final empty = await anonymous.call(
        const Ping(),
        headers: {DwHttpContract.idempotencyKeyHeader: ''},
      );
      expectFailure(empty, DwFailureKind.malformedCall, 400);
      final long = await anonymous.call(const Ping(), key: 'k' * 129);
      expectFailure(long, DwFailureKind.malformedCall, 400);
      expect((await anonymous.call(const Ping(), key: 'k' * 128)).status, 200);
      final onRequest = await anonymous.call(
        const ListNotes(),
        headers: {DwHttpContract.idempotencyKeyHeader: 'key'},
      );
      expectFailure(onRequest, DwFailureKind.malformedCall, 400);
    });

    test('Content-Type: JSON in UTF-8 only', () async {
      for (final type in [
        null,
        'text/plain',
        'application/json; charset=latin1',
      ]) {
        final answer = await anonymous.call(
          const ListNotes(),
          headers: {DwHttpContract.contentTypeHeader: type},
        );
        expectFailure(answer, DwFailureKind.malformedCall, 400);
      }
      final bare = await anonymous.call(
        const ListNotes(ownerId: -1),
        headers: {DwHttpContract.contentTypeHeader: 'application/json'},
      );
      expect(bare.status, 200);
    });

    test('Authorization: a scheme other than Bearer is 400; an unknown '
        'token is 401 even on an anonymous call; the scheme is '
        'case-insensitive', () async {
      final basic = await anonymous.call(
        const ListNotes(),
        headers: {DwHttpContract.authorizationHeader: 'Basic abc'},
      );
      expectFailure(basic, DwFailureKind.malformedCall, 400);
      final unknown = await anonymous.call(
        const ListNotes(ownerId: -1),
        headers: {DwHttpContract.authorizationHeader: 'Bearer nope'},
      );
      expect(unknown.status, 401);
      final lower = await anonymous.call(
        const NeedsAccount(),
        headers: {
          DwHttpContract.authorizationHeader: 'bearer ${session.token}',
        },
      );
      expect(lower.value(const NeedsAccount()), session.id);
    });

    test('a header sent twice is 400', () async {
      Future<String> send(List<String> extraHeaders) async {
        final socket = await Socket.connect('127.0.0.1', harness().server.port);
        addTearDown(socket.destroy);
        socket.write(
          'POST /dw/ListNotes HTTP/1.1\r\nHost: 127.0.0.1\r\n'
          'Dw-Protocol: $dwProtocolVersion\r\nContent-Type: application/json\r\n'
          '${extraHeaders.map((h) => '$h\r\n').join()}'
          'Content-Length: 2\r\nConnection: close\r\n\r\n{}',
        );
        return utf8.decodeStream(socket);
      }

      final twice = await send([
        'Authorization: Bearer ${session.token}',
        'Authorization: Bearer ${session.token}',
      ]);
      expect(twice, startsWith('HTTP/1.1 400'));
      final folded = await send([
        'Authorization: Bearer ${session.token}, Bearer ${session.token}',
      ]);
      expect(folded, startsWith('HTTP/1.1 400'));
      final once = await send(['Authorization: Bearer ${session.token}']);
      expect(once, startsWith('HTTP/1.1 200'));
    });
  });

  group('query and body', () {
    test('a request kind that takes no query refuses one: 400', () async {
      final answer = await anonymous.call(
        const ListNotes(),
        query: {'offset': '1'},
      );
      expectFailure(answer, DwFailureKind.malformedCall, 400);
      final table = await anonymous.call(
        const TableNotes('x'),
        query: {'page': '2'},
      );
      expectFailure(table, DwFailureKind.malformedCall, 400);
    });

    test('a command takes no query: 400', () async {
      final answer = await anonymous.call(const Ping(), query: {'a': 'b'});
      expectFailure(answer, DwFailureKind.malformedCall, 400);
    });

    test('a page parameter the kind does not define, a malformed value or '
        'a repeated parameter: 400', () async {
      for (final query in [
        {'anchor': 'x'},
        {'offset': '-1'},
        {'offset': '07'},
        {'pageSize': '0'},
      ]) {
        final answer = await anonymous.call(const FeedNotes('x'), query: query);
        expectFailure(answer, DwFailureKind.malformedCall, 400);
      }
      final repeated = await anonymous.raw(
        'POST',
        '/dw/FeedNotes',
        headers: {
          DwHttpContract.protocolHeader: '$dwProtocolVersion',
          DwHttpContract.contentTypeHeader: DwHttpContract.jsonContentType,
        },
        body: utf8.encode('{"prefix":"x"}'),
      );
      expect(repeated.status, 200);
      final client = HttpClient();
      addTearDown(client.close);
      final request = await client.postUrl(
        harness().server.httpBase.resolve('/dw/FeedNotes?offset=1&offset=2'),
      );
      request.headers
        ..set(DwHttpContract.protocolHeader, '$dwProtocolVersion')
        ..set(DwHttpContract.contentTypeHeader, DwHttpContract.jsonContentType);
      request.write('{"prefix":"x"}');
      final response = await request.close();
      await response.drain<void>();
      expect(response.statusCode, 400);
    });

    test(
      'a body that is not JSON, not an object, or not the DTO: 400',
      () async {
        for (final body in ['', 'nope', '[]', '"x"', '{"ownerId":"seven"}']) {
          final answer = await anonymous.call(
            const ListNotes(),
            body: utf8.encode(body),
          );
          expectFailure(answer, DwFailureKind.malformedCall, 400);
        }
        final invalidUtf8 = await anonymous.call(
          const ListNotes(),
          body: [0x7b, 0xff, 0x7d],
        );
        expectFailure(invalidUtf8, DwFailureKind.malformedCall, 400);
      },
    );

    test('the body limit: 1 MiB by default; a body over it is 400 and the '
        'answer still arrives', () async {
      const limit = 1 << 20;
      // A body of exactly [size] bytes: an unknown key, which the codec
      // ignores, so the limit is the only thing that can refuse it.
      String bodyOf(int size) {
        const head = '{"pad":"';
        const tail = '"}';
        return '$head${'x' * (size - head.length - tail.length)}$tail';
      }

      final atLimit = await anonymous.call(
        const ListNotes(),
        body: utf8.encode(bodyOf(limit)),
      );
      expect(atLimit.status, 200);
      final over = await anonymous.call(
        const ListNotes(),
        body: utf8.encode(bodyOf(limit + 1)),
      );
      expectFailure(over, DwFailureKind.malformedCall, 400);
    });

    test('a handler overrides the body limit, down and up', () async {
      final small = await anonymous.call(SmallUpload('x' * 80));
      expectFailure(small, DwFailureKind.malformedCall, 400);
      expect(
        (await anonymous.call(
          SmallUpload('x' * 10),
        )).value(const SmallUpload('')),
        10,
      );
      final large = await anonymous.call(LargeUpload('x' * (2 << 20)));
      expect(large.value(const LargeUpload('')), 2 << 20);
    });

    test('a body far over any limit is cut off instead of received', () async {
      final client = HttpClient();
      addTearDown(() => client.close(force: true));
      final request = await client.postUrl(
        harness().server.httpBase.resolve('/dw/ListNotes'),
      );
      request.headers
        ..set(DwHttpContract.protocolHeader, '$dwProtocolVersion')
        ..set(DwHttpContract.contentTypeHeader, DwHttpContract.jsonContentType)
        ..contentLength = 64 << 20;
      final outcome = await () async {
        try {
          request.add(List.filled(1 << 20, 0x20));
          final response = await request.close();
          await response.drain<void>();
          return response.statusCode;
        } on IOException {
          return 'cut off';
        }
      }();
      expect(outcome, anyOf(400, 'cut off'));
    });
  });

  group('health', () {
    test('GET /health answers 200 while the database answers', () async {
      final answer = await anonymous.raw('GET', '/health');
      expect(answer.status, 200);
      expect(answer.text, 'ok');
      expect((await anonymous.raw('POST', '/health')).status, 405);
    });
  });
}
