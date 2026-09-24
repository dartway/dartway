import 'dart:async';
import 'dart:io';

import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_core_server/testing.dart';
import 'package:test/test.dart';

import 'dtos.dart';

export 'package:dartway_core_server/testing.dart';
export 'dtos.dart';

/// The Postgres server the suites run against: `DW_DATABASE_*` from the
/// environment. A missing variable fails the suite loudly.
DwDatabaseConfig adminConfig() {
  try {
    return DwDatabaseConfig.fromEnvironment(Platform.environment);
  } on ArgumentError catch (error) {
    throw StateError(
      'The dartway_core_server suites need a Postgres server: set DW_DATABASE_HOST, '
      '_PORT, _NAME (a maintenance database), _USER, _PASSWORD and _SSL. '
      '(${error.message})',
    );
  }
}

/// Alerts recorded for assertions.
final class RecordingAlerts implements DwAlertSink {
  final List<DwServerIncident> incidents = [];
  final List<String?> notes = [];

  @override
  Future<void> send(DwServerIncident incident, {String? suppressedNote}) async {
    incidents.add(incident);
    notes.add(suppressedNote);
  }
}

/// Log lines recorded for assertions (and echoed when DW_TEST_LOG is set).
final class RecordingLogger implements DwServerLogger {
  RecordingLogger([this.scope]);

  final String? scope;
  static final List<String> lines = [];
  static final bool _echo = Platform.environment['DW_TEST_LOG'] != null;

  @override
  void log(
    DwLogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    final line =
        '${level.name} ${scope ?? ''} $message${error == null ? '' : ': $error'}';
    lines.add(line);
    if (_echo) stderr.writeln(line);
  }

  @override
  DwServerLogger scoped(String scope) =>
      RecordingLogger(this.scope == null ? scope : '${this.scope} $scope');
}

final class _AppMigration extends DwDatabaseMigration {
  const _AppMigration();

  @override
  String get id => '20260913_120000_test_app';

  @override
  String get checksum => 'test-app-1';

  @override
  Future<void> up(DwMigrationContext m) => m.sql('''
    CREATE TABLE note (id bigserial PRIMARY KEY, text text NOT NULL, owner_id bigint);
    CREATE TABLE message (
      id bigserial PRIMARY KEY,
      room text NOT NULL,
      text text NOT NULL,
      sent_at timestamptz NOT NULL
    );
    CREATE TABLE profile (
      account_id bigint PRIMARY KEY REFERENCES dw_account (id),
      name text NOT NULL,
      identifier text NOT NULL
    );
    CREATE TABLE counter (label text PRIMARY KEY, n integer NOT NULL);
    CREATE TABLE job_log (id bigserial PRIMARY KEY, name text NOT NULL, tag text, at timestamptz NOT NULL DEFAULT now());
  ''');

  @override
  Future<void> down(DwMigrationContext m) =>
      m.sql('DROP TABLE job_log, counter, profile, message, note');
}

/// The test application: its handlers, channels and hooks, with everything a
/// test wants to observe recorded.
final class TestApp {
  TestApp();

  final RecordingAlerts alerts = RecordingAlerts();
  final RecordingLogger logger = RecordingLogger();

  /// identifier → last delivered code.
  final Map<String, String> delivered = {};
  final List<String> deliveredTo = [];

  /// identifier → `ctx.accountId` on the last `deliverCode` for it: the
  /// caller attaching it, `null` for a sign-in.
  final Map<String, int?> codeCallers = {};

  /// Identifiers whose delivery throws.
  final Set<String> failingDelivery = {};

  /// Identifiers whose `deliverCode` waits on [deliveryGate] before doing
  /// anything else — a slow provider a test holds open and then releases, to
  /// see what a duplicate send of the same idempotency key meets while the
  /// ticket's own transaction has already committed but delivery has not
  /// finished (framework issue: idempotency vs. the post-commit `deliverCode`
  /// split, #310).
  final Set<String> gatedDelivery = {};

  /// Completed to let every identifier in [gatedDelivery] through. A test
  /// replaces it with a fresh one before gating an identifier.
  Completer<void> deliveryGate = Completer();

