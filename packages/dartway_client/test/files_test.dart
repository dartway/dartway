import 'dart:async';
import 'dart:typed_data';

import 'package:dartway_client/dartway_client.dart';
import 'package:dartway_client/testing.dart';
import 'package:test/test.dart';

import 'support.dart';

enum Upload with DwUploadPurpose { avatar }

/// `client.files` against the fake server and the fake storage: the three
/// steps, progress, retries and every way an upload ends. The same flow
/// against a real server and MinIO is in dartway_core_server's
/// `files_client_e2e_test.dart`.
void main() {
  late DwFakeServer server;
  late DwFakeStorage storage;
  late DwAppClient client;

  Future<DwAppClient> connect({
    DwClientOptions options = dwFakeClientOptions,
    DwStorageTransport? transport,
    bool signedIn = true,
  }) async {
    final connected = server.newClient(
      tokenStore: DwMemoryTokenStore(signedIn ? alice : null),
      storageTransport: transport ?? storage.transport,
      options: options,
    );
    addTearDown(connected.stop);
    await connected.start();
    return connected;
  }

  setUp(() async {
    server = DwFakeServer(protocol: roomsProtocol)
      ..registerToken(alice.token, alice.id);
    storage = DwFakeStorage(server);
    client = await connect();
  });

  tearDown(() => expect(server.errors, isEmpty));

  Uint8List bytes(int size) =>
      Uint8List.fromList(List.generate(size, (i) => i & 0xff));

  Future<DwCallResult<DwStoredFile>> upload(
    DwUploadSource source, {
    void Function(int, int)? onProgress,
    String type = 'image/png',
  }) => client.files.upload(
    Upload.avatar,
    source,
    fileName: 'me.png',
    contentType: type,
    onProgress: onProgress,
  );

  test('starts, puts the bytes to storage and finishes', () async {
    final body = bytes(200 * 1024);
    final result = await upload(DwUploadSource.bytes(body));

    final file = result.valueOrNull!;
    expect(file.fileName, 'me.png');
    expect(file.byteSize, body.length);
    expect(storage.objects[file.id]!.bytes, body);
    expect(storage.puts, 1);
    expect(server.calls.map((call) => call.wireName), [
      'DwStartUpload',
      'DwFinishUpload',
    ]);
  });

  test('reports progress from zero to the total, in order', () async {
    storage.chunkDelay = const Duration(milliseconds: 20);
    final progress = <(int, int)>[];
    await upload(
      DwUploadSource.bytes(bytes(300 * 1024)),
      onProgress: (sent, total) => progress.add((sent, total)),
    );
    expect(progress.first, (0, 300 * 1024));
    expect(progress.last, (300 * 1024, 300 * 1024));
    expect(progress.length, greaterThan(2), reason: 'something in between');
    for (var i = 1; i < progress.length; i++) {
      expect(progress[i].$1, greaterThanOrEqualTo(progress[i - 1].$1));
    }
  });

  test('a stream source is opened again for a retry', () async {
    var opened = 0;
    final body = bytes(1000);
    storage.failPuts = 2;
    final result = await upload(
      DwUploadSource.stream(() {
        opened++;
        return Stream.fromIterable([body.sublist(0, 400), body.sublist(400)]);
      }, byteSize: body.length),
    );
    expect(result.isOk, isTrue);
    expect(opened, 3);
    expect(storage.puts, 3);
    expect(storage.objects.values.single.bytes, body);
  });

  test('an upload that arrived with its answer lost is finished, not sent '
      'twice', () async {
    storage.loseAnswers = 1;
    final progress = <int>[];
    final result = await upload(
      DwUploadSource.bytes(bytes(10)),
      onProgress: (sent, total) => progress.add(sent),
    );
    expect(result.isOk, isTrue);
    expect(storage.puts, 2, reason: 'the retry met 412');
    expect(storage.objects, hasLength(1));
    expect(progress.last, 10);
  });

  test('transient answers are retried; a refusal is not', () async {
    storage.answerStatuses.addAll([503, 500]);
    expect((await upload(DwUploadSource.bytes(bytes(5)))).isOk, isTrue);
    expect(storage.puts, 3);

    storage.answerStatuses.add(403);
    await expectLater(
      upload(DwUploadSource.bytes(bytes(5))),
      throwsA(
        isA<DwUploadException>()
            .having((e) => e.failure, 'failure', DwUploadFailure.rejected)
            .having((e) => e.status, 'status', 403),
      ),
    );
    expect(storage.puts, 4);
  });

  test(
    'the fake storage holds a put to its ticket, as a signature does',
    () async {
      final ticket = (await client.command(
        DwStartUpload(
          purpose: Upload.avatar,
          fileName: 'x.png',
          contentType: 'image/png',
          byteSize: 5,
        ),
      )).valueOrNull!;
      final reply = await storage.transport.put(
        DwStoragePut(
          url: Uri.parse(ticket.uploadUrl),
          headers: {...ticket.headers, 'content-type': 'image/gif'},
          byteSize: 5,
          body: Stream.value(bytes(5)),
          abort: Completer<void>().future,
        ),
      );
      expect(reply.status, 403);
      expect(reply.body, contains('SignatureDoesNotMatch'));
      expect(storage.objects, isEmpty);
    },
  );

  test(
    'network failures until the ticket expires end as unreachable',
    () async {
      storage
        ..ticketLifetime = const Duration(milliseconds: 150)
        ..failPuts = 1 << 20;
      await expectLater(
        upload(DwUploadSource.bytes(bytes(5))),
        throwsA(
          isA<DwUploadException>()
              .having((e) => e.failure, 'failure', DwUploadFailure.unreachable)
              .having(
                (e) => e.lastError,
                'lastError',
                isA<DwFakeNetworkException>(),
              ),
        ),
      );
      expect(storage.puts, greaterThan(1));
      expect(
        server.calls.map((call) => call.wireName),
        isNot(contains('DwFinishUpload')),
      );
    },
  );

  test('a stalled put is abandoned and retried', () async {
    var stalled = true;
    final fallback = storage.transport;
    final stalling = DwMemoryStorageTransport((put) async {
      if (stalled) {
        stalled = false;
        // Never reads the body, never answers — until the client aborts.
        await put.abort;
        throw StateError('aborted');
      }
      return fallback.put(put);
    });
    final stallingClient = await connect(
      transport: stalling,
      options: const DwClientOptions(
        callTimeout: Duration(milliseconds: 100),
        retryDelay: Duration(milliseconds: 1),
        maxRetryDelay: Duration(milliseconds: 5),
        releaseDelay: Duration.zero,
        liveIdleDelay: Duration.zero,
      ),
    );
    final result = await stallingClient.files.upload(
      Upload.avatar,
      DwUploadSource.bytes(bytes(5)),
      fileName: 'a.png',
      contentType: 'image/png',
    );
    expect(result.isOk, isTrue);
    expect(storage.puts, 1);
  });

  group('progress and the stall watchdog, with and without a transport '
      'reporting real progress (#309)', () {
    /// [put] with [reportSent] replaced, so a wrapper can watch or silence
    /// it without touching anything else — `storage.transport` still reads
    /// `body` and validates the ticket exactly as normal.
    DwStoragePut withReportSent(
      DwStoragePut put,
      void Function(int sentBytes) reportSent,
    ) => DwStoragePut(
      url: put.url,
      headers: put.headers,
      byteSize: put.byteSize,
      body: put.body,
      abort: put.abort,
      reportSent: reportSent,
    );

    test('a transport that never calls reportSent gets progress from reading '
        'the body, exactly as before this existed', () async {
      storage.chunkDelay = const Duration(milliseconds: 5);
      final progress = <(int, int)>[];
      final neverReports = DwMemoryStorageTransport(
        (put) => storage.transport.put(withReportSent(put, (_) {})),
      );
      final client2 = await connect(transport: neverReports);
      final result = await client2.files.upload(
        Upload.avatar,
        DwUploadSource.bytes(bytes(300 * 1024)),
        fileName: 'a.png',
        contentType: 'image/png',
        onProgress: (sent, total) => progress.add((sent, total)),
      );
      expect(result.isOk, isTrue);
      expect(progress.first, (0, 300 * 1024));
      expect(progress.last, (300 * 1024, 300 * 1024));
      expect(
        progress.length,
        greaterThan(2),
        reason: 'reading the body still reports something in between',
      );
    });

    test('once a transport reports sent bytes at all, reading the body no '
        'longer drives progress on its own', () async {
      storage.chunkDelay = const Duration(milliseconds: 5);
      final progress = <(int, int)>[];
      // `DwFakeStorage` itself calls `reportSent` on every chunk it reads
      // (like `DwHttpStorageTransport`); this wrapper lets through only
      // the first of those calls, and reports half the body sent — enough
      // to flip the switch and clear the 1%-of-total throttle
      // (`_Attempt.reportSent`) with one clean, observable call, without
      // claiming to track the whole transfer.
      var reportedOnce = false;
      final reportsOnceEarly = DwMemoryStorageTransport(
        (put) => storage.transport.put(
          withReportSent(put, (_) {
            if (reportedOnce) return;
            reportedOnce = true;
            put.reportSent(put.byteSize ~/ 2);
          }),
        ),
      );
      final client2 = await connect(transport: reportsOnceEarly);
      final result = await client2.files.upload(
        Upload.avatar,
        DwUploadSource.bytes(bytes(300 * 1024)),
        fileName: 'a.png',
        contentType: 'image/png',
        onProgress: (sent, total) => progress.add((sent, total)),
      );
      expect(result.isOk, isTrue);
      // Not the dozens of (n, total) pairs a 300 KB body read in 64 KB
      // chunks with a 5 ms delay each would otherwise produce: the single
      // early report silenced them, and only the client's own final
      // `(total, total)` call (files.dart, on a successful reply) follows.
      expect(progress, [
        (0, 300 * 1024),
        (150 * 1024, 300 * 1024),
        (300 * 1024, 300 * 1024),
      ]);
    });

    test('a transport that reads the whole body before calling reportSent at '
        'all, the way XMLHttpRequest has to, still reports its own real '
        'progress in between — not the read, jumped to 100%, then silence '
        'until the end', () async {
      final progress = <(int, int)>[];
      final readsFirstLikeXhr = DwMemoryStorageTransport((put) async {
        // The XHR pattern (`DwXhrStorageTransport.put`): `reportSent(0)`
        // before reading anything, so the read that follows never counts
        // as progress on its own; then the whole body is read into
        // memory (`_readAll`) before anything is reported for real.
        put.reportSent(0);
        final builder = BytesBuilder(copy: false);
        await for (final chunk in put.body) {
          builder.add(chunk);
        }
        final read = builder.takeBytes();
        // Real progress, in a few steps — `upload.onprogress` events.
        // Not 100%: the client's own final `(total, total)` call, on a
        // successful reply, already covers that (files.dart).
        for (final fraction in [0.25, 0.5, 0.75]) {
          put.reportSent((put.byteSize * fraction).round());
        }
        // Storage's own bookkeeping, bypassed here since this transport
        // does not delegate to `DwFakeStorage`'s own body-reading `_put`
        // (which would try to read `put.body` a second time).
        final id = int.parse(put.url.pathSegments.last);
        storage.objects[id] = DwFakeObject(read, put.headers['content-type']!);
        return const DwStorageReply(status: 200);
      });
      final client2 = await connect(transport: readsFirstLikeXhr);
      const total = 400 * 1024;
      final result = await client2.files.upload(
        Upload.avatar,
        DwUploadSource.bytes(bytes(total)),
        fileName: 'a.png',
        contentType: 'image/png',
        onProgress: (sent, total) => progress.add((sent, total)),
      );
      expect(result.isOk, isTrue);
      expect(progress, [
        (0, total),
        (total ~/ 4, total),
        (total ~/ 2, total),
        (total * 3 ~/ 4, total),
        (total, total),
      ]);
    });

    test(
      'a source slower than the stall timeout, read by a transport that '
      'never reports progress, still keeps the watchdog alive on its own',
      () async {
        Stream<List<int>> trickle() async* {
          yield bytes(2);
          await Future<void>.delayed(const Duration(milliseconds: 40));
          yield bytes(2);
          await Future<void>.delayed(const Duration(milliseconds: 40));
          yield bytes(2);
        }

        var opens = 0;
        final source = DwUploadSource.stream(() {
          opens++;
          return trickle();
        }, byteSize: 6);
        final neverReports = DwMemoryStorageTransport(
          (put) => storage.transport.put(withReportSent(put, (_) {})),
        );
        final client2 = await connect(
          transport: neverReports,
          options: const DwClientOptions(
            callTimeout: Duration(milliseconds: 60),
            retryDelay: Duration(milliseconds: 1),
            maxRetryDelay: Duration(milliseconds: 5),
            releaseDelay: Duration.zero,
            liveIdleDelay: Duration.zero,
          ),
        );
        final result = await client2.files.upload(
          Upload.avatar,
          source,
          fileName: 'a.png',
          contentType: 'image/png',
        );
        expect(result.isOk, isTrue);
        expect(
          opens,
          1,
          reason:
              'no retry: two 40 ms gaps under the 60 ms stall timeout, '
              'each read re-arming it, are not a stall — only their 80 ms '
              'sum would be, without the re-arm',
        );
      },
    );

    test(
      'incremental progress from the transport, each report under the '
      'stall timeout but together over it, keeps re-arming the watchdog',
      () async {
        final fallback = storage.transport;
        final trickling = DwMemoryStorageTransport((put) async {
          // Real network progress in two steps, each under the stall
          // timeout, together well over it — and nothing else touches the
          // watchdog: `put.body` is read only at the very end, by
          // `fallback.put`.
          await Future<void>.delayed(const Duration(milliseconds: 60));
          put.reportSent(put.byteSize ~/ 2);
          await Future<void>.delayed(const Duration(milliseconds: 60));
          put.reportSent(put.byteSize);
          return fallback.put(put);
        });
        final client2 = await connect(
          transport: trickling,
          options: const DwClientOptions(
            callTimeout: Duration(milliseconds: 100),
            retryDelay: Duration(milliseconds: 1),
            maxRetryDelay: Duration(milliseconds: 5),
            releaseDelay: Duration.zero,
            liveIdleDelay: Duration.zero,
          ),
        );
        final result = await client2.files.upload(
          Upload.avatar,
          DwUploadSource.bytes(bytes(5)),
          fileName: 'a.png',
          contentType: 'image/png',
        );
        expect(result.isOk, isTrue);
        expect(storage.puts, 1);
      },
    );

    test('a transport that reads the whole body but never reports it sent '
        'still gives up on a genuine, silent stall at the plain stall '
        'timeout', () async {
      var stalled = true;
      final fallback = storage.transport;
      final silentlyBuffering = DwMemoryStorageTransport((put) async {
        if (stalled) {
          stalled = false;
          // Reads (and so validates) the whole body, same as a real
          // transport would, but never calls `reportSent` — an old
          // transport that never adopted it, or one that genuinely
          // cannot tell. Then never answers — until the client aborts.
          await put.body.drain<void>();
          await put.abort;
          throw StateError('aborted');
        }
        // The retry's own attempt, untouched: `fallback` reads its body
        // itself.
        return fallback.put(put);
      });
      final client2 = await connect(
        transport: silentlyBuffering,
        options: const DwClientOptions(
          callTimeout: Duration(milliseconds: 100),
          retryDelay: Duration(milliseconds: 1),
          maxRetryDelay: Duration(milliseconds: 5),
          releaseDelay: Duration.zero,
          liveIdleDelay: Duration.zero,
        ),
      );
      final result = await client2.files
          .upload(
            Upload.avatar,
            DwUploadSource.bytes(bytes(5)),
            fileName: 'a.png',
            contentType: 'image/png',
          )
          .timeout(const Duration(seconds: 5));
      expect(result.isOk, isTrue);
      expect(storage.puts, 1);
    });
  });

  test('refusals of the start and of the finish are results, and nothing is '
      'put after a refused start', () async {
    storage.refuseStart = (command) => DwCallRefusal(
      DwUploadRefusal.tooLarge,
      field: 'byteSize',
      params: {'maxBytes': 4},
    );
    final tooLarge = await upload(DwUploadSource.bytes(bytes(5)));
    expect(
      (tooLarge as DwCallRefused).refusal.isCode(DwUploadRefusal.tooLarge),
      isTrue,
    );
    expect(storage.puts, 0);

    storage.refuseStart = null;
    storage.answerStatuses.add(200); // "stored", yet nothing is
    final missing = await upload(DwUploadSource.bytes(bytes(5)));
    expect(
      (missing as DwCallRefused).refusal.isCode(DwUploadRefusal.missing),
      isTrue,
    );
  });

  test('input that does not validate is refused without a call', () async {
    final result = await client.files.upload(
      Upload.avatar,
      DwUploadSource.bytes(bytes(5)),
      fileName: 'a/b.png',
      contentType: 'image/png',
    );
    expect((result as DwCallRefused).refusal.field, 'fileName');
    expect(server.calls, isEmpty);
  });

  test('signed out, the start answers not authenticated', () async {
    final anonymous = await connect(signedIn: false);
    final result = await anonymous.files.upload(
      Upload.avatar,
      DwUploadSource.bytes(bytes(5)),
      fileName: 'a.png',
      contentType: 'image/png',
    );
    expect(result, isA<DwNotAuthenticated<DwStoredFile>>());
  });

  test('a source that yields another length than it declared is the '
      "caller's bug, thrown and not retried", () async {
    await expectLater(
      upload(DwUploadSource.stream(() => Stream.value(bytes(4)), byteSize: 5)),
      throwsStateError,
    );
    await expectLater(
      upload(DwUploadSource.stream(() => Stream.value(bytes(6)), byteSize: 5)),
      throwsStateError,
    );
    expect(storage.puts, 2);
    expect(storage.objects, isEmpty);
  });

  test('stopping the client ends an upload in flight', () async {
    storage.chunkDelay = const Duration(milliseconds: 50);
    final pending = upload(DwUploadSource.bytes(bytes(300 * 1024)));
    await Future<void>.delayed(const Duration(milliseconds: 60));
    unawaited(client.stop());
    await expectLater(pending, throwsA(isA<DwClientStoppedException>()));
  });

  group('cancel (#284)', () {
    test('aborts a put in flight and sends no confirmation', () async {
      storage.chunkDelay = const Duration(milliseconds: 50);
      final cancel = Completer<void>();
      final pending = client.files.upload(
        Upload.avatar,
        DwUploadSource.bytes(bytes(300 * 1024)),
        fileName: 'big.png',
        contentType: 'image/png',
        cancel: cancel.future,
      );
      await Future<void>.delayed(const Duration(milliseconds: 60));
      cancel.complete();
      await expectLater(pending, throwsA(isA<DwUploadCancelledException>()));
      expect(server.calls.map((call) => call.wireName), ['DwStartUpload']);
      expect(storage.objects, isEmpty);
    });

    test('before the ticket arrives, puts nothing', () async {
      final cancel = Completer<void>()..complete();
      await expectLater(
        client.files.upload(
          Upload.avatar,
          DwUploadSource.bytes(bytes(5)),
          fileName: 'a.png',
          contentType: 'image/png',
          cancel: cancel.future,
        ),
        throwsA(isA<DwUploadCancelledException>()),
      );
      expect(storage.puts, 0);
      expect(server.calls.map((call) => call.wireName), ['DwStartUpload']);
    });

    test('ends the wait before a retry', () async {
      final failing = DwMemoryStorageTransport(
        (put) async => const DwStorageReply(status: 503, body: ''),
      );
      final retrying = await connect(
        transport: failing,
        options: const DwClientOptions(
          retryDelay: Duration(seconds: 30),
          maxRetryDelay: Duration(seconds: 30),
          releaseDelay: Duration.zero,
          liveIdleDelay: Duration.zero,
        ),
      );
      final cancel = Completer<void>();
      final pending = retrying.files.upload(
        Upload.avatar,
        DwUploadSource.bytes(bytes(5)),
        fileName: 'a.png',
        contentType: 'image/png',
        cancel: cancel.future,
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      cancel.complete();
      await expectLater(
        pending.timeout(const Duration(seconds: 5)),
        throwsA(isA<DwUploadCancelledException>()),
      );
    });

    test('after the file is confirmed, changes nothing', () async {
      final cancel = Completer<void>();
      final result = await client.files.upload(
        Upload.avatar,
        DwUploadSource.bytes(bytes(5)),
        fileName: 'a.png',
        contentType: 'image/png',
        cancel: cancel.future,
      );
      cancel.complete();
      expect(result.isOk, isTrue);
    });
  });

  test('getLink reads a link for a confirmed file', () async {
    final file = (await upload(DwUploadSource.bytes(bytes(5)))).valueOrNull!;
    final link = (await client.files.getLink(file.id)).valueOrNull!;
    expect(link.id, file.id);
    expect(link.expiresAt, isNotNull);
    expect((await client.files.getLink(999)), isA<DwCallRefused<DwFileLink>>());
  });
}
