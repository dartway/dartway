import 'dart:convert';

import 'package:dartway_analytics_shared/dartway_analytics_shared.dart';
import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:meta/meta.dart';

/// Saved dashboards: `dw_analytics_dashboard`, its widgets as the JSON of
/// `DwAnalyticsWidgetSpec`, in order.
@internal
abstract final class DwAnalyticsDashboards {
  static List<DwCallHandler> handlers({
    required DwAccessRule read,
    required DwAccessRule edit,
  }) => [
    DwCallHandler.list<DwListAnalyticsDashboards, DwAnalyticsDashboard>(
      access: read,
      handle: (ctx, request) async => [
        for (final row in await ctx.db.query(
          'SELECT * FROM dw_analytics_dashboard ORDER BY id',
        ))
          _dashboard(row),
      ],
    ),
    DwCallHandler.command<DwSaveAnalyticsDashboard, DwAnalyticsDashboard>(
      access: edit,
      handle: (ctx, command) async {
        final params = {
          'id': ?command.id,
          'title': command.title.trim(),
          'widgets': jsonEncode([for (final w in command.widgets) w.toJson()]),
        };
        final rows = await ctx.db.query(
          command.id == null
              ? 'INSERT INTO dw_analytics_dashboard (title, widgets) '
                    'VALUES (@title, @widgets::jsonb) RETURNING *'
              : 'UPDATE dw_analytics_dashboard SET title = @title, '
                    'widgets = @widgets::jsonb, updated_at = now() '
                    'WHERE id = @id::int8 RETURNING *',
          params: params,
        );
        if (rows.isEmpty) ctx.refuse(DwCoreRefusal.notFound);
        return _dashboard(rows.single);
      },
    ),
    DwCallHandler.command<DwDeleteAnalyticsDashboard, void>(
      access: edit,
      handle: (ctx, command) async {
        final deleted = await ctx.db.execute(
          'DELETE FROM dw_analytics_dashboard WHERE id = @id::int8',
          params: {'id': command.id},
        );
        if (deleted == 0) ctx.refuse(DwCoreRefusal.notFound);
      },
    ),
  ];

  static DwAnalyticsDashboard _dashboard(DwResultRow row) =>
      DwAnalyticsDashboard(
        id: row.get<int>('id'),
        title: row.get<String>('title'),
        updatedAt: row.get<DateTime>('updated_at'),
        widgets: [
          for (final widget in row.get<List<Object?>>('widgets'))
            DwAnalyticsWidgetSpec.fromJson(
              (widget! as Map).cast<String, Object?>(),
            ),
        ],
      );
}
