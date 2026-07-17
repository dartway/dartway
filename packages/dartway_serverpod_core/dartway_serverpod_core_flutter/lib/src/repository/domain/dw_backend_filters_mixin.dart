import 'package:dartway_serverpod_core_client/dartway_serverpod_core_client.dart';

mixin DwBackendFiltersMixin<T> on Enum {
  DwBackendFilter<T> equals(T? value, {bool negate = false}) =>
      DwBackendFilter<T>.value(
        type: DwBackendFilterType.equals,
        fieldName: name,
        fieldValue: value,
        negate: negate,
      );

  static const comparisonFiltersTypeErrorText =
      'Unsupported value type, comparison filters are supported for int, double and DateTime value types only (currently)';

  DwBackendFilter<T> greaterThan(T value, {bool negate = false}) =>
      (T != int && T != double && T != DateTime)
          ? throw UnsupportedError(comparisonFiltersTypeErrorText)
          : DwBackendFilter<T>.value(
            type: DwBackendFilterType.greaterThan,
            fieldName: name,
            fieldValue: value,
            negate: negate,
          );

  DwBackendFilter<T> greaterThanOrEquals(T value, {bool negate = false}) =>
      (T != int && T != double && T != DateTime)
          ? throw UnsupportedError(comparisonFiltersTypeErrorText)
          : DwBackendFilter<T>.value(
            type: DwBackendFilterType.greaterThanOrEquals,
            fieldName: name,
            fieldValue: value,
            negate: negate,
          );

  DwBackendFilter<T> lessThan(T value, {bool negate = false}) =>
      (T != int && T != double && T != DateTime)
          ? throw UnsupportedError(comparisonFiltersTypeErrorText)
          : DwBackendFilter<T>.value(
            type: DwBackendFilterType.lessThan,
            fieldName: name,
            fieldValue: value,
            negate: negate,
          );

  DwBackendFilter<T> lessThanOrEquals(T value, {bool negate = false}) =>
      (T != int && T != double && T != DateTime)
          ? throw UnsupportedError(comparisonFiltersTypeErrorText)
          : DwBackendFilter<T>.value(
            type: DwBackendFilterType.lessThanOrEquals,
            fieldName: name,
            fieldValue: value,
            negate: negate,
          );

  DwBackendFilter<String> like(String value, {bool negate = false}) =>
      DwBackendFilter.value(
        type: DwBackendFilterType.like,
        fieldName: name,
        fieldValue: value,
        negate: negate,
      );

  DwBackendFilter<String> ilike(String value, {bool negate = false}) =>
      DwBackendFilter.value(
        type: DwBackendFilterType.ilike,
        fieldName: name,
        fieldValue: value,
        negate: negate,
      );
}
