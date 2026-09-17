import 'package:dartway_core_flutter/src/diagnostics/error_reporting/dw_error_report.dart';
import 'package:dartway_core_flutter/src/private/dw_singleton.dart';
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
    Widget Function(Object error, StackTrace stackTrace)? errorBuilder,
    T? loadingValue,
    Widget? loadingWidget,
    bool skipLoadingOnReload = false,
    bool skipLoadingOnRefresh = true,
  }) {
    final placeholder = loadingValue;

    return _dwBuildAsync<T>(
      this,
      childBuilder: childBuilder,
      errorWidget: errorWidget,
      errorBuilder: errorBuilder,
      loadingValueBuilder: placeholder == null ? null : () => placeholder,
      registryValueBuilder: () =>
          null is T ? null as T : dw.getDefaultModel<T>(),
      loadingWidget: loadingWidget,
      skipLoadingOnReload: skipLoadingOnReload,
      skipLoadingOnRefresh: skipLoadingOnRefresh,
    );
  }
}

/// The list variant of [DwAsyncValueX.dwBuildAsync]: the loading branch renders
/// [loadingItemsCount] skeleton items built from a placeholder model.
extension DwAsyncValueListX<T> on AsyncValue<List<T>> {
  Widget dwBuildListAsync({
    required Widget Function(List<T> value) childBuilder,
    int loadingItemsCount = 3,
    T? loadingItem,
    Widget? loadingWidget,
    Widget errorWidget = const SizedBox.shrink(),
    Widget Function(Object error, StackTrace stackTrace)? errorBuilder,
    bool skipLoadingOnReload = false,
    bool skipLoadingOnRefresh = true,
  }) {
    return _dwBuildAsync<List<T>>(
      this,
      childBuilder: childBuilder,
      errorWidget: errorWidget,
      errorBuilder: errorBuilder,
      // Factories, not values: the placeholder list — and the registry it may
      // need — must not be touched on the data and error branches. A widget
      // test of a list screen would otherwise need the app's model registry
      // standing up to render an AsyncData it already holds.
      loadingValueBuilder: loadingItem == null
          ? null
          : () => List.filled(loadingItemsCount, loadingItem),
      registryValueBuilder: () => List.generate(
        loadingItemsCount,
        (_) => null is T ? null as T : dw.getDefaultModel<T>(),
      ),
      loadingWidget: loadingWidget,
      skipLoadingOnReload: skipLoadingOnReload,
      skipLoadingOnRefresh: skipLoadingOnRefresh,
    );
  }
}

/// The single implementation both public builders delegate to. The loading
/// placeholder arrives as a factory so that nothing it needs — the default-model
/// registry above all — is touched unless the loading branch actually renders.
/// A null [loadingValueBuilder] means the caller supplied no placeholder; the
/// app's registry ([registryValueBuilder]) is asked then. When it has no
/// placeholder for the type — no getter configured, or a getter that does not
/// know the model — the loading branch is empty, as it is for a single value:
/// a skeleton is an improvement on nothing, never a reason for an error block
/// where a list is about to appear.
Widget _dwBuildAsync<T>(
  AsyncValue<T> value, {
  required Widget Function(T value) childBuilder,
  required Widget errorWidget,
  required Widget Function(Object error, StackTrace stackTrace)? errorBuilder,
  required T Function()? loadingValueBuilder,
  required T Function() registryValueBuilder,
  required Widget? loadingWidget,
  required bool skipLoadingOnReload,
  required bool skipLoadingOnRefresh,
}) {
  return value.when(
    skipLoadingOnReload: skipLoadingOnReload,
    skipLoadingOnRefresh: skipLoadingOnRefresh,
    data: (data) => childBuilder(data),
    error: (error, stackTrace) {
      dw.handleError(error, stackTrace, source: DwErrorSource.asyncBuild);
      return errorBuilder?.call(error, stackTrace) ?? errorWidget;
    },
    loading: () {
      if (loadingWidget != null) return loadingWidget;

      final T fakeData;
      if (loadingValueBuilder != null) {
        fakeData = loadingValueBuilder();
      } else {
        if (!dw.isDefaultModelsGetterSetUp) return const SizedBox.shrink();
        try {
          fakeData = registryValueBuilder();
        } catch (_) {
          // The registry does not know this model: no skeleton, not an error.
          return const SizedBox.shrink();
        }
      }

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
