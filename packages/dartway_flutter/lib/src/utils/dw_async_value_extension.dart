import 'package:dartway_flutter/src/private/dw_singleton.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skeletonizer/skeletonizer.dart';

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
        dw.handleError(error, stackTrace);
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

        // 🧠 если дочерний виджет — sliver, используем SliverSkeletonizer
        if (built is SliverList ||
            built is SliverGrid ||
            built is SliverToBoxAdapter ||
            built is SliverPadding) {
          return SliverSkeletonizer(enabled: true, child: built);
        }

        // 🧩 иначе обычный box-режим
        return Skeletonizer(child: built);
      },
    );
  }
}