  /// Identifiers whose delivery refuses (`dw.invalid` on `identifier`)
  /// instead of throwing — the way an SMS provider rejecting the number's
  /// format would, through `ctx.refuse`.
  final Set<String> refusingDelivery = {};
  final List<int> createdAccounts = [];

  /// Account id → the origin `onAccountCreated` was given.
  final Map<int, DwAccountOrigin> accountOrigins = {};

  /// Every `onIdentifierChanged`, in order.
  final List<DwIdentifierChange> identifierChanges = [];

  /// Identifier values whose change makes `onIdentifierChanged` throw, after
  /// it has written the profile.
  final Set<String> failingIdentifierChanges = {};

  /// Account id → `provider:subject` of an external sign-in.
  final Map<int, String> externalAccounts = {};

  /// Accounts whose deletion `onAccountDeleting` refuses.
  final Set<int> undeletable = {};

  /// Accounts that may read anyone's notes (`NotesOfOwner`).
  final Set<int> staff = {};

  /// How many times the access check of `NotesOfOwner` ran.
  int ownerChecks = 0;

  /// Labels of `Count(mode: failOnce)` that have failed already.
  final Set<String> failedOnce = {};

  /// Every read a window handler was asked for, in order.
  final List<DwWindowInput<DateTime, int>> windowReads = [];

  /// How many times the table handler's count ran.
  int tableCounts = 0;

  /// Job name → how many times it should still fail.
  final Map<String, int> jobFailures = {};

  /// `ctx.job` as each run of `flaky` saw it: `attempt/max:isLast`.
  final List<String> jobAttempts = [];

  /// Held open by the `announced` job after its transaction commits, until a
  /// test completes it.
  Completer<void> jobGate = Completer();
  final List<String> jobRuns = [];
  final StreamController<String> jobEvents = StreamController.broadcast();

  static const reviewer = 'reviewer@example.com';

  /// A fixed code that is, unlike [reviewer]'s, still sent — proves
  /// `generateCode` and `deliverCode` decide independently (issue #310).
  static const reviewerSent = 'reviewer-sent@example.com';

  /// How many times `generateCode` has run, across every identifier — so a
  /// test can prove it is not called at all when a request is refused before
  /// either hook runs (the rate limit).
  int generateCodeCalls = 0;

  /// identifier → `ctx.accountId` on the last `generateCode` for it: the
  /// caller attaching it, `null` for a sign-in — the same thing
  /// [codeCallers] records for `deliverCode`, so a test can check both hooks
  /// see the same caller.
  final Map<String, int?> generateCodeCallers = {};

