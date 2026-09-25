import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_core_server/src/channels/dw_channel_rules.dart';
import 'package:dartway_core_server/src/context/dw_call_context.dart';
import 'package:test/test.dart';

import 'support/test_app.dart';

void main() {
  final harness = useHarness();

  late DwTestCaller anonymous;
  late DwTestCaller signed;
  late DwAuthSession session;

  setUpAll(() async {
    anonymous = harness().caller();
    (signed, session) = await harness().signedIn('calls@example.com');
  });

  Future<List<NoteView>> seed(String prefix, int count) async => [
    for (var i = 0; i < count; i++)
      await TestApp.insertNote(harness().db, '$prefix-$i'),
  ];

  group('access', () {
    test('anonymous access needs no session', () async {
      final answer = await anonymous.call(const ListNotes(ownerId: -1));
      expect(answer.value(const ListNotes()), isEmpty);
    });

    test('signedIn answers unauthenticated without a session, and serves '
        'with one', () async {
      expect((await anonymous.call(const MyNotes())).status, 401);
      expect((await signed.call(const MyNotes())).status, 200);
    });

    test('check receives the call: the owner passes, another account is '
        'forbidden until it is staff, and no session is unauthenticated '
        'without running the check', () async {
      final own = await signed.call(NotesOfOwner(session.id));
      expect(own.status, 200);
      final (other, otherSession) = await harness().signedIn(
        'calls-other@example.com',
      );
      final forbidden = await other.call(NotesOfOwner(session.id));
      expect(forbidden.status, 403);
      harness().app.staff.add(otherSession.id);
      expect((await other.call(NotesOfOwner(session.id))).status, 200);

      final checks = harness().app.ownerChecks;
      expect((await anonymous.call(NotesOfOwner(session.id))).status, 401);
      expect(harness().app.ownerChecks, checks);
    });

    test('requireAccountId in a handler answers unauthenticated', () async {
      expect((await anonymous.call(const NeedsAccount())).status, 401);
      expect(
        (await signed.call(const NeedsAccount())).value(const NeedsAccount()),
        session.id,
      );
    });
  });

  group('validation', () {
    test(
      'the first refusal of validate() is answered, before the handler',
      () async {
        Future<int> notes() async => (await harness().db.query(
          'SELECT count(*) AS n FROM note',
        )).single.get<int>('n');
        final before = await notes();
        final empty = await signed.call(const CreateNote(''));
        expect(
          empty.refusal,
          DwCallRefusal(DwCoreRefusal.invalid, field: 'text'),
        );
        final long = await signed.call(CreateNote('x' * 51));
        expect(long.refusal.params, {'max': '50'});
        expect(await notes(), before);
      },
    );

    test(
      'sign-in is checked first, then validation, then the access check',
      () async {
        // Anonymous and invalid: told to sign in, not which field is wrong.
        expect((await anonymous.call(const CreateNote(''))).status, 401);
        expect((await anonymous.call(const NotesOfOwner(0))).status, 401);
        // Signed in and invalid: the check, which may query, never runs.
        final checks = harness().app.ownerChecks;
        final invalid = await signed.call(const NotesOfOwner(0));
        expect(invalid.status, 422);
        expect(invalid.refusal.field, 'ownerId');
        expect(harness().app.ownerChecks, checks);
      },
    );

    test('a table page below 1 is refused with the page field', () async {
      final page = await anonymous.call(const TableNotes('v', page: 0));
      expect(page.status, 422);
      expect(page.refusal.field, 'page');
      final size = await anonymous.call(const TableNotes('v', pageSize: 0));
      expect(size.refusal.field, 'pageSize');
    });
  });

  group('single, maybe and list', () {
    test('single: an absent object refuses dw.notFound', () async {
      expect((await anonymous.call(const GetNote(-5))).status, 404);
      final [note] = await seed('single', 1);
      expect(
        (await anonymous.call(GetNote(note.id))).value(GetNote(note.id)),
        note,
      );
    });

    test(
      'maybe: an absent object is a value, and the result is omitted',
      () async {
        final answer = await anonymous.call(const FindNote(-5));
        expect(answer.json, {'status': 'ok'});
        expect(answer.value(const FindNote(-5)), isNull);
      },
    );
  });

  group('page', () {
    test('reads one row past the page and trims it', () async {
      final notes = await seed('feed', 7);
      const request = FeedNotes('feed-');
      final first = (await anonymous.call(request)).value(request);
      expect(first.items, notes.sublist(0, 3));
      expect(first.hasMore, isTrue);
      final second = (await anonymous.call(
        request,
        query: const DwOffsetQuery(offset: 3).toQuery(),
      )).value(request);
      expect(second.items, notes.sublist(3, 6));
      expect(second.hasMore, isTrue);
      final third = (await anonymous.call(
        request,
        query: const DwOffsetQuery(offset: 6).toQuery(),
      )).value(request);
      expect(third.items, notes.sublist(6));
      expect(third.hasMore, isFalse);
    });

    test('an exactly full last page has no more', () async {
      final notes = await seed('exact', 3);
      const request = FeedNotes('exact-');
      final page = (await anonymous.call(request)).value(request);
      expect(page.items, notes);
      expect(page.hasMore, isFalse);
    });

    test('pageSize in the query is served up to the class maximum', () async {
      final notes = await seed('sized', 8);
      const request = FeedNotes('sized-');
      final four = (await anonymous.call(
        request,
        query: const DwOffsetQuery(pageSize: 4).toQuery(),
      )).value(request);
      expect(four.items, notes.sublist(0, 4));
      final clamped = (await anonymous.call(
        request,
        query: const DwOffsetQuery(pageSize: 50).toQuery(),
      )).value(request);
      expect(clamped.items, notes.sublist(0, 5));
      expect(clamped.hasMore, isTrue);
    });

    test('a handler that reads past its fetch limit fails loudly instead of '
        'being trimmed', () async {
      final answer = await anonymous.call(const GreedyFeed());
      expect(answer.status, 500);
      final incident = (answer.response as DwApiFailed).incidentId;
      await eventually(
        () => harness().app.alerts.incidents.any(
          (i) => i.id == incident && '${i.error}'.contains('at most 3'),
        ),
      );
    });
  });

  group('table', () {
    test('a full page asks the count; a short last page does not', () async {
      final notes = await seed('table', 5);
      const first = TableNotes('table-');
      final counts = harness().app.tableCounts;
      final page1 = (await anonymous.call(first)).value(first);
      expect(page1.items, notes.sublist(0, 2));
      expect((page1.total, page1.page, page1.pageSize), (5, 1, 2));
      expect(harness().app.tableCounts, counts + 1);

      const last = TableNotes('table-', page: 3);
      final page3 = (await anonymous.call(last)).value(last);
      expect(page3.items, notes.sublist(4));
      expect(page3.total, 5, reason: 'offset 4 + 1 row');
      expect(harness().app.tableCounts, counts + 1, reason: 'no count');
    });

    test('a small table costs one query; an empty one has total 0', () async {
      final notes = await seed('small', 1);
      final counts = harness().app.tableCounts;
      const request = TableNotes('small-');
      final page = (await anonymous.call(request)).value(request);
      expect(page.items, notes);
      expect(page.total, 1);
      const none = TableNotes('none-');
      expect((await anonymous.call(none)).value(none).total, 0);
      expect(harness().app.tableCounts, counts);
    });

    test('a page past the end is empty with the real total', () async {
      await seed('past', 3);
      const request = TableNotes('past-', page: 9);
      final counts = harness().app.tableCounts;
      final page = (await anonymous.call(request)).value(request);
      expect(page.items, isEmpty);
      expect(page.total, 3);
      expect(page.pageCount, 2);
      expect(harness().app.tableCounts, counts + 1);
    });

    test('the page size is clamped to maxPageSize and answered', () async {
      final notes = await seed('clamp', 6);
      const request = TableNotes('clamp-', pageSize: 100);
      final page = (await anonymous.call(request)).value(request);
      expect(page.pageSize, 4);
      expect(page.items, notes.sublist(0, 4));
      expect(page.total, 6);
    });
  });

  group('window', () {
    // Nine messages; four of them share one timestamp, so only the id tells
    // them apart. Newest first: m8 m7 m6 m5 m4 m3 m2 m1 m0.
    late List<MessageView> messages;
    final base = DateTime.utc(2026, 9, 14, 12);

    setUpAll(() async {
      messages = [];
      for (var i = 0; i < 9; i++) {
        final sentAt = i >= 3 && i <= 6
            ? base.add(const Duration(minutes: 3))
            : base.add(Duration(minutes: i));
        final row = (await harness().db.query(
          'INSERT INTO message (room, text, sent_at) '
          'VALUES (@room, @text, @at) RETURNING id',
          params: {'room': 'lobby', 'text': 'm$i', 'at': sentAt},
        )).single;
        messages.add(
          MessageView(id: row.get<int>('id'), text: 'm$i', sentAt: sentAt),
        );
      }
    });

    const request = ChatWindow('lobby');
    List<String> texts(DwWindowResult<MessageView> window) => [
      for (final m in window.items) m.text,
    ];
    String cursorOf(int i) =>
        DwWindowCursor.encode(messages[i].sentAt, messages[i].id);

    Future<DwWindowResult<MessageView>> load(DwWindowQuery query) async =>
        (await anonymous.call(request, query: query.toQuery())).value(request);

    test('without an anchor: the newest rows, one read', () async {
      harness().app.windowReads.clear();
      final window = await load(const DwWindowQuery.newest());
      expect(texts(window), ['m8', 'm7', 'm6', 'm5']);
      expect(window.hasNewer, isFalse);
      expect(window.olderCursor, cursorOf(5));
      expect(
        window.olderCursor,
        request.cursorOf(window.items.last),
        reason: 'the server builds cursors by the request class positionOf',
      );
      expect(harness().app.windowReads, hasLength(1));
    });

    test('older pages walk back through rows sharing a timestamp, neither '
        'losing nor repeating one', () async {
      final seen = <String>[];
      var window = await load(const DwWindowQuery.newest(pageSize: 3));
      seen.addAll(texts(window));
      while (window.olderCursor != null) {
        window = await load(
          DwWindowQuery.older(window.olderCursor!, pageSize: 3),
        );
        expect(window.hasNewer, isTrue);
        seen.addAll(texts(window));
      }
      expect(seen, ['m8', 'm7', 'm6', 'm5', 'm4', 'm3', 'm2', 'm1', 'm0']);
    });

    test('newer pages walk forward, newest first within a page', () async {
      final window = await load(DwWindowQuery.newer(cursorOf(1), pageSize: 3));
      expect(texts(window), ['m4', 'm3', 'm2']);
      expect(window.hasNewer, isTrue);
      expect(window.newerCursor, cursorOf(4));
      expect(window.olderCursor, cursorOf(2));
      final next = await load(
        DwWindowQuery.newer(window.newerCursor!, pageSize: 3),
      );
      expect(texts(next), ['m7', 'm6', 'm5']);
      final last = await load(
        DwWindowQuery.newer(next.newerCursor!, pageSize: 3),
      );
      expect(texts(last), ['m8']);
      expect(last.hasNewer, isFalse);
    });

    test('around an anchor: the anchor and older rows, newer rows above; '
        'two reads', () async {
      harness().app.windowReads.clear();
      final window = await load(DwWindowQuery.around(cursorOf(4)));
      expect(texts(window), ['m6', 'm5', 'm4', 'm3']);
      expect(window.hasNewer, isTrue);
      expect(window.hasOlder, isTrue);
      final reads = harness().app.windowReads;
      expect(
        reads.map((r) => (r.direction, r.includesPosition, r.fetchLimit)),
        [
          (DwWindowDirection.newer, false, 3),
          (DwWindowDirection.older, true, 3),
        ],
      );
    });

    test(
      'around an anchor near the newest: older rows fill the page',
      () async {
        final window = await load(DwWindowQuery.around(cursorOf(7)));
        expect(texts(window), ['m8', 'm7', 'm6', 'm5']);
        expect(window.hasNewer, isFalse);
        expect(window.hasOlder, isTrue);
      },
    );

    test('around an anchor at the oldest: newer rows fill the page, with '
        'a third read only here', () async {
      harness().app.windowReads.clear();
      final window = await load(DwWindowQuery.around(cursorOf(0)));
      expect(texts(window), ['m3', 'm2', 'm1', 'm0']);
      expect(window.hasOlder, isFalse);
      expect(window.hasNewer, isTrue);
      expect(harness().app.windowReads, hasLength(3));
    });

    test('a page of one around an anchor below every row', () async {
      final before = DwWindowCursor.encode(
        base.subtract(const Duration(days: 1)),
        0,
      );
      final window = await load(DwWindowQuery.around(before, pageSize: 1));
      expect(texts(window), ['m0']);
      expect(window.hasNewer, isTrue);
      expect(window.hasOlder, isFalse);
    });

    test('an empty sequence is an empty window without cursors', () async {
      const empty = ChatWindow('nobody-here');
      final window = (await anonymous.call(empty)).value(empty);
      expect(window.items, isEmpty);
      expect((window.olderCursor, window.newerCursor), (null, null));
    });

    test(
      'a cursor that is not one, or of another sequence, is malformed',
      () async {
        for (final query in [
          const DwWindowQuery.older('not-a-cursor').toQuery(),
          DwWindowQuery.older(DwWindowCursor.encode('text', 1)).toQuery(),
          DwWindowQuery.older(DwWindowCursor.encode(base, 'id')).toQuery(),
          {'before': cursorOf(1), 'after': cursorOf(2)},
        ]) {
          final answer = await anonymous.call(request, query: query);
          expect(answer.status, 400, reason: '$query');
        }
        final foreign = await anonymous.call(
          const NotesByText(),
          query: DwWindowQuery.older(cursorOf(1)).toQuery(),
        );
        expect(foreign.status, 400);
      },
    );
  });

  group('reads have no side effects', () {
    test('publishing from a request fails the call', () async {
      final answer = await anonymous.call(const PublishingRequest());
      expect(answer.status, 500);
      final incident = (answer.response as DwApiFailed).incidentId;
      await eventually(
        () => harness().app.alerts.incidents.any(
          (i) => i.id == incident && i.error is StateError,
        ),
      );
    });
  });

  group('context', () {
    DwRuntimeContext context({DwContextKind kind = DwContextKind.command}) =>
        DwRuntimeContext(
          db: harness().db,
          kind: kind,
          protocol: testProtocol,
          log: RecordingLogger(),
          jobs: (_) => _NoJobs(),
          accounts: (ctx) => throw UnimplementedError(),
          channelRules: DwChannelRules([
            DwChannelRule.single(
              TestChannel.notes,
              canSubscribe: (ctx) async => true,
            ),
            DwChannelRule.ofCaller(TestChannel.inbox),
          ]),
        );

    test('memo creates once per key per call', () {
      final ctx = context();
      var created = 0;
      expect(ctx.memo(#a, () => ++created), 1);
      expect(ctx.memo(#a, () => ++created), 1);
      expect(ctx.memo(#b, () => ++created), 2);
      expect(context().memo(#a, () => 'fresh'), 'fresh');
    });

    test('publish takes only channels a subscriber could name: a kind with '
        'a rule, a key where the rule has one, in canonical form', () {
      final ctx = context();
      const note = NoteView(id: 1, text: 'x');
      expect(
        () => ctx.publish(const DwLiveChannel(TestChannel.public), note),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('No channel rule declares the kind "public"'),
          ),
        ),
      );
      expect(
        () => ctx.publish(const DwLiveChannel(TestChannel.inbox), note),
        throwsArgumentError,
        reason: 'a keyed kind needs its key',
      );
      expect(
        () => ctx.publish(const DwLiveChannel(TestChannel.inbox, 'x'), note),
        throwsArgumentError,
        reason: 'the rule does not parse the key',
      );
      expect(
        () => ctx.publish(const DwLiveChannel(TestChannel.notes, 1), note),
        throwsArgumentError,
        reason: 'a single kind takes no key',
      );
      ctx
        ..publish(const DwLiveChannel.forAccount(TestChannel.inbox, 7), note)
        ..publish(const DwLiveChannel(TestChannel.notes), note);
      expect(ctx.rootEffects.publications, hasLength(2));
    });

    test('publish takes only registered data objects and deletions', () {
      final ctx = context();
      expect(
        () => ctx.publish(const DwLiveChannel(TestChannel.notes), const Ping()),
        throwsArgumentError,
      );
      ctx.publish(
        const DwLiveChannel(TestChannel.notes),
        const DwDeletedObject(typeName: 'NoteView', id: 1),
      );
      expect(ctx.rootEffects.publications, hasLength(1));
      expect(
        () => ctx.publish(
          const DwLiveChannel(TestChannel.notes),
          const DwDeletedObject(typeName: 'ListNotes', id: 1),
        ),
        throwsArgumentError,
        reason: 'a deletion names a data object type',
      );
      final read = context(kind: DwContextKind.request);
      expect(
        () => read.publish(
          const DwLiveChannel(TestChannel.notes),
          const NoteView(id: 1, text: 'x'),
        ),
        throwsStateError,
      );
      expect(() => read.revokedKey(1), throwsStateError);
      expect(
        () => context(
          kind: DwContextKind.subscription,
        ).revoke(const DwLiveChannel(TestChannel.notes), 1),
        throwsStateError,
      );
    });

    test('effects of a rolled-back transaction are dropped, of a committed '
        'savepoint kept', () async {
      final ctx = context();
      const channel = DwLiveChannel(TestChannel.notes);
      await expectLater(
        ctx.transaction((tx) async {
          ctx.publish(channel, const NoteView(id: 1, text: 'gone'));
          throw StateError('rollback');
        }),
        throwsStateError,
      );
      expect(ctx.rootEffects.isEmpty, isTrue);
      await ctx.transaction((tx) async {
        expect(ctx.db, same(tx));
        await ctx.transaction((inner) async {
          expect(ctx.db, same(inner));
          ctx.publish(channel, const NoteView(id: 2, text: 'kept'));
        });
        await expectLater(
          ctx.transaction((inner) async {
            ctx.publish(channel, const NoteView(id: 3, text: 'savepoint gone'));
            throw StateError('savepoint rollback');
          }),
          throwsStateError,
        );
        expect(ctx.rootEffects.isEmpty, isTrue, reason: 'not committed yet');
      });
      expect(ctx.rootEffects.publications.map((p) => (p.$2 as NoteView).id), [
        2,
      ]);
      expect(ctx.db, same(harness().db));
    });
  });
}

final class _NoJobs implements DwJobQueue {
  @override
  Future<bool> enqueue<P>(
    DwJobKind<P> job,
    P payload, {
    DateTime? runAt,
    String? key,
  }) => throw UnimplementedError();
}
