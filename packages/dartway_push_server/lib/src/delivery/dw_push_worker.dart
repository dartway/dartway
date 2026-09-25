import 'dart:async';
import 'dart:math';

import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_push_shared/dartway_push_shared.dart';
import 'package:meta/meta.dart';

import '../dw_push_message.dart';
import '../dw_push_module.dart';
import '../providers/dw_push_provider.dart';

/// Delivers due notifications: one run of the `dw.push.deliver` job.
///
/// A run repeats, until its budget is spent or nothing is due:
///
/// 1. **Claim** (one short transaction): due, unleased deliveries of any
///    message, `FOR UPDATE SKIP LOCKED`, oldest first. Expired ones finish;
///    the eligibility rule runs once per message for the rest — skipped ones
///    finish, delayed ones move; the recipients' devices are read (a device
///    whose session key is revoked is not one); a delivery with no device
///    left finishes; the others are leased to this run (`lease_id`,
///    `locked_until`) and the transaction commits.
/// 2. **Send**, holding no connection: every leased (delivery, device) pair
///    not yet settled, `concurrentSends` at a time, each bounded by
///    `sendTimeout`. No send starts after the run budget; those left are
///    released untouched.
/// 3. **Record** (one short transaction): per delivery, in one statement
///    guarded by the lease — settled devices, the provider's error text, an
///    attempt counted only for a retryable failure, the next time with
///    backoff, or its outcome. Devices whose token is invalid are deleted —
///    that row, of that transport.
///
/// **Coverage.** Every pending delivery is due no earlier than some pending
/// job: `send` enqueues one at the scheduled time, and every run that moves a
/// delivery later (a retry, a delay) enqueues one at the earliest such time
/// in the same transaction, and a run that stops with work left enqueues its
/// continuation. Several runs may drain at once — they claim different rows.
///
/// **Exactly once.** A device is sent a delivery by the one run holding its
/// lease, and the lease outlasts the run; a settled device is never sent the
/// delivery again. Only a process dying between a provider's acceptance and
/// the record can send twice, after the lease expires.
@internal
final class DwPushWorker {
  DwPushWorker(this.module);

  final DwPushModule module;

  static const int _maxErrorLength = 2000;

  Future<void> run(DwCallContext ctx) async {
    final settings = module.settings;
    final budget = Stopwatch()..start();
    var claimed = 0;
    var sends = 0;
    while (budget.elapsed < settings.runBudget) {
      final claim = await _claim(ctx);
      claimed += claim.claimed;
      if (claim.leased.isNotEmpty) {
        final outcomes = await _send(claim, budget);
        sends += outcomes.length;
        // Deliveries left unsent by the budget come with their continuation.
        if (await _record(ctx, claim, outcomes)) {
          _summary(ctx, claimed, sends, budget, continued: true);
          return;
        }
      }
      // A short batch has taken everything due; what falls due later has its
      // own job.
      if (claim.claimed < settings.batchSize) {
        _summary(ctx, claimed, sends, budget, continued: false);
        return;
      }
    }
    // Out of budget with a full batch just taken: more may be due.
    await ctx.jobs.enqueue(DwPushModule.deliverJob, null);
    _summary(ctx, claimed, sends, budget, continued: true);
  }

  static void _summary(
    DwCallContext ctx,
    int claimed,
    int sends,
    Stopwatch budget, {
    required bool continued,
  }) {
    if (claimed == 0) return;
    ctx.log.debug(
      'push run: $claimed deliveries claimed, $sends sends, '
      '${budget.elapsedMilliseconds} ms'
      '${continued ? ', budget spent, continuation queued' : ''}',
    );
  }

  // --- claim ----------------------------------------------------------------