  DwAuthConfig auth({
    Duration resendDelay = const Duration(seconds: 30),
    int maxRequestsPerWindow = 3,
    int maxAttempts = 3,
    Duration keyTouchInterval = const Duration(minutes: 10),
  }) => DwAuthConfig(
    normalize: (kind, raw) {
      final value = raw.trim().toLowerCase();
      return switch (kind) {
        DwIdentifierKind.email => value.contains('@') ? value : null,
        DwIdentifierKind.phone =>
          RegExp(r'^\+\d{6,15}$').hasMatch(value) ? value : null,
      };
    },
    deliverCode: (ctx, kind, identifier, code, accountId) async {
      // The caller attaching the identifier (null for a sign-in) — not
      // [accountId], which is who the identifier already belongs to.
      codeCallers[identifier] = ctx.accountId;
      if (gatedDelivery.contains(identifier)) await deliveryGate.future;
      // `reviewer`'s fixed code goes nowhere — its own decision, made here
      // rather than by the framework withholding the call.
      if (identifier == reviewer) return;
      if (refusingDelivery.contains(identifier)) {
        ctx.refuse(DwCoreRefusal.invalid, field: 'identifier');
      }
      if (failingDelivery.contains(identifier)) {
        throw StateError('delivery provider is down');
      }
      delivered[identifier] = code;
      deliveredTo.add(identifier);
    },
    generateCode: (ctx, kind, identifier, accountId) async {
      generateCodeCalls++;
      // The caller attaching the identifier, the same as `deliverCode` sees
      // — not [accountId], which is who the identifier already belongs to.
      generateCodeCallers[identifier] = ctx.accountId;
      return switch (identifier) {
        reviewer => '000000',
        reviewerSent => '111111',
        // `null` here is the framework's own default (`codeLength` random
        // digits) — not `dwRandomCode(6)` called by hand, which would drift
        // from `codeLength` the moment one changed without the other.
        _ => null,
      };
    },
    onAccountCreated: (ctx, accountId, kind, identifier, origin) async {
      createdAccounts.add(accountId);
      accountOrigins[accountId] = origin;
      await ctx.db.execute(
        'INSERT INTO profile (account_id, name, identifier) '
        'VALUES (@account, @name, @identifier)',
        params: {
          'account': accountId,
          'name': switch (origin) {
            DwSignInOrigin(:final registration) => registration['name'] ?? '',
            DwToolOrigin() => '',
          },
          'identifier': identifier,
        },
      );
    },
    // The profile references the account without a cascade, as a project's
    // own row may: the hook has to remove it, or the deletion fails.
    onExternalAccountCreated:
        (ctx, accountId, provider, subject, registration) async {
          createdAccounts.add(accountId);
          externalAccounts[accountId] = '$provider:$subject';
          await ctx.db.execute(
            'INSERT INTO profile (account_id, name, identifier) '
            'VALUES (@account, @name, @identifier)',
            params: {
              'account': accountId,
              'name': registration['name'] ?? '',
              'identifier': '$provider:$subject',
            },
          );
        },
    onAccountDeleting: (ctx, accountId) async {
      if (undeletable.contains(accountId)) {
        ctx.refuse(DwCoreRefusal.forbidden);
      }
      await ctx.db.execute(
        'DELETE FROM profile WHERE account_id = @id',
        params: {'id': accountId},
      );
    },
    // Mirrors the latest identifier into the profile, as a project showing it
    // on its own rows would.
    onIdentifierChanged: (ctx, change) async {
      identifierChanges.add(change);
      if (change.current case final current?) {
        await ctx.db.execute(
          'UPDATE profile SET identifier = @identifier WHERE account_id = @id',
          params: {'identifier': current, 'id': change.accountId},
        );
        if (failingIdentifierChanges.contains(current)) {
          throw StateError('profile mirror is down');
        }
      }
    },
    maxAttempts: maxAttempts,
    maxRequestsPerWindow: maxRequestsPerWindow,
    requestWindow: const Duration(minutes: 10),
    resendDelay: resendDelay,
    keyTouchInterval: keyTouchInterval,
  );

  static Future<NoteView> insertNote(
    DwDatabaseHandle db,
    String text, [
    int? owner,
  ]) async {
    final row = (await db.query(
      'INSERT INTO note (text, owner_id) VALUES (@text, @owner::int8) '
      'RETURNING id',
      params: {'text': text, 'owner': owner},
    )).single;
    return NoteView(id: row.get<int>('id'), text: text, ownerId: owner);
  }

  static NoteView _note(DwResultRow row) => NoteView(
    id: row.get<int>('id'),
    text: row.get<String>('text'),
    ownerId: row['owner_id'] as int?,
  );

  static Future<List<NoteView>> _notes(
    DwDatabaseHandle db,
    String sql, [
    Map<String, Object?> params = const {},
  ]) async => [
    for (final row in await db.query(sql, params: params)) _note(row),
  ];

  Future<int> _count(DwDatabaseHandle db, String label) async =>
      (await db.query(
        'INSERT INTO counter (label, n) VALUES (@label, 1) '
        'ON CONFLICT (label) DO UPDATE SET n = counter.n + 1 RETURNING n',
        params: {'label': label},
      )).single.get<int>('n');

