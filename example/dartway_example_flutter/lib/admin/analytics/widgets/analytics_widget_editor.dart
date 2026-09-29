import 'package:collection/collection.dart';
import 'package:dartway_analytics_flutter/dartway_analytics_flutter.dart';
import 'package:dartway_example_flutter/admin/analytics/widgets/analytics_filter_rows.dart';
import 'package:dartway_example_flutter/core/app_l10n.dart';
import 'package:dartway_example_flutter/core/dw_core.dart';
import 'package:dartway_example_flutter/ui_kit/ui_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';

/// Builds one dashboard widget: what it shows and how. Pops with the spec.
///
/// Events and property keys are offered from the catalog of [period] — what
/// was actually recorded — rather than typed: a misspelt name is an empty
/// report nobody can tell from a quiet week. Only a filter's value is typed.
class AnalyticsWidgetEditor extends StatelessWidget {
  const AnalyticsWidgetEditor({super.key, this.initial, required this.period});

  /// The widget edited; `null` for a new one.
  final DwAnalyticsWidgetSpec? initial;
  final DwAnalyticsPeriod period;

  @override
  Widget build(BuildContext context) => DwReadBuilder(
    dw.request(DwGetAnalyticsCatalog(period: period)),
    builder: (context, catalog) =>
        _AnalyticsWidgetForm(initial: initial, catalog: catalog),
  );
}

/// The editor's form over the catalog it offers from.
class _AnalyticsWidgetForm extends HookWidget {
  const _AnalyticsWidgetForm({required this.initial, required this.catalog});

  final DwAnalyticsWidgetSpec? initial;
  final DwAnalyticsCatalog catalog;

  static const Set<int> _topChoices = {
    3,
    5,
    10,
    DwAnalyticsBreakdown.labelOrderTop,
    DwAnalyticsBreakdown.maxTop,
  };

  /// A breakdown as a choice of the "split by" menu, whatever its `top`.
  static String _breakdownKey(DwAnalyticsBreakdown breakdown) =>
      switch ((breakdown.bucket, breakdown.property)) {
        (final bucket?, _) => 'time:${bucket.name}',
        (_, final property?) => 'property:$property',
        _ => 'none',
      };

