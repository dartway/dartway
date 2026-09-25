import 'dart:convert';

import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_push_shared/dartway_push_shared.dart';

import 'dw_push_message.dart';
import 'dw_push_module.dart';

/// `ctx.push` — sending notifications from a handler or a job.
extension DwPushContext on DwCallContext {
  /// The push service of this server. Throws [StateError] when the server
  /// has no [DwPushModule].
  DwPushService get push => DwPushService._(this, module<DwPushModule>());
}

/// Queues notifications. Nothing is sent from the call that queues: the
/// message and one delivery per recipient are written through the caller's
/// database — in its transaction, so a rolled-back command sends nothing —
/// and the delivery job sends them once that commits.
final class DwPushService {
  DwPushService._(this._ctx, this._module);

  final DwCallContext _ctx;
  final DwPushModule _module;

  static const int maxDedupKeyLength = 200;

  /// Queues [message] of [category] for each of [recipientAccountIds] and
  /// answers how many deliveries were queued.
  ///
  /// With [dedupKey], a recipient who already has a delivery with that key —
  /// pending, or finished within `DwPushSettings.retention` — is not queued
  /// again: a retried command, a job that runs twice or two events about one
  /// thing send once. Without one, every call sends.
  ///
  /// [scheduledAt] (now when omitted) is when the deliveries fall due; the
  /// message may still go out until [lifetime] (by default
  /// `DwPushSettings.messageLifetime`) after it, and is recorded as expired
  /// after that.
  ///
  /// Throws [ArgumentError] for a message that cannot be sent (see
  /// `DwPushMessage.problemIn`) or a malformed key; an account id that does
  /// not exist fails the statement, and with it the caller's transaction.
  Future<int> send(
    Iterable<int> recipientAccountIds, {
    required DwPushMessage message,
    required DwPushCategory category,
    String? dedupKey,
    DateTime? scheduledAt,
    Duration? lifetime,
  }) async {
    if (message.problemIn(_ctx.protocol) case final problem?) {
      throw ArgumentError.value(message, 'message', problem);
    }
    if (message.imageUrl case final url? when !message.imageIsShowable) {
      _ctx.log.warning(
        'push image $url is not https: the notification is sent without it',
      );
    }
    if (dedupKey != null &&
        (dedupKey.isEmpty || dedupKey.length > maxDedupKeyLength)) {
      throw ArgumentError.value(
        dedupKey,
        'dedupKey',
        'must have 1 to $maxDedupKeyLength characters',
      );
    }
    final life = lifetime ?? _module.settings.messageLifetime;
    if (life <= Duration.zero) {
      throw ArgumentError.value(lifetime, 'lifetime', 'must be positive');
    }
    final accounts = recipientAccountIds.toSet().toList()..sort();
    if (accounts.isEmpty) return 0;

    Future<int> queue(DwDatabaseHandle db) async {
      // The message and its deliveries in one statement; a recipient whose
      // dedup key is taken is left out by the unique index.
      final rows = await db.query(
        'WITH message AS ('
        'INSERT INTO dw_push_message '
        '(category, title, body, image_url, data, expires_at) '
        'VALUES (@category, @title, @body::text, @image::text, @data::jsonb, '
        'COALESCE(@run_at::timestamptz, now()) '
        '+ @lifetime::int8 * interval \'1 microsecond\') RETURNING id) '
        'INSERT INTO dw_push_delivery (message_id, account_id, dedup_key, run_at) '
        'SELECT message.id, account, @dedup::text, '
        'COALESCE(@run_at::timestamptz, now()) '
        'FROM message, unnest(@accounts::int8[]) AS account '
        'ON CONFLICT (account_id, dedup_key) WHERE dedup_key IS NOT NULL '
        'DO NOTHING RETURNING id',
        params: {
          'category': category.categoryName,
          'title': message.title,
          'body': message.body,
          'image': message.imageUrl,
          'data': jsonEncode(message.wireData),
          'run_at': scheduledAt?.toUtc(),
          'lifetime': life.inMicroseconds,
          'dedup': dedupKey,
          'accounts': accounts,
        },
      );
      if (rows.isEmpty) return 0;
      // Every pending delivery is covered by a job due no later than it.
      await _ctx.jobs.enqueue(
        DwPushModule.deliverJob,
        null,
        runAt: scheduledAt,
      );
      return rows.length;
    }

    // Two statements that must commit together.
    return _ctx.db.inTransaction ? queue(_ctx.db) : _ctx.transaction(queue);
  }
}