  List<DwCallHandler> handlers() => [
    DwCallHandler.list<ListNotes, NoteView>(
      access: DwAccessRule.anonymous,
      handle: (ctx, request) => _notes(
        ctx.db,
        'SELECT * FROM note WHERE @owner::int8 IS NULL OR owner_id = @owner '
        'ORDER BY id',
        {'owner': request.ownerId},
      ),
    ),
    DwCallHandler.list<LiveNotes, NoteView>(
      access: DwAccessRule.anonymous,
      handle: (ctx, request) =>
          _notes(ctx.db, 'SELECT * FROM note ORDER BY id DESC'),
    ),
    DwCallHandler.list<MyNotes, NoteView>(
      access: DwAccessRule.signedIn,
      handle: (ctx, request) => _notes(
        ctx.db,
        'SELECT * FROM note WHERE owner_id = @owner ORDER BY id',
        {'owner': ctx.requireAccountId},
      ),
    ),
    DwCallHandler.list<NotesOfOwner, NoteView>(
      access: DwAccessRule.check<NotesOfOwner>((ctx, request) async {
        ownerChecks++;
        return request.ownerId == ctx.accountId ||
            staff.contains(ctx.accountId);
      }),
      handle: (ctx, request) => _notes(
        ctx.db,
        'SELECT * FROM note WHERE owner_id = @owner ORDER BY id',
        {'owner': request.ownerId},
      ),
    ),
    DwCallHandler.single<GetNote, NoteView>(
      access: DwAccessRule.anonymous,
      handle: (ctx, request) async => (await _notes(
        ctx.db,
        'SELECT * FROM note WHERE id = @id',
        {'id': request.noteId},
      )).firstOrNull,
    ),
    DwCallHandler.maybe<FindNote, NoteView>(
      access: DwAccessRule.anonymous,
      handle: (ctx, request) async => (await _notes(
        ctx.db,
        'SELECT * FROM note WHERE id = @id',
        {'id': request.noteId},
      )).firstOrNull,
    ),
    DwCallHandler.page<FeedNotes, NoteView>(
      access: DwAccessRule.anonymous,
      handle: (ctx, request, page) => _notes(
        ctx.db,
        'SELECT * FROM note WHERE text LIKE @prefix ORDER BY id '
        'LIMIT @limit OFFSET @offset',
        {
          'prefix': '${request.prefix}%',
          'limit': page.fetchLimit,
          'offset': page.offset,
        },
      ),
    ),
    DwCallHandler.page<GreedyFeed, NoteView>(
      access: DwAccessRule.anonymous,
      handle: (ctx, request, page) async => [
        for (var i = 0; i < page.fetchLimit + 1; i++)
          NoteView(id: i, text: 'greedy'),
      ],
    ),
    DwCallHandler.table<TableNotes, NoteView>(
      access: DwAccessRule.anonymous,
      rows: (ctx, request, table) => _notes(
        ctx.db,
        'SELECT * FROM note WHERE text LIKE @prefix ORDER BY id '
        'LIMIT @limit OFFSET @offset',
        {
          'prefix': '${request.prefix}%',
          'limit': table.fetchLimit,
          'offset': table.offset,
        },
      ),
      count: (ctx, request) async {
        tableCounts++;
        return (await ctx.db.query(
          'SELECT count(*) AS n FROM note WHERE text LIKE @prefix',
          params: {'prefix': '${request.prefix}%'},
        )).single.get<int>('n');
      },
    ),
    DwCallHandler.window<ChatWindow, MessageView, DateTime, int>(
      access: DwAccessRule.anonymous,
      handle: (ctx, request, window) async {
        windowReads.add(window);
        final older = window.direction == DwWindowDirection.older;
        final position = window.position;
        final comparison = older ? (window.includesPosition ? '<=' : '<') : '>';
        final order = older ? 'DESC' : 'ASC';
        final rows = await ctx.db.query(
          'SELECT id, text, sent_at FROM message WHERE room = @room '
          '${position == null ? '' : 'AND (sent_at, id) $comparison (@sort::timestamptz, @id::int8)'} '
          'ORDER BY sent_at $order, id $order LIMIT @limit',
          params: {
            'room': request.room,
            if (position != null) ...{
              'sort': position.sortValue,
              'id': position.id,
            },
            'limit': window.fetchLimit,
          },
        );
        return [
          for (final row in rows)
            MessageView(
              id: row.get<int>('id'),
              text: row.get<String>('text'),
              sentAt: row.get<DateTime>('sent_at'),
            ),
        ];
      },
    ),
    DwCallHandler.window<NotesByText, NoteView, String, int>(
      access: DwAccessRule.anonymous,
      handle: (ctx, request, window) async => const [],
    ),
    DwCallHandler.list<ExplodingRequest, NoteView>(
      access: DwAccessRule.anonymous,
      handle: (ctx, request) async =>
          throw StateError('database password is ${request.secret}'),
    ),
    DwCallHandler.list<PublishingRequest, NoteView>(
      access: DwAccessRule.anonymous,
      handle: (ctx, request) async {
        ctx.publish(
          const DwLiveChannel(TestChannel.notes),
          const NoteView(id: 1, text: 'from a read'),
        );
        return const [];
      },
    ),
    DwCallHandler.list<SlowRequest, NoteView>(
      access: DwAccessRule.anonymous,
      handle: (ctx, request) async {
        await Future<void>.delayed(Duration(milliseconds: request.millis));
        return const [];
      },
    ),
    DwCallHandler.command<CreateNote, NoteView>(
      access: DwAccessRule.signedIn,
      handle: (ctx, command) async {
        final note = await insertNote(
          ctx.db,
          command.text,
          ctx.requireAccountId,
        );
        ctx.publish(
          const DwLiveChannel(TestChannel.notes),
          note,
          exceptAccounts: {if (command.exceptAuthor) ctx.requireAccountId},
        );
        for (var i = 0; i < command.extraPublishes; i++) {
          ctx.publish(
            const DwLiveChannel(TestChannel.notes),
            NoteView(
              id: note.id,
              text: '${note.text} #$i',
              ownerId: note.ownerId,
            ),
          );
        }
        ctx.publish(
          DwLiveChannel(TestChannel.account, ctx.requireAccountId),
          note,
        );
        return note;
      },
    ),
    DwCallHandler.list<MyInbox, NoteView>(
      access: DwAccessRule.signedIn,
      handle: (ctx, request) async => const [],
    ),
    DwCallHandler.command<SendToInbox, NoteView>(
      access: DwAccessRule.signedIn,
      handle: (ctx, command) async {
        final note = await insertNote(
          ctx.db,
          command.text,
          ctx.requireAccountId,
        );
        ctx.publish(switch (command.accountId) {
          final accountId? => DwLiveChannel.forAccount(
            TestChannel.inbox,
            accountId,
          ),
          null => const DwLiveChannel.ofCaller(TestChannel.inbox),
        }, note);
        return note;
      },
    ),
    DwCallHandler.command<PublishAndEnd, void>(
      access: DwAccessRule.signedIn,
      handle: (ctx, command) async {
        final note = await insertNote(ctx.db, command.ending);
        ctx.publish(const DwLiveChannel(TestChannel.notes), note);
        switch (command.ending) {
          case 'refuse':
            ctx.refuse(DwCoreRefusal.conflict);
          case 'fail':
            throw StateError('after publish');
          default:
            throw ArgumentError(command.ending);
        }
      },
    ),
    DwCallHandler.command<Count, int>(
      access: DwAccessRule.anonymous,
      handle: (ctx, command) async {
        final n = await _count(ctx.db, command.label);
        switch (command.mode) {
          case 'refuse':
            ctx.refuse(DwCoreRefusal.conflict, params: {'n': n});
          case 'outdated':
            ctx.refuse(DwCoreRefusal.updateRequired);
          case 'unknownEnum':
            // The guard itself, reached the way a handler reaches it: the
            // column type a row write uses, on a value this build read as
            // `unknown` off the wire.
            const DwEnumType(FeedTone.values).encode(FeedTone.unknown);
          case 'failOnce' when failedOnce.add(command.label):
            throw StateError('first execution fails');
          case 'conflictOnce' when failedOnce.add(command.label):
            throw DwSerializationFailure('could not serialize access');
        }
        return n;
      },
    ),
    DwCallHandler.command<CountOutside, int>(
      access: DwAccessRule.anonymous,
      transactional: false,
      handle: (ctx, command) async {
        if (ctx.db.inTransaction) throw StateError('expected no transaction');
        final n = await ctx.transaction((tx) => _count(tx, command.label));
        final note = await ctx.transaction(
          (tx) => insertNote(tx, 'outside ${command.label}'),
        );
        ctx.publish(const DwLiveChannel(TestChannel.notes), note);
        if (command.label.startsWith('fail')) {
          throw StateError('after a committed transaction');
        }
        return n;
      },
    ),
    DwCallHandler.command<Ping, String>(
      access: DwAccessRule.anonymous,
      handle: (ctx, command) async => 'pong',
    ),
    DwCallHandler.command<NeedsAccount, int>(
      access: DwAccessRule.anonymous,
      handle: (ctx, command) async => ctx.requireAccountId,
    ),
    DwCallHandler.command<RevokeNotes, void>(
      access: DwAccessRule.signedIn,
      handle: (ctx, command) async {
        ctx.revoke(const DwLiveChannel(TestChannel.notes), command.accountId);
        final note = await insertNote(ctx.db, 'after revoke');
        ctx.publish(const DwLiveChannel(TestChannel.notes), note);
        ctx.publish(const DwLiveChannel(TestChannel.public), note);
      },
    ),
    DwCallHandler.command<RevokeSessions, void>(
      access: DwAccessRule.signedIn,
      handle: (ctx, command) async {
        await ctx.accounts.revokeKeys(command.accountId);
        if (command.ending == 'refuse') ctx.refuse(DwCoreRefusal.conflict);
      },
    ),
    DwCallHandler.command<WhichKey, DwSessionKeyInfo?>(
      access: DwAccessRule.anonymous,
      handle: (ctx, command) async => ctx.sessionKey,
    ),
    DwCallHandler.single<CurrentKey, DwSessionKeyInfo>(
      access: DwAccessRule.signedIn,
      handle: (ctx, request) async => ctx.sessionKey,
    ),
    DwCallHandler.command<IssueKey, IssuedKey>(
      access: DwAccessRule.signedIn,
      handle: (ctx, command) async {
        final (:key, :token) = await ctx.accounts.issueKey(
          ctx.requireAccountId,
          label: command.label,
        );
        if (command.ending == 'refuse') ctx.refuse(DwCoreRefusal.conflict);
        return IssuedKey(id: key.id, token: token);
      },
    ),
    DwCallHandler.command<RevokeMyKey, bool>(
      access: DwAccessRule.signedIn,
      handle: (ctx, command) => ctx.accounts.revokeKey(
        command.keyId,
        accountId: ctx.requireAccountId,
      ),
    ),
    DwCallHandler.command<EnsureAccount, int>(
      access: DwAccessRule.anonymous,
      handle: (ctx, command) async => (await ctx.accounts.ensure(
        DwIdentifierKind.email,
        command.email,
      )).accountId,
    ),
    DwCallHandler.command<EnqueueJob, bool>(
      access: DwAccessRule.anonymous,
      handle: (ctx, command) async {
        final enqueued = await ctx.jobs.enqueue(
          command.name,
          {'tag': command.tag},
          key: command.key,
          runAt: command.delayMillis == null
              ? null
              : DateTime.now().add(
                  Duration(milliseconds: command.delayMillis!),
                ),
        );
        if (command.refuse) ctx.refuse(DwCoreRefusal.conflict);
        return enqueued;
      },
    ),
    DwCallHandler.command<Burst, void>(
      access: DwAccessRule.anonymous,
      handle: (ctx, command) async {
        for (var i = 0; i < command.count; i++) {
          ctx.publish(
            const DwLiveChannel(TestChannel.public),
            NoteView(id: i, text: 'x' * command.size),
          );
        }
      },
    ),
    DwCallHandler.command<SlowNote, NoteView>(
      access: DwAccessRule.anonymous,
      handle: (ctx, command) async {
        await Future<void>.delayed(Duration(milliseconds: command.millis));
        final note = await insertNote(ctx.db, command.text);
        ctx.publish(const DwLiveChannel(TestChannel.notes), note);
        return note;
      },
    ),
    DwCallHandler.command<SmallUpload, int>(
      access: DwAccessRule.anonymous,
      maxBodyBytes: 64,
      handle: (ctx, command) async => command.data.length,
    ),
    DwCallHandler.command<LargeUpload, int>(
      access: DwAccessRule.anonymous,
      maxBodyBytes: 4 << 20,
      handle: (ctx, command) async => command.data.length,
    ),
  ];

