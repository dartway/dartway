import 'dart:convert';

import 'package:dartway_analytics_shared/dartway_analytics_shared.dart';
import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:meta/meta.dart';

import 'dw_analytics_settings.dart';

/// The handler of [DwTrackEvents]: a batch in three statements, whatever its
/// size — the install upserted and locked, the events inserted in one
/// statement, the install's running session written back.
@internal
final class DwAnalyticsBatches {
  const DwAnalyticsBatches(this.settings);

  final DwAnalyticsSettings settings;

  DwCallHandler handler() => DwCallHandler.command<DwTrackEvents, void>(
    access: DwAccessRule.anonymous,
    // The events are unique by (install, sequence): a repeated batch stores
    // nothing twice, so an outcome row per batch would only grow a table.
    recordsSuccess: false,
    handle: _store,
  );

  Future<void> _store(DwCallContext ctx, DwTrackEvents batch) async {
    final account = ctx.accountId;
    final install = (await ctx.db.query(
      'INSERT INTO dw_analytics_install '
      '(install_id, platform, app_version, account_id) '
      'VALUES (@install, @platform, @version, @account::int8) '
      'ON CONFLICT (install_id) DO UPDATE SET '
      'platform = EXCLUDED.platform, app_version = EXCLUDED.app_version, '
      'account_id = COALESCE(EXCLUDED.account_id, dw_analytics_install.account_id), '
      'last_seen_at = now() '
      'RETURNING last_event_at, session_number',
      params: {
        'install': batch.installId,
        'platform': batch.platform.name,
        'version': batch.appVersion,
        'account': account,
      },
    )).single;
    // The upsert holds the row lock until the command commits: two batches
    // of one install number their sessions one after the other.
    var lastEventAt = install['last_event_at'] as DateTime?;
    var session = install.get<int>('session_number');

    final events = [...batch.events]
      ..sort((a, b) => a.sequence.compareTo(b.sequence));
    final sessions = <int>[];
    for (final event in events) {
      final at = event.occurredAt.toUtc();
      if (lastEventAt == null ||
          at.difference(lastEventAt) > settings.sessionGap) {
        session++;
      }
      sessions.add(session);
      if (lastEventAt == null || at.isAfter(lastEventAt)) lastEventAt = at;
    }

    await ctx.db.execute(
      'INSERT INTO dw_analytics_event (name, source, occurred_at, install_id, '
      'sequence, session_number, account_id, platform, app_version, properties) '
      "SELECT e.name, 'app', e.occurred_at::timestamptz, @install, e.sequence, e.session, "
      '@account::int8, @platform, @version, e.properties::jsonb '
      'FROM unnest(@names::text[], @occurred::text[], @sequences::int8[], '
      '@sessions::int4[], @properties::text[]) '
      'AS e(name, occurred_at, sequence, session, properties) '
      'ON CONFLICT ON CONSTRAINT dw_analytics_event_once DO NOTHING',
      params: {
        'install': batch.installId,
        'account': account,
        'platform': batch.platform.name,
        'version': batch.appVersion,
        'names': [for (final e in events) e.name],
        // The driver encodes no timestamp arrays; ISO text casts exactly.
        'occurred': [
          for (final e in events) e.occurredAt.toUtc().toIso8601String(),
        ],
        'sequences': [for (final e in events) e.sequence],
        'sessions': sessions,
        'properties': [for (final e in events) jsonEncode(e.properties)],
      },
    );

    await ctx.db.execute(
      'UPDATE dw_analytics_install SET last_event_at = @last, '
      'session_number = @session WHERE install_id = @install',
      params: {
        'install': batch.installId,
        'last': lastEventAt,
        'session': session,
      },
    );
  }
}
