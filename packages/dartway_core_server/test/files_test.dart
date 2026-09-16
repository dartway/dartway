import 'dart:async';

import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:test/test.dart';

import 'support/files.dart';
import 'support/test_app.dart';

/// File uploads against a real S3-compatible storage and a real database:
/// the server issues tickets, storage enforces them, the server confirms
/// what storage holds, and cleanup removes what was never finished.
void main() {
  late TestStorage storage;
  setUpAll(() async => storage = await TestStorage.create());
  tearDownAll(() async => storage.drop());

  /// Read rule of the test project: owners, and account ids listed here.
  final readers = <int>{};
  final harness = useFilesHarness(
    () => storage,
    declaration: (config) => testStorage(
      config,
      maxPendingUploads: 50,
      canRead: (ctx, file) async =>
          file.accountId == ctx.accountId || readers.contains(ctx.accountId),
    ),
  );

  late DwTestCaller alice;
  late DwAuthSession aliceSession;
  late DwTestCaller bob;
  late DwAuthSession bobSession;
  late DwTestCaller anonymous;
  setUpAll(() async {
    (alice, aliceSession) = await harness().signedIn('files-alice@example.com');
    (bob, bobSession) = await harness().signedIn('files-bob@example.com');
    anonymous = harness().caller();
  });

  DwStartUpload start(
    DwUploadPurpose purpose, {
    int size = 16,
    String type = 'image/png',
    String name = 'photo.png',
  }) => DwStartUpload(
    purpose: purpose,
    fileName: name,
    contentType: type,
    byteSize: size,
  );

  Future<DwUploadTicket> ticketFor(
    DwTestCaller caller,
    DwStartUpload command,
  ) async => (await caller.call(command)).value(command);

  Future<DwResultRow> rowOf(int id) async => (await harness().db.query(
    'SELECT * FROM dw_stored_file WHERE id = @id',
    params: {'id': id},
  )).single;

  Future<DwTestAnswer> finish(DwTestCaller caller, int ticketId) =>
      caller.call(DwFinishUpload(ticketId: ticketId));

  /// A whole upload by [caller]: start, put, finish.
  Future<DwStoredFile> upload(
    DwTestCaller caller,
    DwUploadPurpose purpose, {
    List<int>? bytes,
    String type = 'image/png',
    String name = 'photo.png',
  }) async {
    final body = bytes ?? bytesOf(16);
    final ticket = await ticketFor(
      caller,
      start(purpose, size: body.length, type: type, name: name),
    );
    final put = await putToTicket(ticket, body);
    expect(put.status, 200, reason: put.body);
    final answer = await finish(caller, ticket.id);
    return answer.value(DwFinishUpload(ticketId: ticket.id));
  }

  group('a public upload', () {
    test('goes to storage by a presigned PUT and is confirmed with a public '
        'URL anyone can read', () async {
      final bytes = bytesOf(40);
      final command = start(TestUpload.avatar, size: 40, name: 'Me (1).PNG');
      final ticket = await ticketFor(alice, command);

      expect(ticket.headers, {
        'content-type': 'image/png',
        'if-none-match': '*',
      });
      expect(
        ticket.expiresAt.difference(DateTime.now()).inSeconds,
        inInclusiveRange(290, 300),
      );
      final pending = await rowOf(ticket.id);
      expect(pending['confirmed_at'], isNull);
      expect(pending['account_id'], aliceSession.id);

      expect((await putToTicket(ticket, bytes)).status, 200);
      final file = (await finish(
        alice,
        ticket.id,
      )).value(DwFinishUpload(ticketId: ticket.id));

      expect(file.id, ticket.id);
      expect(file.purpose, 'avatar');
      expect(file.fileName, 'Me (1).PNG');
      expect(file.contentType, 'image/png');
      expect(file.byteSize, 40);
      final key = pending.get<String>('object_key');
      expect(pending['bucket'], storage.publicBucket);
      expect(file.url, '${storage.config.publicBaseUrl}/$key');
      expect(Uri.parse(ticket.uploadUrl).path, '/${storage.publicBucket}/$key');
      expect((await rowOf(ticket.id))['confirmed_at'], isNotNull);

      final read = await getUrl(file.url!);
      expect(read.status, 200);
      expect(read.bytes, bytes);
      expect(read.headers.contentType?.mimeType, 'image/png');
    });

    test('its key is the server\'s: purpose, account, 192 random bits and '
        'the extension of its type — never the client\'s name', () async {
      final keys = <String>{};
      for (var i = 0; i < 20; i++) {
        final ticket = await ticketFor(
          alice,
          start(
            TestUpload.avatar,
            type: i.isEven ? 'image/png' : 'image/jpeg',
            name: 'avatar.exe',
          ),
        );
        final key = (await rowOf(ticket.id)).get<String>('object_key');
        expect(
          key,
          matches(
            RegExp(
              '^avatar/${aliceSession.id}/[A-Za-z0-9_-]{32}\\.'
              '${i.isEven ? 'png' : 'jpg'}\$',
            ),
          ),
        );
        expect(key, isNot(contains('exe')));
        keys.add(key);
      }
      expect(keys, hasLength(20), reason: 'no two keys collide');
      // The upload URL is for that key and nothing else.
      final ticket = await ticketFor(alice, start(TestUpload.avatar));
      final key = (await rowOf(ticket.id)).get<String>('object_key');
      expect(Uri.parse(ticket.uploadUrl).path, '/${storage.publicBucket}/$key');
    });
  });

  group('a private upload', () {
    test('has no URL, is unreadable by its storage path, and is read through '
        'a short link the read rule guards', () async {
      final bytes = 'a private document'.codeUnits;
      final file = await upload(
        alice,
        TestUpload.document,
        bytes: bytes,
        type: 'text/plain',
        name: 'договор "итог".txt',
      );
      expect(file.url, isNull);

      final row = await rowOf(file.id);
      final key = row.get<String>('object_key');
      expect(row['bucket'], storage.privateBucket);
      expect(await storage.keys(storage.privateBucket), contains(key));
      expect(await storage.keys(storage.publicBucket), isNot(contains(key)));
      final direct = await getUrl(
        '${storage.config.endpoint}/${storage.privateBucket}/$key',
      );
      expect(direct.status, 403, reason: 'the private bucket is not public');

      final request = DwGetFileLink(fileId: file.id);
      final link = (await alice.call(request)).value(request);
      expect(link.id, file.id);
      expect(
        link.expiresAt!.difference(DateTime.now()).inSeconds,
        inInclusiveRange(590, 600),
      );
      expect(
        Uri.parse(link.url).path,
        '/${storage.privateBucket}/$key',
        reason: 'the link reads the private bucket',
      );
      final read = await getUrl(link.url);
      expect(read.status, 200);
      expect(read.bytes, bytes);
      expect(
        read.headers.value('content-disposition'),
        "inline; filename=\"_______ ______.txt\"; filename*=UTF-8''"
        '%D0%B4%D0%BE%D0%B3%D0%BE%D0%B2%D0%BE%D1%80%20%22%D0%B8%D1%82%D0%BE%D0%B3%22.txt',
      );

      final bobAnswer = await bob.call(request);
      expect(bobAnswer.status, 403);
      expect(bobAnswer.refusal.isCode(DwCoreRefusal.forbidden), isTrue);
      expect((await anonymous.call(request)).status, 401);

      readers.add(bobSession.id);
      addTearDown(() => readers.remove(bobSession.id));
      final allowed = (await bob.call(request)).value(request);
      expect((await getUrl(allowed.url)).bytes, bytes);
    });

    test('a public file\'s link is its public URL, for anyone', () async {
      final file = await upload(alice, TestUpload.avatar);
      final request = DwGetFileLink(fileId: file.id);
      final link = (await anonymous.call(request)).value(request);
      expect(link.url, file.url);
      expect(link.expiresAt, isNull);
    });

    test('an unfinished or absent file has no link', () async {
      final ticket = await ticketFor(alice, start(TestUpload.avatar));
      for (final id in [ticket.id, 1 << 40]) {
        final answer = await alice.call(DwGetFileLink(fileId: id));
        expect(answer.status, 404);
        expect(answer.refusal.isCode(DwCoreRefusal.notFound), isTrue);
      }
    });
  });

  group('starting is refused', () {
    Future<void> refused(
      DwTestCaller caller,
      DwStartUpload command,
      int status,
      DwRefusalCode code, {
      String? field,
      Map<String, String> params = const {},
    }) async {
      final before = (await harness().db.query(
        'SELECT count(*) AS n FROM dw_stored_file',
      )).single.get<int>('n');
      final answer = await caller.call(command);
      expect(answer.status, status, reason: answer.text);
      expect(answer.refusal.code, code.code);
      expect(answer.refusal.field, field);
      expect(answer.refusal.params, params);
      final after = (await harness().db.query(
        'SELECT count(*) AS n FROM dw_stored_file',
      )).single.get<int>('n');
      expect(after, before, reason: 'a refused start reserves nothing');
    }

    test('for a purpose without a rule', () async {
      await refused(
        alice,
        start(TestUpload.unruled),
        422,
        DwUploadRefusal.purposeUnknown,
        field: 'purpose',
      );
    });

    test('above the size limit, naming the limit', () async {
      await refused(
        alice,
        start(TestUpload.avatar, size: 65),
        422,
        DwUploadRefusal.tooLarge,
        field: 'byteSize',
        params: {'maxBytes': '64'},
      );
    });

    test(
      'for a type the purpose does not take, naming the ones it does',
      () async {
        await refused(
          alice,
          start(TestUpload.avatar, type: 'image/svg+xml'),
          422,
          DwUploadRefusal.typeRejected,
          field: 'contentType',
          params: {'allowed': 'image/jpeg,image/png'},
        );
      },
    );

    test('when the rule says the caller may not upload', () async {
      await refused(
        alice,
        start(TestUpload.locked, type: 'text/plain'),
        403,
        DwCoreRefusal.forbidden,
      );
    });

    test('anonymously', () async {
      final answer = await anonymous.call(start(TestUpload.avatar));
      expect(answer.status, 401);
    });

    test('for input that does not validate', () async {
      for (final (command, field) in [
        (start(TestUpload.avatar, name: '../../etc/passwd'), 'fileName'),
        (start(TestUpload.avatar, name: ''), 'fileName'),
        (start(TestUpload.avatar, size: 0), 'byteSize'),
        (
          const DwStartUpload.raw(
            purpose: 'avatar',
            fileName: 'x.png',
            contentType: 'image/png; charset=binary',
            byteSize: 3,
          ),
          'contentType',
        ),
      ]) {
        await refused(alice, command, 422, DwCoreRefusal.invalid, field: field);
      }
    });
  });

  group('storage enforces the ticket', () {
    test('a body longer or shorter than declared is refused', () async {
      final ticket = await ticketFor(alice, start(TestUpload.avatar, size: 16));
      expect((await putToTicket(ticket, bytesOf(17))).status, 403);
      expect((await putToTicket(ticket, bytesOf(15))).status, 403);
      expect(
        await storage.keys(storage.publicBucket),
        isNot(contains(await _keyOf(harness, ticket))),
      );
    });

    test('another content type is refused', () async {
      final ticket = await ticketFor(alice, start(TestUpload.avatar));
      final put = await putToTicket(
        ticket,
        bytesOf(16),
        headers: {'content-type': 'text/html'},
      );
      expect(put.status, 403);
    });

    test('the object cannot be overwritten through its ticket, before or '
        'after it is confirmed', () async {
      final ticket = await ticketFor(alice, start(TestUpload.avatar));
      expect((await putToTicket(ticket, bytesOf(16, 1))).status, 200);
      expect((await putToTicket(ticket, bytesOf(16, 2))).status, 412);
      final file = (await finish(
        alice,
        ticket.id,
      )).value(DwFinishUpload(ticketId: ticket.id));
      expect((await putToTicket(ticket, bytesOf(16, 3))).status, 412);
      expect((await getUrl(file.url!)).bytes, bytesOf(16, 1));
    });

    test('a ticket without the conditional header is refused', () async {
      final ticket = await ticketFor(alice, start(TestUpload.avatar));
      final put = await putToTicket(
        ticket,
        bytesOf(16),
        headers: {'if-none-match': null},
      );
      expect(put.status, anyOf(400, 403));
    });
  });

  group('finishing', () {
    test(
      'by another account is refused as if the ticket did not exist',
      () async {
        final ticket = await ticketFor(alice, start(TestUpload.avatar));
        await putToTicket(ticket, bytesOf(16));
        final answer = await finish(bob, ticket.id);
        expect(answer.status, 404);
        expect(answer.refusal.isCode(DwCoreRefusal.notFound), isTrue);
        expect((await rowOf(ticket.id))['confirmed_at'], isNull);
        expect((await finish(anonymous, ticket.id)).status, 401);
        expect((await finish(alice, 1 << 40)).status, 404);
      },
    );

    test(
      'before the object arrived is a refusal, and the ticket still works',
      () async {
        final ticket = await ticketFor(alice, start(TestUpload.avatar));
        final early = await finish(alice, ticket.id);
        expect(early.status, 422);
        expect(early.refusal.isCode(DwUploadRefusal.missing), isTrue);
        expect(
          harness().app.alerts.incidents,
          isEmpty,
          reason: 'not a failure',
        );

        await putToTicket(ticket, bytesOf(16));
        expect((await finish(alice, ticket.id)).status, 200);
      },
    );

    test(
      'an object that is not what the ticket was issued for is refused',
      () async {
        final sized = await ticketFor(
          alice,
          start(TestUpload.avatar, size: 16),
        );
        await storage.putDirectly(
          storage.publicBucket,
          await _keyOf(harness, sized),
          bytesOf(20),
          'image/png',
        );
        final bySize = await finish(alice, sized.id);
        expect(bySize.status, 422);
        expect(bySize.refusal.isCode(DwUploadRefusal.mismatch), isTrue);

        final typed = await ticketFor(
          alice,
          start(TestUpload.avatar, size: 16),
        );
        await storage.putDirectly(
          storage.publicBucket,
          await _keyOf(harness, typed),
          bytesOf(16),
          'text/html',
        );
        final byType = await finish(alice, typed.id);
        expect(byType.refusal.isCode(DwUploadRefusal.mismatch), isTrue);
        expect((await rowOf(typed.id))['confirmed_at'], isNull);
      },
    );

    test('twice answers the same file', () async {
      final file = await upload(alice, TestUpload.avatar);
      final again = await finish(alice, file.id);
      expect(again.value(DwFinishUpload(ticketId: file.id)), file);
    });

    test('past the ticket and its grace is refused as expired', () async {
      final ticket = await ticketFor(alice, start(TestUpload.avatar));
      await putToTicket(ticket, bytesOf(16));
      await harness().db.execute(
        "UPDATE dw_stored_file SET created_at = now() - interval '11 minutes' "
        'WHERE id = @id',
        params: {'id': ticket.id},
      );
      final answer = await finish(alice, ticket.id);
      expect(answer.status, 422);
      expect(answer.refusal.isCode(DwUploadRefusal.expired), isTrue);
    });
  });

  test('unfinished uploads past their ticket and grace are removed with '
      'their objects, from the bucket each is in; finished and recent ones '
      'stay', () async {
    final uploadedStale = await ticketFor(alice, start(TestUpload.avatar));
    await putToTicket(uploadedStale, bytesOf(16));
    final privateStale = await ticketFor(
      alice,
      start(TestUpload.document, type: 'text/plain'),
    );
    await putToTicket(privateStale, bytesOf(16));
    final emptyStale = await ticketFor(alice, start(TestUpload.avatar));
    final recent = await ticketFor(alice, start(TestUpload.avatar));
    await putToTicket(recent, bytesOf(16));
    final finished = await upload(alice, TestUpload.avatar);
    final finishedPrivate = await upload(
      alice,
      TestUpload.document,
      type: 'text/plain',
    );
    final staleKey = await _keyOf(harness, uploadedStale);
    final privateStaleKey = await _keyOf(harness, privateStale);
    final recentKey = await _keyOf(harness, recent);
    final finishedKey = (await rowOf(finished.id)).get<String>('object_key');
    final finishedPrivateKey = (await rowOf(
      finishedPrivate.id,
    )).get<String>('object_key');
    expect(
      await storage.keys(storage.privateBucket),
      containsAll([privateStaleKey, finishedPrivateKey]),
    );

    await harness().db.execute(
      "UPDATE dw_stored_file SET created_at = now() - interval '11 minutes' "
      'WHERE id = ANY(@ids::int8[])',
      params: {
        'ids': [
          uploadedStale.id,
          privateStale.id,
          emptyStale.id,
          finished.id,
          finishedPrivate.id,
        ],
      },
    );
    // Cleanup runs every ten minutes; this run is brought forward, so no
    // other test's backdated row races a run it did not ask for.
    await harness().db.execute(
      'UPDATE dw_recurring_job SET next_run_at = now() WHERE name = @name',
      params: {'name': 'dw.files.cleanup'},
    );
    harness().server.wakeJobs();
    await eventually(() async {
      final rows = await harness().db.query(
        'SELECT id FROM dw_stored_file WHERE id = ANY(@ids::int8[])',
        params: {
          'ids': [uploadedStale.id, privateStale.id, emptyStale.id],
        },
      );
      return rows.isEmpty;
    }, reason: 'cleanup removed the stale rows');
    final keys = await storage.keys(storage.publicBucket);
    expect(keys, isNot(contains(staleKey)));
    expect(keys, containsAll([recentKey, finishedKey]));
    final privateKeys = await storage.keys(storage.privateBucket);
    expect(privateKeys, isNot(contains(privateStaleKey)));
    expect(privateKeys, contains(finishedPrivateKey));
    expect(await rowOf(recent.id), isNotNull);
    expect((await rowOf(finished.id))['confirmed_at'], isNotNull);
    expect(harness().app.alerts.incidents, isEmpty);
  });

  test('too many unfinished uploads are refused until the oldest ticket '
      'expires', () async {
    final (carol, _) = await harness().signedIn('files-carol@example.com');
    for (var i = 0; i < 50; i++) {
      await ticketFor(carol, start(TestUpload.avatar));
    }
    final answer = await carol.call(start(TestUpload.avatar));
    expect(answer.status, 429);
    expect(answer.refusal.retryAfter!.inSeconds, inInclusiveRange(290, 300));
    expect(answer.headers.value('retry-after'), isNotNull);
    // Another account is not affected.
    expect((await bob.call(start(TestUpload.avatar))).status, 200);
  });

  group('ctx.files', () {
    test('requireOwned accepts only the caller\'s confirmed file of the '
        'purpose, and says nothing more', () async {
      final avatar = await upload(alice, TestUpload.avatar);
      final ok = await alice.call(SetAvatar(avatar.id));
      expect(ok.value(SetAvatar(avatar.id)), avatar);

      final document = await upload(
        alice,
        TestUpload.document,
        type: 'text/plain',
      );
      final unfinished = await ticketFor(alice, start(TestUpload.avatar));
      for (final (caller, id) in [
        (bob, avatar.id),
        (alice, document.id),
        (alice, unfinished.id),
        (alice, 1 << 40),
      ]) {
        final answer = await caller.call(SetAvatar(id));
        expect(answer.status, 422);
        expect(answer.refusal.code, 'dw.fileNotOwned');
        expect(answer.refusal.field, 'fileId');
      }
    });

    test(
      'publicUrls resolves a batch, leaving out what is not public',
      () async {
        final first = await upload(alice, TestUpload.avatar);
        final second = await upload(bob, TestUpload.avatar);
        final private = await upload(
          alice,
          TestUpload.document,
          type: 'text/plain',
        );
        final command = ResolveUrls([first.id, second.id, private.id, 1 << 40]);
        final urls = (await anonymous.call(command)).value(command).urls;
        expect(urls, {'${first.id}': first.url, '${second.id}': second.url});
      },
    );

    for (final (purpose, type, public) in [
      (TestUpload.avatar, 'image/png', true),
      (TestUpload.document, 'text/plain', false),
    ]) {
      test('delete removes the row at once and the object after commit, '
          'from the ${public ? 'public' : 'private'} bucket', () async {
        final bucket = public ? storage.publicBucket : storage.privateBucket;
        final file = await upload(alice, purpose, type: type);
        final key = (await rowOf(file.id)).get<String>('object_key');
        expect(await storage.keys(bucket), contains(key));

        final kept = await alice.call(DropFile(file.id, refuse: true));
        expect(kept.status, 409);
        await Future<void>.delayed(const Duration(milliseconds: 300));
        expect(
          await storage.keys(bucket),
          contains(key),
          reason: 'rolled back',
        );

        final dropped = await alice.call(DropFile(file.id));
        expect(dropped.value(DropFile(file.id)), isTrue);
        expect(
          await harness().db.query(
            'SELECT 1 FROM dw_stored_file WHERE id = @id',
            params: {'id': file.id},
          ),
          isEmpty,
        );
        harness().server.wakeJobs();
        await eventually(
          () async => !(await storage.keys(bucket)).contains(key),
          reason: 'the delete job removed the object',
        );
        expect(
          (await alice.call(DropFile(file.id))).value(DropFile(file.id)),
          isFalse,
        );
        expect(harness().app.alerts.incidents, isEmpty);
      });
    }

    group('the server\'s own files', () {
      int sumOf(List<int> bytes) => bytes.fold<int>(0, (a, b) => a + b);

      test('read and readLink reach a private file without canRead', () async {
        // Alice's private document: Bob may not read it as a client, and the
        // server reads it anyway — that is the point.
        final body = bytesOf(40, 3);
        final file = await upload(
          alice,
          TestUpload.document,
          bytes: body,
          type: 'text/plain',
        );
        final asClient = await bob.call(DwGetFileLink(fileId: file.id));
        expect(asClient.status, 403);

        final command = ReadAsServer(file.id);
        final answer = (await bob.call(command)).value(command).urls;
        expect(answer['length'], '${body.length}');
        expect(answer['sum'], '${sumOf(body)}');
        final fetched = await getUrl(answer['link']!);
        expect(fetched.status, 200);
        expect(fetched.bytes, body);
      });

      test(
        'read and readLink know nothing of an unfinished or absent file',
        () async {
          final unfinished = await ticketFor(
            alice,
            start(TestUpload.document, type: 'text/plain', name: 'a.txt'),
          );
          for (final id in [unfinished.id, 1 << 40]) {
            final command = ReadAsServer(id);
            expect((await alice.call(command)).value(command).urls, isEmpty);
          }
        },
      );

      test('store writes a confirmed private file the server made', () async {
        const command = StoreMade(purpose: 'document', size: 30);
        final stored = (await alice.call(command)).value(command);
        expect(stored.url, isNull, reason: 'private');
        expect(stored.byteSize, 30);
        final row = await rowOf(stored.id);
        expect(row['confirmed_at'], isNotNull);
        expect(row.get<String>('bucket'), storage.privateBucket);
        expect(
          await storage.keys(storage.privateBucket),
          contains(row.get<String>('object_key')),
        );

        final read = ReadAsServer(stored.id);
        final answer = (await alice.call(read)).value(read).urls;
        expect(answer['sum'], '${sumOf(bytesOf(30))}');
      });

      test(
        'store rolled back leaves an unconfirmed file for the cleanup',
        () async {
          final before = await harness().db.query(
            'SELECT max(id) AS id FROM dw_stored_file',
          );
          final last = before.single['id'] as int? ?? 0;
          const command = StoreMade(
            purpose: 'document',
            size: 12,
            refuse: true,
          );
          expect((await alice.call(command)).status, 409);
          final rows = await harness().db.query(
            'SELECT confirmed_at, bucket, object_key FROM dw_stored_file '
            'WHERE id > @last',
            params: {'last': last},
          );
          expect(rows, hasLength(1));
          expect(rows.single['confirmed_at'], isNull);
          final read = ReadAsServer(
            (await harness().db.query(
              'SELECT id FROM dw_stored_file WHERE id > @last',
              params: {'last': last},
            )).single.get<int>('id'),
          );
          expect((await alice.call(read)).value(read).urls, isEmpty);
        },
      );

      test(
        'store holds the purpose\'s rule, as mistakes in server code',
        () async {
          for (final command in const [
            StoreMade(purpose: 'document', size: 2 << 20),
            StoreMade(purpose: 'document', size: 8, type: 'image/png'),
            StoreMade(purpose: 'unruled', size: 8),
          ]) {
            expect((await alice.call(command)).status, 500, reason: '$command');
          }
          harness().app.alerts.incidents.clear();
        },
      );
    });

    test('delete from a read is an error, and deletes nothing', () async {
      final file = await upload(alice, TestUpload.avatar);
      final answer = await alice.call(DropFromRead(file.id));
      expect(answer.status, 500);
      expect(await rowOf(file.id), isNotNull);
      harness().app.alerts.incidents.clear();
    });
  });
}

Future<String> _keyOf(
  Harness Function() harness,
  DwUploadTicket ticket,
) async => (await harness().db.query(
  'SELECT object_key FROM dw_stored_file WHERE id = @id',
  params: {'id': ticket.id},
)).single.get<String>('object_key');