  List<DwChannelRule> channels() => [
    DwChannelRule.single(TestChannel.notes, canSubscribe: (ctx) async => true),
    DwChannelRule.single(TestChannel.public, canSubscribe: (ctx) async => true),
    DwChannelRule.keyed<int>(
      TestChannel.account,
      parseKey: int.parse,
      canSubscribe: (ctx, accountId) async => ctx.accountId == accountId,
    ),
    DwChannelRule.single(
      TestChannel.broken,
      canSubscribe: (ctx) async => throw StateError('rule is broken'),
    ),
    DwChannelRule.single(
      TestChannel.nobody,
      canSubscribe: (ctx) async => false,
    ),
    DwChannelRule.ofCaller(TestChannel.inbox),
    DwChannelRule.single(
      TestChannel.tools,
      canSubscribe: (ctx) async =>
          ctx.sessionKey?.kind == DwSessionKeyKind.personal,
    ),
  ];

  Future<void> _logJob(DwCallContext ctx, String name, Object? tag) async {
    await ctx.db.execute(
      'INSERT INTO job_log (name, tag) VALUES (@name, @tag::text)',
      params: {'name': name, 'tag': tag},
    );
  }

  List<DwJobDefinition> jobs({bool withTick = false}) => [
    DwJobDefinition(
      'record',
      handle: (ctx, payload) async {
        await _logJob(ctx, 'record', payload['tag']);
        jobRuns.add('record:${payload['tag']}');
        jobEvents.add('record:${payload['tag']}');
      },
    ),
    DwJobDefinition(
      'flaky',
      maxAttempts: 3,
      backoff: (attempt) => const Duration(milliseconds: 50),
      handle: (ctx, payload) async {
        final run = ctx.job!;
        jobAttempts.add(
          '${run.attempt}/${run.maxAttempts}:${run.isLastAttempt}',
        );
        await _logJob(ctx, 'flaky-attempt', payload['tag']);
        final left = jobFailures['flaky:${payload['tag']}'] ?? 0;
        if (left > 0) {
          jobFailures['flaky:${payload['tag']}'] = left - 1;
          throw StateError('flaky failure, $left left');
        }
        jobEvents.add('flaky:${payload['tag']}');
      },
    ),
    DwJobDefinition(
      'outside',
      transactional: false,
      maxAttempts: 2,
      backoff: (attempt) => const Duration(milliseconds: 50),
      handle: (ctx, payload) async {
        if (ctx.db.inTransaction) throw StateError('expected no transaction');
        final left = jobFailures['outside:${payload['tag']}'] ?? 0;
        if (left > 0) {
          jobFailures['outside:${payload['tag']}'] = left - 1;
          throw StateError('outside failure');
        }
        await _logJob(ctx, 'outside', payload['tag']);
        jobEvents.add('outside:${payload['tag']}');
      },
    ),
    DwJobDefinition(
      'announced',
      transactional: false,
      handle: (ctx, payload) async {
        await ctx.transaction((_) async {
          ctx.publish(
            const DwLiveChannel(TestChannel.notes),
            NoteView(id: 990, text: '${payload['tag']}'),
          );
        });
        // The long call to another service a status is announced before.
        await jobGate.future;
        jobEvents.add('announced:${payload['tag']}');
      },
    ),
    if (withTick)
      DwRecurringJob(
        'tick',
        every: const Duration(milliseconds: 300),
        handle: (ctx) async {
          await _logJob(ctx, 'tick', null);
          jobEvents.add('tick');
        },
      ),
  ];

