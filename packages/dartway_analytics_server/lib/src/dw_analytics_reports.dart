import 'package:dartway_analytics_shared/dartway_analytics_shared.dart';
import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:meta/meta.dart';

/// The reads of what was recorded: a report in one statement, and the
/// catalog of names and keys.
///
/// Every value that comes from the call — the event name, filter keys and
/// values, the breakdown key, the period — is a parameter. What varies in the
/// statement's text is chosen from enums and counts: which aggregate, which
/// breakdown, how many filter conditions.
@internal
abstract final class DwAnalyticsReports {
  static List<DwCallHandler> handlers(DwAccessRule access) => [
    DwCallHandler.single<DwGetAnalyticsReport, DwAnalyticsReport>(
      access: access,
      handle: (ctx, request) => report(ctx.db, request),
    ),
    DwCallHandler.single<DwGetAnalyticsCatalog, DwAnalyticsCatalog>(
      access: access,
      handle: (ctx, request) => catalog(ctx.db, request.period),
    ),
  ];

  /// The part of the result a row belongs to.
  static const int _point = 0;
  static const int _other = 1;
  static const int _total = 2;

  static Future<DwAnalyticsReport> report(
    DwDatabaseHandle db,
    DwGetAnalyticsReport request,
  ) async {
    final spec = request.spec;
    final period = request.period;
    final params = <String, Object?>{
      'from': period.from.toUtc(),
      'to': period.to.toUtc(),
    };
    final conditions = [
      'occurred_at >= @from::timestamptz',
      'occurred_at < @to::timestamptz',
    ];
    if (spec.eventName case final name?) {
      conditions.add('name = @name');
      params['name'] = name;
    }
    for (final (index, filter) in spec.filters.indexed) {
      conditions.add('properties ->> @fk$index = @fv$index');
      params['fk$index'] = filter.property;
      params['fv$index'] = filter.value;
    }
    final where = conditions.join(' AND ');

    // The counted column: the aggregate below counts it distinctly.
    final counted = switch (spec.metric) {
      DwAnalyticsMetric.events => 'NULL::int8',
      DwAnalyticsMetric.accounts => 'account_id',
      DwAnalyticsMetric.installs => 'install_id',
    };
    final count = switch (spec.metric) {
      DwAnalyticsMetric.events => 'count(*)',
      DwAnalyticsMetric.accounts ||
      DwAnalyticsMetric.installs => 'count(DISTINCT counted)',
    };
    // The event's moment on the period's wall clock.
    const local =
        "(occurred_at AT TIME ZONE 'UTC') + @offset::int4 * interval '1 minute'";

    final String sql;
    final breakdown = spec.breakdown;
    if (breakdown.bucket case final bucket?) {
      params['offset'] = period.utcOffsetMinutes;
      params['unit'] = bucket.name;
      params['step'] = '1 ${bucket.name}';
      // Every bucket of the period, empty ones included, labelled by its
      // first day; the total is counted over the events, not summed.
      sql =
          'WITH e AS (SELECT date_trunc(@unit, $local) AS bucket, '
          '$counted AS counted FROM dw_analytics_event WHERE $where), '
          'buckets AS (SELECT generate_series('
          "date_trunc(@unit, (@from::timestamptz AT TIME ZONE 'UTC') "
          "+ @offset::int4 * interval '1 minute'), "
          "date_trunc(@unit, (@to::timestamptz AT TIME ZONE 'UTC') "
          "+ @offset::int4 * interval '1 minute' - interval '1 microsecond'), "
          '@step::interval) AS bucket), '
          'g AS (SELECT bucket, $count AS value FROM e GROUP BY bucket) '
          "SELECT $_point AS part, to_char(b.bucket, 'YYYY-MM-DD') AS label, "
          'coalesce(g.value, 0)::int8 AS value, b.bucket AS ord '
          'FROM buckets b LEFT JOIN g USING (bucket) '
          'UNION ALL SELECT $_total, NULL, $count::int8, NULL FROM e '
          'ORDER BY part, ord';
    } else if (breakdown.property case final property?) {
      params['key'] = property;
      params['top'] = breakdown.top;
      // The largest values, then the rest together, then the total — each
      // counted over the events, so a distinct count stays distinct.
      sql =
          'WITH e AS (SELECT properties ->> @key AS label, '
          '$counted AS counted FROM dw_analytics_event WHERE $where), '
          'g AS (SELECT label, $count AS value FROM e GROUP BY label), '
          'top AS (SELECT label, value, row_number() OVER '
          '(ORDER BY value DESC, label ASC NULLS LAST) AS ord FROM g '
          'ORDER BY ord LIMIT @top::int4) '
          'SELECT $_point AS part, label, value::int8 AS value, ord FROM top '
          'UNION ALL SELECT $_other, NULL, $count::int8, NULL FROM e '
          'WHERE NOT EXISTS (SELECT 1 FROM top '
          'WHERE top.label IS NOT DISTINCT FROM e.label) '
          'HAVING count(*) > 0 '
          'UNION ALL SELECT $_total, NULL, $count::int8, NULL FROM e '
          'ORDER BY part, ord';
    } else {
      sql =
          'SELECT $_total AS part, $count::int8 AS value FROM '
          '(SELECT $counted AS counted FROM dw_analytics_event '
          'WHERE $where) e';
    }

    final rows = await db.query(sql, params: params);
    var total = 0;
    int? other;
    final points = <DwAnalyticsPoint>[];
    for (final row in rows) {
      final value = row.get<int>('value');
      switch (row.get<int>('part')) {
        case _point:
          points.add(
            DwAnalyticsPoint(label: row.get<String?>('label'), value: value),
          );
        case _other:
          other = value;
        case _:
          total = value;
      }
    }
    return DwAnalyticsReport(total: total, points: points, other: other);
  }

  static Future<DwAnalyticsCatalog> catalog(
    DwDatabaseHandle db,
    DwAnalyticsPeriod period,
  ) async {
    final rows = await db.query(
      'WITH e AS (SELECT name, properties FROM dw_analytics_event '
      'WHERE occurred_at >= @from::timestamptz AND occurred_at < @to::timestamptz), '
      'n AS (SELECT name, count(*)::int8 AS events FROM e GROUP BY name), '
      'k AS (SELECT name, array_agg(DISTINCT key ORDER BY key) AS keys '
      'FROM e, jsonb_object_keys(e.properties) AS key GROUP BY name) '
      "SELECT n.name, n.events, coalesce(k.keys, '{}') AS keys "
      'FROM n LEFT JOIN k USING (name) ORDER BY n.name',
      params: {'from': period.from.toUtc(), 'to': period.to.toUtc()},
    );
    return DwAnalyticsCatalog(
      events: [
        for (final row in rows)
          DwAnalyticsCatalogEvent(
            name: row.get<String>('name'),
            count: row.get<int>('events'),
            propertyKeys: (row['keys']! as List).cast<String>(),
          ),
      ],
    );
  }
}
