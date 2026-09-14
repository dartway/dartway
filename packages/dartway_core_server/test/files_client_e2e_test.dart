import 'dart:async';
import 'dart:typed_data';

import 'package:test/test.dart';

import 'support/files.dart';
import 'support/test_app.dart';

/// The real client uploading through the real server to real storage:
/// `client.files` as an app calls it, with nothing faked between the three.
void main() {
  late TestStorage storage;
  setUpAll(() async => storage = await TestStorage.create());
  tearDownAll(() async => storage.drop());
  final harness = useFilesHarness(() => storage);

  Future<DwAppClient> signedInClient(
    String email, {
    DwStorageTransport? storageTransport,
  }) async {
    final client = await harness().server.connectClient(
      storageTransport: storageTransport,
    );
    addTearDown(client.stop);
    final ticket = await client.command(
      DwRequestCode(kind: DwIdentifierKind.email, identifier: email),
    );
    final verified = await client.command(
      DwVerifyCode(
        ticketId: ticket.valueOrNull!.id,
        code: harness().app.delivered[email]!,
      ),
    );
    await client.signIn(verified.valueOrNull!);
    return client;
  }

  Uint8List bytes(int size, [int seed = 3]) =>
      Uint8List.fromList(bytesOf(size, seed));

  test(
    'a public upload: progress to the end, then a URL anyone reads',
    () async {
      final client = await signedInClient('e2e-files-public@example.com');
      final body = bytes(60);
      final progress = <(int, int)>[];
      final result = await client.files.upload(
        TestUpload.avatar,
        DwUploadSource.bytes(body),
        fileName: 'me.png',
        contentType: 'image/png',
        onProgress: (sent, total) => progress.add((sent, total)),
      );
      final file = result.valueOrNull!;
      expect(progress.first, (0, 60));
      expect(progress.last, (60, 60));
      expect(file.url, isNotNull);
      expect((await getUrl(file.url!)).bytes, body);
    },
  );

  test('a private upload of a stream, read back through its link', () async {
    final client = await signedInClient('e2e-files-private@example.com');
    final body = bytes(700 * 1024);
    final progress = <int>[];
    final result = await client.files.upload(
      TestUpload.document,
      DwUploadSource.stream(
        () => Stream.fromIterable([
          for (var i = 0; i < body.length; i += 100 * 1024)
            body.sublist(
              i,
              i + 100 * 1024 > body.length ? body.length : i + 100 * 1024,
            ),
        ]),
        byteSize: body.length,
      ),
      fileName: 'report.txt',
      contentType: 'text/plain',
      onProgress: (sent, total) => progress.add(sent),
    );
    final file = result.valueOrNull!;
    expect(file.url, isNull);
    expect(progress.last, body.length);
    for (var i = 1; i < progress.length; i++) {
      expect(progress[i], greaterThanOrEqualTo(progress[i - 1]));
    }

    final link = (await client.files.getLink(file.id)).valueOrNull!;
    expect((await getUrl(link.url)).bytes, body);
  });

  test(
    'a put that fails on the network is retried within the ticket',
    () async {
      final real = DwHttpStorageTransport();
      addTearDown(real.close);
      var attempts = 0;
      final client = await signedInClient(
        'e2e-files-retry@example.com',
        storageTransport: DwMemoryStorageTransport((put) async {
          attempts++;
          if (attempts == 1) throw const SocketLikeFailure();
          return real.put(put);
        }),
      );
      final progress = <int>[];
      final result = await client.files.upload(
        TestUpload.avatar,
        DwUploadSource.bytes(bytes(20)),
        fileName: 'a.png',
        contentType: 'image/png',
        onProgress: (sent, total) => progress.add(sent),
      );
      expect(result.isOk, isTrue);
      expect(attempts, 2);
      expect(progress.last, 20);
    },
  );

  test('a put whose answer is lost is recognised by storage on the retry, '
      'and confirmed', () async {
    final real = DwHttpStorageTransport();
    addTearDown(real.close);
    final statuses = <int>[];
    var lost = false;
    final client = await signedInClient(
      'e2e-files-lost@example.com',
      storageTransport: DwMemoryStorageTransport((put) async {
        final reply = await real.put(put);
        statuses.add(reply.status);
        if (!lost) {
          lost = true;
          throw const SocketLikeFailure();
        }
        return reply;
      }),
    );
    final body = bytes(30);
    final result = await client.files.upload(
      TestUpload.avatar,
      DwUploadSource.bytes(body),
      fileName: 'a.png',
      contentType: 'image/png',
    );
    expect(statuses, [200, 412]);
    expect((await getUrl(result.valueOrNull!.url!)).bytes, body);
  });

  test('a refused start puts nothing; a put storage refuses is a typed '
      'rejection', () async {
    final real = DwHttpStorageTransport();
    addTearDown(real.close);
    var puts = 0;
    var tamper = false;
    final client = await signedInClient(
      'e2e-files-refused@example.com',
      storageTransport: DwMemoryStorageTransport((put) {
        puts++;
        return real.put(
          tamper
              ? DwStoragePut(
                  url: put.url,
                  headers: {...put.headers, 'content-type': 'image/jpeg'},
                  byteSize: put.byteSize,
                  body: put.body,
                  abort: put.abort,
                )
              : put,
        );
      }),
    );

    final tooLarge = await client.files.upload(
      TestUpload.avatar,
      DwUploadSource.bytes(bytes(65)),
      fileName: 'a.png',
      contentType: 'image/png',
    );
    expect(
      (tooLarge as DwCallRefused).refusal.isCode(DwUploadRefusal.tooLarge),
      isTrue,
    );
    expect(puts, 0);

    tamper = true;
    await expectLater(
      client.files.upload(
        TestUpload.avatar,
        DwUploadSource.bytes(bytes(10)),
        fileName: 'a.png',
        contentType: 'image/png',
      ),
      throwsA(
        isA<DwUploadException>()
            .having((e) => e.failure, 'failure', DwUploadFailure.rejected)
            .having((e) => e.status, 'status', 403)
            .having((e) => e.storageCode, 'code', 'SignatureDoesNotMatch'),
      ),
    );
    expect(puts, 1);
  });
}

/// A network failure, as a transport throws it.
final class SocketLikeFailure implements Exception {
  const SocketLikeFailure();
}