  Future<_Claim> _claim(DwCallContext ctx) => ctx.transaction((tx) async {
    final rows = await tx.query(
      'SELECT d.id, d.account_id, d.message_id, d.attempts, d.done_devices, '
      'd.sent, m.category, m.title, m.body, m.image_url, m.data, '
      'm.expires_at, m.created_at AS message_created_at, now() AS now '
      'FROM dw_push_delivery d JOIN dw_push_message m ON m.id = d.message_id '
      'WHERE d.finished_at IS NULL AND d.run_at <= now() '
      'AND (d.locked_until IS NULL OR d.locked_until <= now()) '
      'ORDER BY d.run_at, d.id LIMIT @limit FOR UPDATE OF d SKIP LOCKED',
      params: {'limit': module.settings.batchSize},
    );
    if (rows.isEmpty) return _Claim.empty();
    final now = rows.first.get<DateTime>('now');
    final finished = <(int, String)>[];
    final delayed = <(int, DateTime)>[];
    final candidates = <_Delivery>[];
    final messages = <int, _Message>{};
    for (final row in rows) {
      final message = messages.putIfAbsent(
        row.get<int>('message_id'),
        () => _Message.of(row),
      );
      final delivery = _Delivery(
        id: row.get<int>('id'),
        accountId: row.get<int>('account_id'),
        attempts: row.get<int>('attempts'),
        doneDevices: {...(row['done_devices']! as List).cast<int>()},
        sent: row.get<bool>('sent'),
        message: message,
      );
      if (!message.expiresAt.isAfter(now)) {
        finished.add((delivery.id, 'expired'));
      } else {
        candidates.add(delivery);
      }
    }

    final sendable = await _decide(ctx, candidates, finished, delayed);

    final devices = <int, List<_Device>>{};
    if (sendable.isNotEmpty) {
      for (final row in await tx.query(
        'SELECT d.id, d.account_id, d.transport, d.token FROM dw_push_device d '
        'JOIN dw_auth_key k ON k.id = d.key_id AND k.revoked_at IS NULL '
        'WHERE d.account_id = ANY(@accounts::int8[]) '
        'ORDER BY d.account_id, d.updated_at DESC, d.id DESC',
        params: {
          'accounts': {for (final d in sendable) d.accountId}.toList(),
        },
      )) {
        devices
            .putIfAbsent(row.get<int>('account_id'), () => [])
            .add(
              _Device(
                id: row.get<int>('id'),
                transport: DwPushTransport.values.byName(
                  row.get<String>('transport'),
                ),
                token: row.get<String>('token'),
              ),
            );
      }
    }
    final leased = <_Delivery>[];
    for (final delivery in sendable) {
      delivery.devices = [
        for (final device in devices[delivery.accountId] ?? const <_Device>[])
          if (!delivery.doneDevices.contains(device.id)) device,
      ];
      if (delivery.devices.isNotEmpty) {
        leased.add(delivery);
      } else {
        finished.add((delivery.id, delivery.settledOutcome));
      }
    }

    if (finished.isNotEmpty) {
      await tx.execute(
        'UPDATE dw_push_delivery AS d SET outcome = u.outcome, '
        'finished_at = now(), locked_until = NULL, lease_id = NULL '
        'FROM unnest(@ids::int8[], @outcomes::text[]) AS u(id, outcome) '
        'WHERE d.id = u.id',
        params: {
          'ids': [for (final (id, _) in finished) id],
          'outcomes': [for (final (_, outcome) in finished) outcome],
        },
      );
    }
    if (delayed.isNotEmpty) {
      await tx.execute(
        'UPDATE dw_push_delivery AS d SET '
        "run_at = timestamptz 'epoch' + u.micros * interval '1 microsecond' "
        'FROM unnest(@ids::int8[], @micros::int8[]) AS u(id, micros) '
        'WHERE d.id = u.id',
        params: {
          'ids': [for (final (id, _) in delayed) id],
          'micros': [
            for (final (_, time) in delayed)
              time.toUtc().microsecondsSinceEpoch,
          ],
        },
      );
      await _cover(ctx, delayed.map((entry) => entry.$2));
    }
    final leaseId = _newLeaseId();
    if (leased.isNotEmpty) {
      await tx.execute(
        'UPDATE dw_push_delivery SET lease_id = @lease, '
        "locked_until = now() + @micros::int8 * interval '1 microsecond' "
        'WHERE id = ANY(@ids::int8[])',
        params: {
          'lease': leaseId,
          'micros': module.settings.lease.inMicroseconds,
          'ids': [for (final d in leased) d.id],
        },
      );
    }
    return _Claim(rows.length, leaseId, leased, now);
  });

