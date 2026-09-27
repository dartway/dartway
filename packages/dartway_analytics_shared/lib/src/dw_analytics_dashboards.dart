import 'package:dartway_core_shared/dartway_core_shared.dart';

import 'dw_analytics_reports.dart';
import 'dw_list_equality.dart';
import 'dw_track_events.dart';

/// How a dashboard widget shows its report. What each looks like is the
/// app's: the framework ships no design.
enum DwAnalyticsWidgetType {
  /// The total as one number, optionally with its change against the
  /// previous period.
  indicator,

  /// The points as bars.
  bar,

  /// The points as slices of the whole. Only for counted events broken down
  /// by a property: each event has one value, so the slices add up to the
  /// total. Distinct people or devices overlap between values — a person
  /// who saw steps 1 and 2 is in both — and would draw shares of nothing.
  pie,
}

/// One widget of a dashboard: a report and how it is shown. A description,
/// not a Flutter widget — the app draws it.
final class DwAnalyticsWidgetSpec {
  const DwAnalyticsWidgetSpec({
    required this.type,
    required this.title,
    required this.report,
    this.comparePrevious = false,
  });

  final DwAnalyticsWidgetType type;
  final String title;
  final DwAnalyticsReportSpec report;

  /// Whether the change against the previous period of the same length is
  /// shown beside the total.
  final bool comparePrevious;

  static const int maxTitleLength = 100;

  /// Why this widget cannot be stored, or null when it can.
  String? get problem {
    if (title.trim().isEmpty || title.length > maxTitleLength) {
      return 'widget title is empty or longer than $maxTitleLength';
    }
    if (type == DwAnalyticsWidgetType.pie && !report.isPieShaped) {
      return 'a pie counts events broken down by a property';
    }
    return report.problem;
  }

  Map<String, Object?> toJson() => {
    'type': type.name,
    'title': title,
    'report': report.toJson(),
    if (comparePrevious) 'comparePrevious': true,
  };

  static DwAnalyticsWidgetSpec fromJson(Map<String, Object?> json) =>
      DwAnalyticsWidgetSpec(
        type: DwJsonCodec.decodeEnum(
          json['type'],
          DwAnalyticsWidgetType.values,
        ),
        title: json['title']! as String,
        report: DwAnalyticsReportSpec.fromJson(
          (json['report']! as Map).cast<String, Object?>(),
        ),
        comparePrevious: json['comparePrevious'] as bool? ?? false,
      );

  @override
  bool operator ==(Object other) =>
      other is DwAnalyticsWidgetSpec &&
      other.type == type &&
      other.title == title &&
      other.report == report &&
      other.comparePrevious == comparePrevious;

  @override
  int get hashCode => Object.hash(type, title, report, comparePrevious);

  @override
  String toString() => 'DwAnalyticsWidgetSpec(${type.name} "$title", $report)';
}

/// A saved dashboard: a title and its widgets, in order. Dashboards belong
/// to the project, not to whoever saved them: everyone with `readAccess`
/// sees the same ones.
final class DwAnalyticsDashboard extends DwDataObject {
  const DwAnalyticsDashboard({
    required this.id,
    required this.title,
    required this.updatedAt,
    this.widgets = const [],
  });

  @override
  final int id;
  final String title;

  /// In the order they are shown.
  final List<DwAnalyticsWidgetSpec> widgets;

  final DateTime updatedAt;

  static const int maxTitleLength = 100;

  /// The most widgets one dashboard holds: a dashboard is read at a glance.
  static const int maxWidgets = 12;

  @override
  String get dwTypeName => 'DwAnalyticsDashboard';

  @override
  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    if (widgets.isNotEmpty) 'widgets': [for (final w in widgets) w.toJson()],
    'updatedAt': DwJsonCodec.encodeDateTime(updatedAt),
  };

  static DwAnalyticsDashboard fromJson(Map<String, Object?> json) =>
      DwAnalyticsDashboard(
        id: json['id']! as int,
        title: json['title']! as String,
        widgets: json['widgets'] == null
            ? const []
            : DwJsonCodec.decodeList(
                json['widgets'],
                (item) => DwAnalyticsWidgetSpec.fromJson(
                  (item! as Map).cast<String, Object?>(),
                ),
              ),
        updatedAt: DwJsonCodec.decodeDateTime(json['updatedAt']),
      );

  @override
  bool operator ==(Object other) =>
      other is DwAnalyticsDashboard &&
      other.id == id &&
      other.title == title &&
      other.updatedAt == updatedAt &&
      sameList(other.widgets, widgets);

  @override
  int get hashCode =>
      Object.hash(id, title, updatedAt, Object.hashAll(widgets));

  @override
  String toString() =>
      'DwAnalyticsDashboard($id "$title", ${widgets.length} widgets)';
}