  static DwAnalyticsBreakdown _breakdownOf(
    String? key, {
    required DwAnalyticsBreakdown previous,
  }) {
    if (key == null || key == 'none') return const DwAnalyticsBreakdown.none();
    if (key.startsWith('property:')) {
      return DwAnalyticsBreakdown.byProperty(
        key.substring('property:'.length),
        top: previous.top == 0 ? 5 : previous.top,
        order: previous.order,
      );
    }
    return DwAnalyticsBreakdown.byTime(
      DwAnalyticsTimeBucket.values.byName(key.substring('time:'.length)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final start = initial;
    final type = useState(start?.type ?? DwAnalyticsWidgetType.indicator);
    final title = useState(start?.title ?? '');
    final eventName = useState(start?.report.eventName);
    final metric = useState(start?.report.metric ?? DwAnalyticsMetric.events);
    final filters = useState(start?.report.filters ?? const []);
    final breakdown = useState(
      start?.report.breakdown ?? const DwAnalyticsBreakdown.none(),
    );
    final comparePrevious = useState(start?.comparePrevious ?? false);

    final events = catalog.events;
    final keys = eventName.value == null
        ? {for (final e in events) ...e.propertyKeys}.sorted()
        : events
                  .firstWhereOrNull((e) => e.name == eventName.value)
                  ?.propertyKeys ??
              const <String>[];
    // What the widget already names stays offered, recorded in this period
    // or not.
    final keyChoices = {
      ...keys,
      ?breakdown.value.property,
      for (final f in filters.value) f.property,
    }.toList();

    final spec = DwAnalyticsWidgetSpec(
      type: type.value,
      title: title.value.trim(),
      report: DwAnalyticsReportSpec(
        eventName: eventName.value,
        metric: metric.value,
        filters: [
          for (final f in filters.value)
            if (f.value.isNotEmpty) f,
        ],
        breakdown: breakdown.value,
      ),
      comparePrevious:
          type.value == DwAnalyticsWidgetType.indicator &&
          comparePrevious.value,
    );

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppText.title(
            start == null ? l10n.analyticsAddWidget : l10n.analyticsEditWidget,
          ),
          const Gap(16),
          SegmentedButton<DwAnalyticsWidgetType>(
            segments: [
              for (final t in DwAnalyticsWidgetType.values)
                ButtonSegment(
                  value: t,
                  label: Text(l10n.analyticsWidgetType(t.name)),
                ),
            ],
            selected: {type.value},
            onSelectionChanged: (selected) {
              type.value = selected.single;
              // A pie's slices add up only for events, one value each.
              if (type.value == DwAnalyticsWidgetType.pie) {
                metric.value = DwAnalyticsMetric.events;
              }
            },
          ),
          const Gap(12),
          AppTextFormField(
            value: title.value,
            onChanged: (value) => title.value = value,
            labelText: l10n.analyticsWidgetTitle,
            maxLength: DwAnalyticsWidgetSpec.maxTitleLength,
          ),
          const Gap(12),
          DropdownButtonFormField<String?>(
            initialValue: eventName.value,
            decoration: InputDecoration(labelText: l10n.analyticsEvent),
            isExpanded: true,
            items: [
              DropdownMenuItem(child: Text(l10n.analyticsEveryEvent)),
              for (final e in events)
                DropdownMenuItem(
                  value: e.name,
                  child: Text(l10n.analyticsEventWithCount(e.name, e.count)),
                ),
              if (eventName.value case final name?
                  when events.every((e) => e.name != name))
                DropdownMenuItem(value: name, child: Text(name)),
            ],
            onChanged: (name) => eventName.value = name,
          ),
          const Gap(12),
          DropdownButtonFormField<DwAnalyticsMetric>(
            key: ValueKey(metric.value),
            initialValue: metric.value,
            decoration: InputDecoration(labelText: l10n.analyticsMetricLabel),
            isExpanded: true,
            items: [
              for (final m in DwAnalyticsMetric.values)
                DropdownMenuItem(
                  value: m,
                  child: Text(l10n.analyticsMetric(m.name)),
                ),
            ],
            onChanged: type.value == DwAnalyticsWidgetType.pie
                ? null
                : (m) => metric.value = m ?? metric.value,
          ),
          const Gap(16),
          AnalyticsFilterRows(
            filters: filters.value,
            keyChoices: keyChoices,
            onChanged: (next) => filters.value = next,
          ),
          const Gap(12),
          DropdownButtonFormField<String>(
            initialValue: _breakdownKey(breakdown.value),
            decoration: InputDecoration(
              labelText: l10n.analyticsBreakdownLabel,
            ),
            isExpanded: true,
            items: [
              DropdownMenuItem(
                value: _breakdownKey(const DwAnalyticsBreakdown.none()),
                child: Text(l10n.analyticsBreakdownNone),
              ),
              for (final bucket in DwAnalyticsTimeBucket.values)
                DropdownMenuItem(
                  value: _breakdownKey(DwAnalyticsBreakdown.byTime(bucket)),
                  child: Text(l10n.analyticsBucket(bucket.name)),
                ),
              for (final key in keyChoices)
                DropdownMenuItem(
                  value: _breakdownKey(DwAnalyticsBreakdown.byProperty(key)),
                  child: Text(l10n.analyticsByProperty(key)),
                ),
            ],
            onChanged: (choice) => breakdown.value = _breakdownOf(
              choice,
              previous: breakdown.value,
            ),
          ),
          if (breakdown.value.property case final key?) ...[
            const Gap(12),
            DropdownButtonFormField<DwAnalyticsBreakdownOrder>(
              key: ValueKey(('order', key)),
              initialValue: breakdown.value.order,
              decoration: InputDecoration(labelText: l10n.analyticsOrderLabel),
              isExpanded: true,
              items: [
                for (final order in DwAnalyticsBreakdownOrder.values)
                  DropdownMenuItem(
                    value: order,
                    child: Text(l10n.analyticsOrder(order.name)),
                  ),
              ],
              // A funnel shows every step: ordered by value, the top grows
              // to hold a quiz's questions.
              onChanged: (order) =>
                  breakdown.value = DwAnalyticsBreakdown.byProperty(
                    key,
                    order: order ?? breakdown.value.order,
                    top:
                        order == DwAnalyticsBreakdownOrder.byLabel &&
                            breakdown.value.top <
                                DwAnalyticsBreakdown.labelOrderTop
                        ? DwAnalyticsBreakdown.labelOrderTop
                        : breakdown.value.top,
                  ),
            ),
            const Gap(12),
            DropdownButtonFormField<int>(
              key: ValueKey(('top', key, breakdown.value.top)),
              initialValue: breakdown.value.top,
              decoration: InputDecoration(labelText: l10n.analyticsTopValues),
              items: [
                for (final top in {..._topChoices, breakdown.value.top})
                  DropdownMenuItem(value: top, child: Text('$top')),
              ],
              onChanged: (top) =>
                  breakdown.value = DwAnalyticsBreakdown.byProperty(
                    key,
                    top: top ?? breakdown.value.top,
                    order: breakdown.value.order,
                  ),
            ),
          ],
          if (type.value == DwAnalyticsWidgetType.pie &&
              !spec.report.isPieShaped) ...[
            const Gap(8),
            AppText.caption(l10n.analyticsPieNeedsProperty),
          ],
          if (type.value == DwAnalyticsWidgetType.indicator) ...[
            const Gap(12),
            Row(
              children: [
                AppCheckbox(
                  value: comparePrevious.value,
                  onChanged: (value) => comparePrevious.value = value,
                ),
                const Gap(8),
                Expanded(child: AppText.body(l10n.analyticsComparePrevious)),
              ],
            ),
          ],
          const Gap(16),
          AppButton.primary(
            l10n.saveAction,
            onTap: spec.problem == null
                ? dw.action((context) => Navigator.of(context).pop(spec))
                : null,
          ),
        ],
      ),
    );
  }
}