  /// Runs the eligibility rule once per message; answers the deliveries to
  /// send and adds the skipped, expired-by-delay and delayed ones.
  Future<List<_Delivery>> _decide(
    DwCallContext ctx,
    List<_Delivery> candidates,
    List<(int, String)> finished,
    List<(int, DateTime)> delayed,
  ) async {
    final rule = module.eligibility;
    if (rule == null) return candidates;
    final byMessage = <_Message, List<_Delivery>>{};
    for (final delivery in candidates) {
      byMessage.putIfAbsent(delivery.message, () => []).add(delivery);
    }
    final sendable = <_Delivery>[];
    for (final MapEntry(key: message, value: deliveries) in byMessage.entries) {
      final accountIds = [for (final d in deliveries) d.accountId];
      final decisions = await rule(
        ctx,
        message.notice(ctx.protocol),
        List.unmodifiable(accountIds),
      );
      final unknown = decisions.keys.toSet().difference(accountIds.toSet());
      if (unknown.isNotEmpty) {
        throw StateError(
          'The push eligibility rule answered for accounts it was not asked '
          'about: $unknown (message ${message.id})',
        );
      }
      for (final delivery in deliveries) {
        switch (decisions[delivery.accountId] ?? DwPushDecision.send) {
          case DwPushSendNow():
            sendable.add(delivery);
          case DwPushSkip():
            finished.add((delivery.id, 'skipped'));
          case DwPushDelay(:final time):
            if (time.isBefore(message.expiresAt)) {
              delayed.add((delivery.id, time));
            } else {
              finished.add((delivery.id, 'expired'));
            }
        }
      }
    }
    return sendable;
  }

  // --- send -----------------------------------------------------------------

  Future<Map<(int, int), DwPushOutcome>> _send(
    _Claim claim,
    Stopwatch budget,
  ) async {
    final settings = module.settings;
    final tasks = [
      for (final delivery in claim.leased)
        for (final device in delivery.devices) (delivery, device),
    ];
    final outcomes = <(int, int), DwPushOutcome>{};
    var next = 0;
    Future<void> lane() async {
      while (next < tasks.length && budget.elapsed < settings.runBudget) {
        final (delivery, device) = tasks[next++];
        outcomes[(delivery.id, device.id)] = await _sendOne(
          delivery,
          device,
          claim.now,
        );
      }
    }

    await Future.wait([
      for (var i = 0; i < min(settings.concurrentSends, tasks.length); i++)
        lane(),
    ]);
    return outcomes;
  }

  Future<DwPushOutcome> _sendOne(
    _Delivery delivery,
    _Device device,
    DateTime now,
  ) async {
    final provider = module.providers[device.transport];
    if (provider == null) {
      return DwPushRejected(
        'no ${device.transport.name} provider is configured on this server',
      );
    }
    final message = delivery.message;
    final timeout = module.settings.sendTimeout;
    try {
      return await provider
          .send(
            DwPushRequest(
              token: device.token,
              title: message.title,
              body: message.body,
              // Stored as queued; an image no provider shows is left out
              // rather than failing the delivery (see DwPushMessage.imageUrl).
              imageUrl: DwPushMessage.showsImage(message.imageUrl)
                  ? message.imageUrl
                  : null,
              data: message.data,
              link: message.data[DwPushData.linkKey],
              ttl: message.expiresAt.difference(now),
            ),
          )
          .timeout(timeout);
    } on TimeoutException {
      return DwPushRetryLater(
        '${device.transport.name} did not answer within $timeout',
      );
    } catch (error) {
      return DwPushRetryLater('${device.transport.name} send failed: $error');
    }
  }

  // --- record ---------------------------------------------------------------