/// Every saved dashboard, oldest first. Guarded by the module's
/// `readAccess`.
///
/// Not live: the module declares no channel. `dw.plugins.analytics`'s
/// `saveDashboard` and `deleteDashboard` read the list again after a change.
final class DwListAnalyticsDashboards
    extends DwListRequest<DwAnalyticsDashboard> {
  const DwListAnalyticsDashboards();

  @override
  int Function(DwAnalyticsDashboard a, DwAnalyticsDashboard b) get sort =>
      (a, b) => a.id.compareTo(b.id);

  @override
  String get dwTypeName => 'DwListAnalyticsDashboards';

  @override
  Map<String, Object?> toJson() => const {};

  static DwListAnalyticsDashboards fromJson(Map<String, Object?> json) =>
      const DwListAnalyticsDashboards();

  @override
  bool operator ==(Object other) => other is DwListAnalyticsDashboards;

  @override
  int get hashCode => (DwListAnalyticsDashboards).hashCode;

  @override
  String toString() => 'DwListAnalyticsDashboards()';
}

/// Creates a dashboard ([id] `null`) or replaces the title and widgets of
/// dashboard [id]; answers it as stored. Guarded by the module's
/// `editAccess`. The last save wins.
final class DwSaveAnalyticsDashboard
    extends DwActionCommand<DwAnalyticsDashboard>
    implements DwSelfValidating {
  const DwSaveAnalyticsDashboard({
    this.id,
    required this.title,
    this.widgets = const [],
  });

  final int? id;
  final String title;
  final List<DwAnalyticsWidgetSpec> widgets;

  @override
  List<DwCallRefusal> validate() => [
    if (title.trim().isEmpty ||
        title.length > DwAnalyticsDashboard.maxTitleLength)
      DwCallRefusal(DwAnalyticsRefusal.dashboardInvalid, field: 'title'),
    if (widgets.length > DwAnalyticsDashboard.maxWidgets ||
        widgets.any((widget) => widget.problem != null))
      DwCallRefusal(DwAnalyticsRefusal.dashboardInvalid, field: 'widgets'),
  ];

  @override
  String get dwTypeName => 'DwSaveAnalyticsDashboard';

  @override
  Map<String, Object?> toJson() => {
    'id': ?id,
    'title': title,
    if (widgets.isNotEmpty) 'widgets': [for (final w in widgets) w.toJson()],
  };

  static DwSaveAnalyticsDashboard fromJson(Map<String, Object?> json) =>
      DwSaveAnalyticsDashboard(
        id: json['id'] as int?,
        title: json['title']! as String,
        widgets: json['widgets'] == null
            ? const []
            : DwJsonCodec.decodeList(
                json['widgets'],
                (item) => DwAnalyticsWidgetSpec.fromJson(
                  (item! as Map).cast<String, Object?>(),
                ),
              ),
      );

  @override
  bool operator ==(Object other) =>
      other is DwSaveAnalyticsDashboard &&
      other.id == id &&
      other.title == title &&
      sameList(other.widgets, widgets);

  @override
  int get hashCode => Object.hash(id, title, Object.hashAll(widgets));

  @override
  String toString() =>
      'DwSaveAnalyticsDashboard(${id ?? 'new'} "$title", '
      '${widgets.length} widgets)';
}

/// Deletes dashboard [id]; `dw.notFound` when there is none. Guarded by the
/// module's `editAccess`.
final class DwDeleteAnalyticsDashboard extends DwActionCommand<void> {
  const DwDeleteAnalyticsDashboard({required this.id});

  final int id;

  @override
  String get dwTypeName => 'DwDeleteAnalyticsDashboard';

  @override
  Map<String, Object?> toJson() => {'id': id};

  static DwDeleteAnalyticsDashboard fromJson(Map<String, Object?> json) =>
      DwDeleteAnalyticsDashboard(id: json['id']! as int);

  @override
  bool operator ==(Object other) =>
      other is DwDeleteAnalyticsDashboard && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'DwDeleteAnalyticsDashboard($id)';
}
