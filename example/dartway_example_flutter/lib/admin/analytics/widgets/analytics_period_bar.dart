import 'package:dartway_example_flutter/admin/analytics/logic/analytics_period_choice.dart';
import 'package:dartway_example_flutter/core/app_l10n.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// The period every widget of the dashboard reports on: the last 7, 30 or 90
/// days, or dates picked by hand.
class AnalyticsPeriodBar extends StatelessWidget {
  const AnalyticsPeriodBar({
    super.key,
    required this.choice,
    required this.onChanged,
  });

  final AnalyticsPeriodChoice choice;
  final ValueChanged<AnalyticsPeriodChoice> onChanged;

  static String _date(DateTime at) => DateFormat.yMMMd().format(at.toLocal());

  Future<void> _pickDates(BuildContext context) async {
    final now = DateTime.now();
    final period = choice.period;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 3 * 365)),
      lastDate: now,
      initialDateRange: DateTimeRange(
        start: period.from.toLocal(),
        end: period.to.toLocal().subtract(const Duration(days: 1)),
      ),
    );
    if (picked != null) {
      onChanged(AnalyticsPeriodChoice.dates(picked.start, picked.end));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final period = choice.period;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final days in AnalyticsPeriodChoice.presets)
          ChoiceChip(
            label: Text(l10n.analyticsLastDays(days)),
            selected: choice.days == days,
            onSelected: (_) => onChanged(AnalyticsPeriodChoice.lastDays(days)),
          ),
        ChoiceChip(
          label: Text(
            choice.days == null
                ? '${_date(period.from)} – '
                      '${_date(period.to.subtract(const Duration(days: 1)))}'
                : l10n.analyticsPickDates,
          ),
          selected: choice.days == null,
          onSelected: (_) => _pickDates(context),
        ),
      ],
    );
  }
}
