import 'package:dartway_flutter/src/diagnostics/error_reporting/dw_error_report.dart';
import 'package:dartway_flutter/src/private/dw_singleton.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// The async-UI contract: render an `AsyncValue`'s loading / error / data
/// branches uniformly. The loading branch is a skeleton derived from your real
/// widget (built against a placeholder value), not a spinner; an error is
/// routed into the dw error pipeline and replaced by [errorWidget].
extension DwAsyncValueX<T> on AsyncValue<T> {
  Widget dwBuildAsync({
    required Widget Function(T value) childBuilder,
    Widget errorWidget = const SizedBox.shrink(),
    T? loadingValue,
    Widget? loadingWidget,
    bool skipLoadingOnReload = false,
    bool skipLoadingOnRefresh = true,
  }) {
    return when(
      skipLoadingOnReload: skipLoadingOnReload,
      skipLoadingOnRefresh: skipLoadingOnRefresh,
      data: (data) => childBuilder(data),
      error: (error, stackTrace) {
        dw.handleError(error, stackTrace, source: DwErrorSource.asyncBuild);
        return errorWidget;
      },
      loading: () {
        if (loadingWidget != null) return loadingWidget;

        if (loadingValue == null && !dw.isDefaultModelsGetterSetUp) {
          return const SizedBox.shrink();
        }

        final fakeData =
            loadingValue ?? (null is T ? null as T : dw.getDefaultModel<T>());

        final built = childBuilder(fakeData);

        // A sliver child needs the sliver-flavoured skeletonizer: the box one
        // would be an invalid child for the enclosing CustomScrollView.
        if (built is SliverList ||
            built is SliverGrid ||
            built is SliverToBoxAdapter ||
            built is SliverPadding) {
          return SliverSkeletonizer(enabled: true, child: built);
        }

        return Skeletonizer(child: built);
      },
    );
  }
}

/// The list variant of [dwBuildAsync]: generates [loadingItemsCount] skeleton
/// items from a placeholder model, then delegates to [dwBuildAsync].
extension DwAsyncValueListX<T> on AsyncValue<List<T>> {
  Widget dwBuildListAsync({
    required Widget Function(List<T> value) childBuilder,
    int loadingItemsCount = 3,
    T? loadingItem,
    Widget? loadingWidget,
    Widget errorWidget = const SizedBox.shrink(),
    bool skipLoadingOnReload = false,
    bool skipLoadingOnRefresh = true,
  }) {
    assert(
      loadingItem != null || dw.isDefaultModelsGetterSetUp,
      'Cannot build a loading value for dwBuildListAsync: either pass '
      'loadingItem, or set DwConfig.defaultModelGetter.',
    );

    final items = List.generate(
      loadingItemsCount,
      (_) => loadingItem ?? (null is T ? null as T : dw.getDefaultModel<T>()),
    );

    return dwBuildAsync(
      childBuilder: childBuilder,
      loadingValue: items,
      loadingWidget: loadingWidget,
      errorWidget: errorWidget,
      skipLoadingOnReload: skipLoadingOnReload,
      skipLoadingOnRefresh: skipLoadingOnRefresh,
    );
  }
}
