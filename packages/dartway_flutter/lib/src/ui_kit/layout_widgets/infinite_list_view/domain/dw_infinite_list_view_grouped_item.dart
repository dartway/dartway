import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

sealed class DwInfiniteListViewGroupedItem {
  static List<DwInfiniteListViewGroupedItem> groupByDate<Entity>(
    WidgetRef ref,
    List<Entity> items,
    DateTime Function(Entity item) groupingFieldGetter,
    Widget Function(WidgetRef ref, DateTime date) groupHeaderBuilder,
  ) {
    items.sort(
      (a, b) => groupingFieldGetter(b).compareTo(groupingFieldGetter(a)),
    );

    final grouped = <DwInfiniteListViewGroupedItem>[];
    DateTime? lastDate;

    for (final item in items) {
      final timestamp = groupingFieldGetter(item);
      final date = DateTime(timestamp.year, timestamp.month, timestamp.day);

      if (lastDate == null || lastDate != date) {
        grouped.add(
          DwInfiniteListViewGroupHeader(groupHeaderBuilder(ref, date)),
        );
        lastDate = date;
      }

      grouped.add(DwInfiniteListViewGroupedModel(item));
    }
    return grouped;
  }
}

class DwInfiniteListViewGroupHeader extends DwInfiniteListViewGroupedItem {
  final Widget widget;
  DwInfiniteListViewGroupHeader(this.widget);
}

class DwInfiniteListViewGroupedModel<Entity>
    extends DwInfiniteListViewGroupedItem {
  final Entity model;
  DwInfiniteListViewGroupedModel(this.model);
}