  DwAppServer server(
    DwDatabaseConfig database, {
    DwAuthConfig? auth,
    DwServerSettings settings = const DwServerSettings(
      jobPollInterval: Duration(seconds: 30),
    ),
    List<DwCallHandler>? handlers,
    List<DwChannelRule>? channels,
    List<DwJobDefinition>? jobs,
    List<DwHttpRoute> routes = const [],
    List<DwDatabaseMigration>? migrations,
    DwWireProtocol? protocol,
    DwDatabaseSchema? schema,
    DwFileStorage? files,
    List<DwServerModule> modules = const [],
  }) => DwAppServer(
    protocol: protocol ?? testProtocol,
    schema: schema,
    migrations: migrations ?? const [_AppMigration()],
    database: database,
    auth: auth ?? this.auth(),
    handlers: handlers ?? this.handlers(),
    channels: channels ?? this.channels(),
    jobs: jobs ?? this.jobs(),
    routes: routes,
    files: files,
    modules: modules,
    alerts: alerts,
    logger: logger,
    settings: settings,
  );

  /// Signs [identifier] in over HTTP and returns the session.
  Future<DwAuthSession> signIn(
    DwTestCaller caller,
    String identifier, {
    DwIdentifierKind kind = DwIdentifierKind.email,
    Map<String, String> registration = const {},
  }) async {
    final request = DwRequestCode(kind: kind, identifier: identifier);
    final ticket = (await caller.call(request)).value(request);
    final normalized = identifier.trim().toLowerCase();
    final code = normalized == reviewer ? '000000' : delivered[normalized]!;
    final verify = DwVerifyCode(
      ticketId: ticket.id,
      code: code,
      registration: registration,
    );
    return (await caller.call(verify)).value(verify);
  }
}

