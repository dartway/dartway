part of '../../ui_kit.dart';

/// Bars, scaled to the largest value.
///
/// [AppBarChart.columns] stands them up side by side — a series over time,
/// where the order is the point and there are many; the first and the last
/// label sit under the ends, and each bar says its own on a long press.
/// [AppBarChart.rows] lays them down one per line with the label and the
/// value beside — a breakdown by value, where every label has to be read.
///
/// Plain widgets rather than a painter: each bar is a box the framework lays
/// out, gets a tooltip and a semantics label for free, and follows the theme
/// without a repaint of its own.
class AppBarChart extends StatelessWidget {
  const AppBarChart.columns({
    super.key,
    required this.values,
    this.height = 140,
  }) : _rows = false,
       rest = null;

  const AppBarChart.rows({super.key, required this.values, this.rest})
    : _rows = true,
      height = 0;

  final List<AppChartValue> values;

  /// A last line in the rest colour — "other" — for [AppBarChart.rows].
  final AppChartValue? rest;

  /// The height of the columns.
  final double height;

  final bool _rows;

  static String _number(num value) =>
      NumberFormat.decimalPattern().format(value);

  @override
  Widget build(BuildContext context) {
    final all = [...values, ?rest];
    final peak = all.fold<num>(0, (peak, v) => max(peak, v.value));
    double share(num value) => peak <= 0 ? 0 : value / peak;
    return _rows
        ? _buildRows(context, all, share)
        : _buildColumns(context, share);
  }

  Widget _buildColumns(BuildContext context, double Function(num) share) {
    final color = context.chartColor(0);
    final gap = values.length > 40 ? 0.5 : 2.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final value in values)
                Expanded(
                  child: Tooltip(
                    message: '${value.label}: ${_number(value.value)}',
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: gap),
                      child: FractionallySizedBox(
                        alignment: Alignment.bottomCenter,
                        heightFactor: max(share(value.value), 0.01),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: value.value > 0
                                ? color
                                : context.colorScheme.outlineVariant,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(3),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (values.isNotEmpty) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              AppText.caption(values.first.label),
              const Spacer(),
              if (values.length > 1) AppText.caption(values.last.label),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildRows(
    BuildContext context,
    List<AppChartValue> all,
    double Function(num) share,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, value) in all.indexed)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                SizedBox(
                  width: 112,
                  child: AppText.body(
                    value.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: max(share(value.value), 0.01),
                      child: Container(
                        height: 14,
                        decoration: BoxDecoration(
                          color: index == values.length && rest != null
                              ? context.chartRestColor
                              : context.chartColor(0),
                          borderRadius: const BorderRadius.horizontal(
                            right: Radius.circular(3),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 56,
                  child: AppText.body(
                    _number(value.value),
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
