import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:meta/meta.dart';

import '../dw_push_module.dart';
import '../dw_push_settings.dart';

/// The recurring `dw.push.cleanup` job: removes what retention no longer
/// needs, and recovers delivery work nobody covers.
@internal
final class DwPushCleanup {
  const DwPushCleanup(this.settings);

  final DwPushSettings settings;

  /// Rows removed per run; a larger backlog is worked off over several runs,
  /// so one run's transaction stays short.
  static const int batch = 5000;

  Future<void> run(DwCallContext ctx) async {
    // Finished deliveries past retention; their dedup keys are free again.
    await ctx.db.execute(
      'DELETE FROM dw_push_delivery WHERE id IN (SELECT id FROM dw_push_delivery '
      "WHERE finished_at < now() - @micros::int8 * interval '1 microsecond' "
      'LIMIT @batch)',
      params: {'micros': settings.retention.inMicroseconds, 'batch': batch},
    );
    // Messages without deliveries: every recipient was a duplicate, or their
    // deliveries were just removed. A message is written with its deliveries
    // in one statement, so none gains a delivery later.
    await ctx.db.execute(
      'DELETE FROM dw_push_message WHERE id IN (SELECT m.id FROM dw_push_message m '
      'WHERE NOT EXISTS (SELECT 1 FROM dw_push_delivery d WHERE d.message_id = m.id) '
      'LIMIT @batch)',
      params: {'batch': batch},
    );
    // Work overdue by more than a lease is not covered by a job — its job
    // ran out of attempts on database failures, which alerted. Queue one
    // run to take it again; the key keeps repeated cleanups to one.
    final overdue = (await ctx.db.query(
      'SELECT count(*) AS n FROM dw_push_delivery WHERE finished_at IS NULL '
      "AND run_at < now() - @micros::int8 * interval '1 microsecond' "
      'AND (locked_until IS NULL OR locked_until < now())',
      params: {'micros': settings.lease.inMicroseconds},
    )).single.get<int>('n');
    if (overdue > 0) {
      ctx.log.warning(
        'push: $overdue deliveries are overdue by more than ${settings.lease}; '
        'queueing a delivery run for them',
      );
      await ctx.jobs.enqueue(
        DwPushModule.deliverJob,
        const {},
        key: 'dw.push.recover',
      );
    }
  }
}
