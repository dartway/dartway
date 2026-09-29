import 'dart:async';

import 'package:dartway_client/dartway_client.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/dw_flutter_core.dart';
import '../../data/dw_request_notifiers.dart';
import '../../private/dw_singleton.dart';
import 'dw_read_states.dart';

/// A list over `dw.pages(request)` — a feed read page by page, the next page
/// loaded as the end of the list comes near.
///
/// ```dart
/// DwPagedListView(
///   request: const ListNewsPosts(),
///   placeholder: NewsPostTile.placeholder,
///   emptyBuilder: (context) => AppEmptyBlock(title: context.l10n.noNews),
///   itemBuilder: (context, post) => NewsPostTile(post),
/// )
/// ```
///
/// **When the next page loads.** The slot after the last loaded row is built
/// lazily, like the rows: it is built when it comes within the scroll view's
/// cache extent, and building it asks for the next page. So the next page is
/// asked for as the person nears the end, a short first page that leaves the
/// slot on screen fills the screen page by page, and no scroll listener or
/// threshold is written by the screen. Asking while a page is in flight, or
/// when there is no more, costs nothing (`DwPagesNotifier.loadMore`). After a
/// failed page the slot shows a retry instead of asking again by itself.
///
/// The first answer shows what `DwReadBuilder` shows: [itemBuilder] over
/// [placeholder] as [placeholderCount] skeleton rows, or the app's
/// `readLoadingBuilder`; a refusal [onRefused] names, that branch; any other
/// refusal or failure, the app's `readFailedBuilder` with a retry. [header]
/// scrolls with the rows and stays on screen through all of them.
///
/// Rows follow the server live, as the read does. Pull to refresh is the
/// read's own: `ref.read(dw.pages(request).notifier).refetch()`.
class DwPagedListView<T extends DwDataObject> extends ConsumerWidget {
  const DwPagedListView({
    super.key,
    required this.request,
    required this.itemBuilder,
    required this.emptyBuilder,
    this.placeholder,
    this.placeholderCount = 3,
    this.onRefused = const {},
    this.header,
    this.edgeBuilder,
    this.padding = EdgeInsets.zero,
    this.controller,
    this.primary,
    this.physics,
  }) : assert(placeholderCount > 0, 'placeholderCount is a number of rows');

  final DwPageRequest<T> request;

  /// One row.
  final Widget Function(BuildContext context, T item) itemBuilder;

  /// When the read answered with no rows. New rows arriving live replace it.
  final WidgetBuilder emptyBuilder;

  /// A stand-in row the loading skeleton is drawn from, through
  /// [itemBuilder], [placeholderCount] times. Without it the app's
  /// `readLoadingBuilder` shows.
  final T? placeholder;

  final int placeholderCount;

  /// A branch per refusal code of the first answer, as in `DwReadBuilder`.
  final Map<DwRefusalCode, DwRefusedBuilder> onRefused;

  /// Above the rows, scrolled with them.
  final Widget? header;

  /// The slot past the last loaded row while there is more: loading, idle,
  /// or [error] with [retry] when the last page failed. Default: 48 pixels
  /// holding a small indicator while loading, or a retry button — the same
  /// slot as `DwWindowListView`'s. Keep its height constant.
  final Widget Function(BuildContext context, Object? error, VoidCallback retry)?
  edgeBuilder;

  /// Space inside the scrollable around the rows.
  final EdgeInsets padding;

  final ScrollController? controller;
  final bool? primary;
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = (dw as DwFlutterCore).pages(request);
    final Widget body;
    switch (ref.watch(provider)) {
      case AsyncData(:final value):
        body = _rows(context, ref, provider, value);
      case AsyncError(:final error, :final stackTrace):
        body = _fill(
          DwReadStates.failed(
            context,
            error,
            stackTrace,
            retry: () => ref.read(provider.notifier).refetch(),
            onRefused: onRefused,
          ),
        );
      case AsyncLoading():
        final stand = placeholder;
        body = stand == null
            ? _fill(DwReadStates.loading(context))
            : DwReadStates.loading(
                context,
                placeholder: SliverList.builder(
                  itemCount: placeholderCount,
                  itemBuilder: (context, _) => itemBuilder(context, stand),
                ),
              );
    }
    return CustomScrollView(
      controller: controller,
      primary: primary,
      physics: physics,
      slivers: [
        if (header case final header?) SliverToBoxAdapter(child: header),
        SliverPadding(padding: padding, sliver: body),
      ],
    );
  }

  Widget _rows(
    BuildContext context,
    WidgetRef ref,
    DwPagesProvider<T> provider,
    DwPagedData<T> data,
  ) {
    final items = data.items;
    if (items.isEmpty) return _fill(emptyBuilder(context));
    void loadMore() => unawaited(ref.read(provider.notifier).loadMore());
    return SliverList.builder(
      itemCount: items.length + (data.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index < items.length) return itemBuilder(context, items[index]);
        final error = data.loadMoreError;
        if (error == null && !data.loadingMore) {
          // Built means near: the slot comes into the cache extent. The
          // notifier is not changed while the tree is laid out.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) loadMore();
          });
        }
        return edgeBuilder?.call(context, error, loadMore) ??
            DwReadStates.edge(
              loading: data.loadingMore,
              error: error,
              retry: loadMore,
            );
      },
    );
  }

  static Widget _fill(Widget child) =>
      SliverFillRemaining(hasScrollBody: false, child: child);
}