  /// Records the outcomes; answers whether deliveries were released unsent
  /// (and their continuation queued).
  Future<bool> _record(
    DwCallContext ctx,
    _Claim claim,
    Map<(int, int), DwPushOutcome> outcomes,
  ) async {
    final settings = module.settings;
    final ids = <int>[];
    final done = <String>[];
    final sent = <bool>[];
    final attempts = <int>[];
    final errors = <String>[];
    final runAts = <int>[];
    final results = <String>[];
    final invalidDevices = <int>[];
    final retryTimes = <DateTime>[];
    var released = false;
    // The claim's database clock, moved on by the time sending took: retry
    // times and the job covering them are both on it.
    final now = claim.now.add(claim.age.elapsed);

    for (final delivery in claim.leased) {
      final settled = <int>[];
      final reasons = <String>[];
      var accepted = false;
      var retryable = false;
      var notStarted = false;
      Duration? retryAfter;
      for (final device in delivery.devices) {
        final outcome = outcomes[(delivery.id, device.id)];
        final label = '${device.transport.name} device ${device.id}';
        switch (outcome) {
          case null:
            notStarted = true;
          case DwPushAccepted():
            accepted = true;
            settled.add(device.id);
          case DwPushTokenInvalid(:final reason):
            settled.add(device.id);
            invalidDevices.add(device.id);
            reasons.add('$label: token invalid, removed: $reason');
          case DwPushRejected(:final reason):
            settled.add(device.id);
            reasons.add('$label: $reason');
          case DwPushRetryLater(:final reason, retryAfter: final after):
            retryable = true;
            reasons.add('$label: $reason');
            if (after != null && (retryAfter == null || after > retryAfter)) {
              retryAfter = after;
            }
        }
      }
      final wasSent = delivery.sent || accepted;
      final attempt = delivery.attempts + (retryable ? 1 : 0);
      String outcome = '';
      var runAt = -1;
      if (!retryable && !notStarted) {
        outcome = wasSent ? 'sent' : 'failed';
      } else if (retryable && attempt >= settings.maxAttempts) {
        outcome = wasSent ? 'sent' : 'failed';
      } else if (retryable) {
        final backoff = settings.backoff(attempt);
        final delay = retryAfter != null && retryAfter > backoff
            ? retryAfter
            : backoff;
        final time = now.add(delay);
        runAt = time.microsecondsSinceEpoch;
        retryTimes.add(time);
      } else {
        released = true;
      }
      if (outcome == 'failed') {
        ctx.log.error(
          'push delivery ${delivery.id} (message ${delivery.message.id}) '
          'failed: ${reasons.join('; ')}',
        );
      }
      ids.add(delivery.id);
      done.add('{${settled.join(',')}}');
      sent.add(accepted);
      attempts.add(attempt);
      errors.add(_bounded(reasons.join('; ')));
      runAts.add(runAt);
      results.add(outcome);
    }

    await ctx.transaction((tx) async {
      final recorded = await tx.query(
        'UPDATE dw_push_delivery AS d SET '
        'done_devices = d.done_devices || u.done::int8[], '
        'sent = d.sent OR u.sent, attempts = u.attempts, '
        "last_error = COALESCE(NULLIF(u.error, ''), d.last_error), "
        'run_at = CASE WHEN u.run_at < 0 THEN d.run_at '
        "ELSE timestamptz 'epoch' + u.run_at * interval '1 microsecond' END, "
        "outcome = NULLIF(u.outcome, ''), "
        "finished_at = CASE WHEN u.outcome = '' THEN NULL ELSE now() END, "
        'locked_until = NULL, lease_id = NULL '
        'FROM unnest(@ids::int8[], @done::text[], @sent::bool[], '
        '@attempts::int4[], @errors::text[], @run_ats::int8[], '
        '@outcomes::text[]) '
        'AS u(id, done, sent, attempts, error, run_at, outcome) '
        'WHERE d.id = u.id AND d.lease_id = @lease RETURNING d.id',
        params: {
          'ids': ids,
          'done': done,
          'sent': sent,
          'attempts': attempts,
          'errors': errors,
          'run_ats': runAts,
          'outcomes': results,
          'lease': claim.leaseId,
        },
      );
      if (recorded.length != ids.length) {
        ctx.log.warning(
          'push: ${ids.length - recorded.length} deliveries lost their lease '
          'while being sent (a run outlived ${settings.lease}); their '
          'devices may receive them twice',
        );
      }
      if (invalidDevices.isNotEmpty) {
        await tx.execute(
          'DELETE FROM dw_push_device WHERE id = ANY(@ids::int8[])',
          params: {'ids': invalidDevices},
        );
      }
      await _cover(ctx, retryTimes);
      if (released) {
        await ctx.jobs.enqueue(DwPushModule.deliverJob, null);
      }
    });
    return released;
  }

