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

  group('the wait for the reply once the transport reports the body sent '
      '(#309)', () {
    test('a transport that reads the whole body at once — the way a browser '
        "fetch does — but reports the network's real progress is not "
        'aborted by a reply slower than the stall timeout', () async {
      final fallback = storage.transport;
      final bufferingButHonest = DwMemoryStorageTransport((put) async {
        // Like `fetch`/`XMLHttpRequest`: the body is read into memory in
        // one go, instantly. Unlike the bug this transport reports the
        // real send separately, so that read is never mistaken for it.
        put.reportSent(put.byteSize);
        // Storage answers slower than the stall timeout — plausible for
        // a large upload — but well inside the ticket's life.
        await Future<void>.delayed(const Duration(milliseconds: 150));
        return fallback.put(put);
      });
      final client2 = await connect(
        transport: bufferingButHonest,
        options: const DwClientOptions(
          callTimeout: Duration(milliseconds: 50),
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
      expect(
        storage.puts,
        1,
        reason: 'no retry: the wait for the reply was not read as a stall',
      );
    });

    test('progress reported by the transport, slower than the stall timeout '
        'but in time, keeps re-arming the watchdog', () async {
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
    });

    test('a transport that reads the whole body but never reports it sent '
        'still gives up on a genuine stall at the plain stall timeout, not '
        "the ticket's — a body read is not proof a network took it", () async {
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
          // Storage's ticket lasts 15 minutes by default: if reading the
          // body were mistaken for reporting it sent, this would hang
          // until then instead of aborting within the stall timeout.
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