/// A database and a started server for one test file; torn down after it.
final class Harness {
  Harness._(this.app, this.database, this.server);

  final TestApp app;
  final DwTestDatabase database;
  DwTestServer server;
  final List<DwTestCaller> _callers = [];
  final List<DwTestLiveSocket> _sockets = [];

  static Future<Harness> start({
    TestApp? app,
    DwAppServer Function(TestApp app, DwDatabaseConfig config)? build,
  }) async {
    final testApp = app ?? TestApp();
    final database = await DwTestDatabase.create(
      admin: adminConfig(),
      prefix: 'server_test',
    );
    try {
      final server = await DwTestServer.start(
        build?.call(testApp, database.config) ??
            testApp.server(database.config),
      );
      return Harness._(testApp, database, server);
    } catch (_) {
      await database.drop();
      rethrow;
    }
  }

  DwDatabaseHandle get db => server.db;

  /// An anonymous caller, closed with the harness.
  DwTestCaller caller({String? token}) {
    final caller = server.caller(token: token);
    _callers.add(caller);
    return caller;
  }

  /// A live socket, closed with the harness; authenticated when [token] is
  /// given.
  Future<DwTestLiveSocket> live({String? token}) async {
    final socket = await server.openLive();
    _sockets.add(socket);
    if (token != null) {
      final authed = await socket.authenticate(token);
      expect(authed.accountId, isNotNull, reason: 'the token was rejected');
    }
    return socket;
  }

  /// A caller signed in as [identifier], and its session.
  Future<(DwTestCaller, DwAuthSession)> signedIn(String identifier) async {
    final anonymous = caller();
    final session = await app.signIn(anonymous, identifier);
    return (caller(token: session.token), session);
  }

  Future<void> stop() async {
    for (final caller in _callers) {
      caller.close();
    }
    for (final socket in _sockets) {
      if (!socket.isClosed) await socket.close();
    }
    await server.stop();
    await database.drop();
  }
}

/// Registers a harness for the enclosing test file.
Harness Function() useHarness({
  DwAppServer Function(TestApp app, DwDatabaseConfig config)? build,
}) {
  Harness? harness;
  setUpAll(() async => harness = await Harness.start(build: build));
  tearDownAll(() async => harness?.stop());
  return () => harness!;
}

/// Polls [condition] until it holds or [timeout] passes.
Future<void> eventually(
  FutureOr<bool> Function() condition, {
  Duration timeout = const Duration(seconds: 10),
  String? reason,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!await condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail(
        'condition not met within $timeout${reason == null ? '' : ': $reason'}',
      );
    }
    await Future<void>.delayed(const Duration(milliseconds: 25));
  }
}
