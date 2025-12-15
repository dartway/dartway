import 'package:dartway_flutter/dartway_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class InfiniteListView<Entity> extends ConsumerStatefulWidget {
  const InfiniteListView({
    super.key,
    required this.listViewConfig,
    required this.listTileBuilder,
    this.separatorBuilder,
    this.onFirstLoadTrigger,
    this.emptyListPlaceHolder = const SizedBox.shrink(),
    this.groupBy,
    this.groupDivider,
  });

  final DwInfiniteListViewConfig<Entity> listViewConfig;
  final Widget Function(BuildContext context, int index)? separatorBuilder;
  final Widget Function(BuildContext context, Entity model) listTileBuilder;
  final Function(WidgetRef ref, List<Entity> models)? onFirstLoadTrigger;
  final Widget emptyListPlaceHolder;
  final List<DwInfiniteListViewGroupedItem> Function(
    WidgetRef ref,
    List<Entity> items,
  )?
  groupBy;
  final Widget? groupDivider;

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _State<Entity>();
}

class _State<Entity> extends ConsumerState<InfiniteListView<Entity>> {
  bool isLoadingMore = false;
  bool hasMaybeMore = true;
  bool isFirstLoadTriggered = false;

  @override
  Widget build(BuildContext context) {
    final asyncList = widget.listViewConfig.watchAsyncValue(ref);

    return asyncList.dwBuildListAsync(
      loadingItemsCount: 5,
      childBuilder: (items) {
        if (asyncList.hasValue &&
            widget.onFirstLoadTrigger != null &&
            !isFirstLoadTriggered) {
          widget.onFirstLoadTrigger?.call(ref, items);
          isFirstLoadTriggered = true;
        }

        final displayItems =
            widget.groupBy != null
                ? widget.groupBy!(ref, items) // сгруппированные
                : items; // плоский список

        Widget itemBuilder(BuildContext context, int index) {
          final item = displayItems[index];

          if (item is DwInfiniteListViewGroupHeader) {
            final isFirstHeader = index == 0;

            if (isFirstHeader || widget.groupDivider == null) {
              return item.widget;
            } else {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  widget.groupDivider!, // 👈 вставляем перед заголовком
                  item.widget,
                ],
              );
            }
          } else if (item is DwInfiniteListViewGroupedModel<Entity>) {
            return widget.listTileBuilder(context, item.model);
          } else if (item is Entity) {
            return widget.listTileBuilder(context, item);
          }

          return const SizedBox.shrink();
        }

        return NotificationListener<ScrollNotification>(
          onNotification: (scrollInfo) {
            if (scrollInfo is ScrollUpdateNotification &&
                hasMaybeMore &&
                !isLoadingMore &&
                scrollInfo.metrics.pixels >=
                    scrollInfo.metrics.maxScrollExtent - 200) {
              setState(() => isLoadingMore = true);

              widget.listViewConfig.loadNextPage(ref).then((res) {
                if (mounted) {
                  setState(() {
                    hasMaybeMore = res;
                    isLoadingMore = false;
                  });
                }
              });
            }
            return false;
          },
          child:
              displayItems.isEmpty
                  ? widget.emptyListPlaceHolder
                  : widget.separatorBuilder != null
                  ? ListView.separated(
                    itemCount: displayItems.length,
                    itemBuilder: itemBuilder,
                    separatorBuilder: widget.separatorBuilder!,
                  )
                  : ListView.builder(
                    itemCount: displayItems.length,
                    itemBuilder: itemBuilder,
                  ),
        );
      },
    );
  }
}
