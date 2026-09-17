import 'dart:convert';

import 'package:dartway_analytics_shared/dartway_analytics_shared.dart';
import 'package:dartway_core_server/dartway_core_server.dart';

import 'dw_analytics_module.dart';

/// `ctx.analytics` — events the server records itself.
extension DwAnalyticsContext on DwCallContext {
  /// The analytics of this server. Throws [StateError] when the server has
  /// no [DwAnalyticsModule].
  DwAnalyticsService get analytics {
    module<DwAnalyticsModule>();
    return DwAnalyticsService._(this);
  }
}

/// Records events from a handler or a job.
///
/// What only the server knows for certain belongs here rather than in the
/// app: a payment settled, a job finished, a command succeeded. The event is
/// written through the caller's database — in its transaction, so a
/// rolled-back command records nothing.
final class DwAnalyticsService {
  DwAnalyticsService._(this._ctx);

  final DwCallContext _ctx;

  /// Records [event] with [properties], attributed to [accountId] — the
  /// caller's account when omitted.
  ///
  /// Throws [ArgumentError] for properties the store does not take (see
  /// `DwTrackedEvent.problem`).
  Future<void> track(
    DwAnalyticsEvent event, {
    Map<String, Object?> properties = const {},
    int? accountId,
  }) async {
    final check = DwTrackedEvent(
      name: event.eventName,
      occurredAt: DateTime.now(),
      sequence: 0,
      properties: properties,
    );
    if (check.problem case final problem?) {
      throw ArgumentError.value(properties, 'properties', problem);
    }
    await _ctx.db.execute(
      'INSERT INTO dw_analytics_event '
      '(name, source, occurred_at, account_id, properties) '
      "VALUES (@name, 'server', now(), @account::int8, @properties::jsonb)",
      params: {
        'name': event.eventName,
        'account': accountId ?? _ctx.accountId,
        'properties': jsonEncode(properties),
      },
    );
  }
}
