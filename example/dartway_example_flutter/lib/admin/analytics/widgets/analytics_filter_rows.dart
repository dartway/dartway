import 'package:dartway_analytics_flutter/dartway_analytics_flutter.dart';
import 'package:dartway_example_flutter/core/app_l10n.dart';
import 'package:dartway_example_flutter/core/dw_core.dart';
import 'package:dartway_example_flutter/ui_kit/ui_kit.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

/// The conditions of a report: a property from [keyChoices] and the value it
/// equals, one per row, all of them together.
class AnalyticsFilterRows extends StatelessWidget {
  const AnalyticsFilterRows({
    super.key,
    required this.filters,
    required this.keyChoices,
    required this.onChanged,
  });

  final List<DwAnalyticsFilter> filters;
  final List<String> keyChoices;
  final ValueChanged<List<DwAnalyticsFilter>> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    void setFilter(int index, DwAnalyticsFilter? filter) => onChanged([
      for (final (i, f) in filters.indexed)
        if (i != index) f else ?filter,
    ]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppText.body(l10n.analyticsFilters),
        for (final (index, filter) in filters.indexed)
          Row(
            children: [
              Expanded(
                child: DropdownButton<String>(
                  value: filter.property,
                  isExpanded: true,
                  items: [
                    for (final key in keyChoices)
                      DropdownMenuItem(value: key, child: Text(key)),
                  ],
                  onChanged: (key) => setFilter(
                    index,
                    DwAnalyticsFilter(
                      property: key ?? filter.property,
                      value: filter.value,
                    ),
                  ),
                ),
              ),
              const Gap(8),
              Expanded(
                child: AppTextFormField(
                  value: filter.value,
                  onChanged: (value) => setFilter(
                    index,
                    DwAnalyticsFilter(property: filter.property, value: value),
                  ),
                  labelText: l10n.analyticsFilterValue,
                ),
              ),
              IconButton(
                tooltip: l10n.analyticsRemoveFilter,
                icon: const Icon(Icons.close),
                onPressed: () => setFilter(index, null),
              ),
            ],
          ),
        if (keyChoices.isNotEmpty &&
            filters.length < DwAnalyticsReportSpec.maxFilters)
          Align(
            alignment: Alignment.centerLeft,
            child: AppButton.text(
              l10n.analyticsAddFilter,
              onTap: dw.action(
                (_) => onChanged([
                  ...filters,
                  DwAnalyticsFilter(property: keyChoices.first, value: ''),
                ]),
              ),
            ),
          ),
      ],
    );
  }
}