  /// Enqueues the job that covers the earliest of [times].
  static Future<void> _cover(
    DwCallContext ctx,
    Iterable<DateTime> times,
  ) async {
    DateTime? earliest;
    for (final time in times) {
      if (earliest == null || time.isBefore(earliest)) earliest = time;
    }
    if (earliest == null) return;
    await ctx.jobs.enqueue(DwPushModule.deliverJob, null, runAt: earliest);
  }

  static String _bounded(String text) => text.length <= _maxErrorLength
      ? text
      : '${text.substring(0, _maxErrorLength - 1)}…';

  static final Random _random = Random.secure();

  static String _newLeaseId() => List.generate(
    16,
    (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

final class _Claim {
  _Claim(this.claimed, this.leaseId, this.leased, this.now)
    : age = Stopwatch()..start();

  _Claim.empty()
    : claimed = 0,
      leaseId = '',
      leased = const [],
      now = DateTime.utc(1970),
      age = Stopwatch();

  final int claimed;
  final String leaseId;
  final List<_Delivery> leased;

  /// The database's clock when the claim was read.
  final DateTime now;

  /// Time since [now]: the claim's clock moved on.
  final Stopwatch age;
}

final class _Message {
  _Message({
    required this.id,
    required this.category,
    required this.title,
    required this.body,
    required this.imageUrl,
    required this.data,
    required this.expiresAt,
    required this.createdAt,
  });

  factory _Message.of(DwResultRow row) => _Message(
    id: row.get<int>('message_id'),
    category: row.get<String>('category'),
    title: row.get<String>('title'),
    body: row['body'] as String?,
    imageUrl: row['image_url'] as String?,
    data: (row['data']! as Map).cast<String, String>(),
    expiresAt: row.get<DateTime>('expires_at'),
    createdAt: row.get<DateTime>('message_created_at'),
  );

  final int id;
  final String category;
  final String title;
  final String? body;
  final String? imageUrl;
  final Map<String, String> data;
  final DateTime expiresAt;
  final DateTime createdAt;

  DwPushNotice notice(DwWireProtocol protocol) {
    DwPushData decoded;
    try {
      decoded = DwPushData.fromWire(data, protocol);
    } on FormatException {
      // A payload class a later deploy removed: the rule still sees the link.
      decoded = DwPushData(link: data[DwPushData.linkKey]);
    }
    return DwPushNotice(
      messageId: id,
      category: category,
      title: title,
      body: body,
      data: decoded,
      createdAt: createdAt,
    );
  }
}

final class _Delivery {
  _Delivery({
    required this.id,
    required this.accountId,
    required this.attempts,
    required this.doneDevices,
    required this.sent,
    required this.message,
  });

  final int id;
  final int accountId;
  final int attempts;
  final Set<int> doneDevices;
  final bool sent;
  final _Message message;
  List<_Device> devices = const [];

  /// The outcome of a delivery with nothing left to send to.
  String get settledOutcome => sent
      ? 'sent'
      : doneDevices.isEmpty
      ? 'noDevices'
      : 'failed';
}

final class _Device {
  const _Device({
    required this.id,
    required this.transport,
    required this.token,
  });

  final int id;
  final DwPushTransport transport;
  final String token;
}
