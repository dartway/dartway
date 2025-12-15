import 'package:dartway_router/dartway_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

extension WidgetRefNavigationExtension on WidgetRef {
  T? watchNavigationParam<T>(NavigationParamsMixin<T> param) => param.get(
        watch(navigationPathParametersProvider),
      );

  T? readNavigationParam<T>(NavigationParamsMixin<T> param) => param.get(
        read(navigationPathParametersProvider),
      );

  menuItemTap(
    DwMenuItem item, {
    Map<String, String>? pathParameters,
  }) {
    if (item.customOnPressed != null) {
      item.customOnPressed!(this);
    } else if (item.route != null) {
      context.goNamed(
        item.route!.name,
        pathParameters: pathParameters ?? {},
      );
    }
  }
}

extension RefNavigationExtension on Ref {
  T? watchNavigationParam<T>(NavigationParamsMixin<T> param) => param.get(
        watch(navigationPathParametersProvider),
      );

  T? readNavigationParam<T>(NavigationParamsMixin<T> param) => param.get(
        read(navigationPathParametersProvider),
      );
}
