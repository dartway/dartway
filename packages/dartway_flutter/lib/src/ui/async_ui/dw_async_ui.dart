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
      // A factory, not a value: the placeholder list — and the assert that it
      // can be built at all — must not run on the data and error branches. A
      // widget test of a list screen would otherwise need the app's model
      // registry standing up to render an AsyncData it already holds.
      loadingValueBuilder: () {
        assert(
          loadingItem != null || dw.isDefaultModelsGetterSetUp,
          'Cannot build a loading value for dwBuildListAsync: either pass '
          'loadingItem, or set DwConfig.defaultModelGetter.',
        );

        return List.generate(
          loadingItemsCount,
          (_) =>
              loadingItem ?? (null is T ? null as T : dw.getDefaultModel<T>()),
        );
      },
      loadingWidget: loadingWidget,
      skipLoadingOnReload: skipLoadingOnReload,
      skipLoadingOnRefresh: skipLoadingOnRefresh,
    );
  }
}

/// The single implementation both public builders delegate to. The loading
/// placeholder arrives as a factory so that nothing it needs — the default-model
/// registry above all — is touched unless the loading branch actually renders.
/// A null [loadingValueBuilder] means the caller supplied no placeholder.
Widget _dwBuildAsync<T>(
  AsyncValue<T> value, {
  required Widget Function(T value) childBuilder,
  required Widget errorWidget,
  required Widget Function(Object error, StackTrace stackTrace)? errorBuilder,
  required T Function()? loadingValueBuilder,
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

      if (loadingValueBuilder == null && !dw.isDefaultModelsGetterSetUp) {
        return const SizedBox.shrink();
      }

      final fakeData = loadingValueBuilder != null
          ? loadingValueBuilder()
          : (null is T ? null as T : dw.getDefaultModel<T>());

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
