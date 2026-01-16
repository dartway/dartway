import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Mixin for type-safe navigation parameters
mixin DwNavigationParamsMixin<T> on Enum {
  /// Set parameter value for navigation (for query/path building)
  Map<String, String> set(T value) => {
        name: value.toString(),
      };

  // ---------------------------
  // Path
  // ---------------------------

  T? fromPathOrNull(BuildContext context) {
    final value = GoRouterState.of(context).pathParameters[name];
    return _cast(value);
  }

  T fromPath(BuildContext context) {
    final result = fromPathOrNull(context);
    if (result == null) {
      throw ArgumentError(
        'Missing required path param "$name" for route',
      );
    }
    return result;
  }

  // ---------------------------
  // Query
  // ---------------------------

  T? fromQueryOrNull(BuildContext context) {
    final value = GoRouterState.of(context).uri.queryParameters[name];
    return _cast(value);
  }

  T fromQuery(BuildContext context) {
    final result = fromQueryOrNull(context);
    if (result == null) {
      throw ArgumentError(
        'Missing required query param "$name" for route',
      );
    }
    return result;
  }

  // ---------------------------
  // Extra
  // ---------------------------

  T? fromExtra(BuildContext context) {
    final extra = GoRouterState.of(context).extra;
    if (extra == null) return null;
    return extra as T;
  }

  // ---------------------------
  // Cast
  // ---------------------------

  T? _cast(String? value) {
    if (value == null) return null;

    if (T == String) return value as T;
    if (T == int) return int.tryParse(value) as T?;
    if (T == double) return double.tryParse(value) as T?;
    if (T == bool) return (value == 'true') as T;

    throw UnsupportedError(
      'Unsupported navigation param type: $T',
    );
  }
}
