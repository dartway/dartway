import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Mixin for type-safe navigation parameters.
///
/// This mixin provides methods for extracting typed parameters from navigation
/// state (path parameters, query parameters, and extra data) and for building
/// parameter maps for navigation.
///
/// The type parameter [T] specifies the parameter type. Supported types are:
/// - [String]
/// - [int]
/// - [double]
/// - [bool]
///
/// Example usage:
/// ```dart
/// enum AppParams<T> with DwNavigationParamsMixin<T> {
///   userId<int>(),
///   userName<String>(),
///   price<double>(),
///   isActive<bool>(),
/// }
///
/// // In a widget:
/// final userId = AppParams.userId.fromPath(context);
/// final searchQuery = AppParams.userName.fromQueryOrNull(context);
///
/// // For navigation:
/// context.go('/user/${AppParams.userId.set(123)}');
/// ```
mixin DwNavigationParamsMixin<T> on Enum {
  /// Creates a map with this parameter's name and value for navigation.
  ///
  /// This is useful for building path parameters or query parameters when
  /// navigating to routes that require parameters.
  ///
  /// Example:
  /// ```dart
  /// final params = AppParams.userId.set(123);
  /// // Returns: {'userId': '123'}
  /// ```
  ///
  /// The value is converted to a string using [toString()].
  Map<String, String> set(T value) => {
        name: value.toString(),
      };

  // ---------------------------
  // Path Parameters
  // ---------------------------

  /// Extracts the parameter value from the route's path parameters.
  ///
  /// Returns `null` if the parameter is not present in the path.
  /// Use [fromPath] if you want an exception to be thrown when the parameter
  /// is missing.
  ///
  /// Example:
  /// ```dart
  /// // For route '/user/:userId'
  /// final userId = AppParams.userId.fromPathOrNull(context);
  /// if (userId != null) {
  ///   // Use userId
  /// }
  /// ```
  T? fromPathOrNull(BuildContext context) {
    final value = GoRouterState.of(context).pathParameters[name];
    return _cast(value);
  }

  /// Extracts the parameter value from the route's path parameters.
  ///
  /// Throws [ArgumentError] if the parameter is not present in the path.
  /// Use [fromPathOrNull] if you want to handle missing parameters gracefully.
  ///
  /// Example:
  /// ```dart
  /// // For route '/user/:userId'
  /// final userId = AppParams.userId.fromPath(context);
  /// // userId is guaranteed to be non-null
  /// ```
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
  // Query Parameters
  // ---------------------------

  /// Extracts the parameter value from the URL's query parameters.
  ///
  /// Returns `null` if the parameter is not present in the query string.
  /// Use [fromQuery] if you want an exception to be thrown when the parameter
  /// is missing.
  ///
  /// Example:
  /// ```dart
  /// // For URL '/search?query=flutter'
  /// final query = AppParams.query.fromQueryOrNull(context);
  /// ```
  T? fromQueryOrNull(BuildContext context) {
    final value = GoRouterState.of(context).uri.queryParameters[name];
    return _cast(value);
  }

  /// Extracts the parameter value from the URL's query parameters.
  ///
  /// Throws [ArgumentError] if the parameter is not present in the query string.
  /// Use [fromQueryOrNull] if you want to handle missing parameters gracefully.
  ///
  /// Example:
  /// ```dart
  /// // For URL '/search?query=flutter'
  /// final query = AppParams.query.fromQuery(context);
  /// ```
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
  // Extra Data
  // ---------------------------

  /// Extracts the parameter value from the route's extra data.
  ///
  /// Returns `null` if no extra data was provided or if the extra data
  /// cannot be cast to type [T].
  ///
  /// Extra data is passed when navigating using `context.go(path, extra: data)`
  /// or `context.push(path, extra: data)`.
  ///
  /// Example:
  /// ```dart
  /// // When navigating: context.go('/detail', extra: 123)
  /// final id = AppParams.userId.fromExtra(context);
  /// ```
  T? fromExtra(BuildContext context) {
    final extra = GoRouterState.of(context).extra;
    if (extra == null) return null;
    return extra as T;
  }

  // ---------------------------
  // Type Casting
  // ---------------------------

  /// Casts a string value to the parameter type [T].
  ///
  /// Supports [String], [int], [double], and [bool] types.
  /// Returns `null` if the value is `null`.
  /// Throws [UnsupportedError] for unsupported types.
  ///
  /// For [bool], the string 'true' (case-insensitive) is converted to `true`,
  /// all other values are converted to `false`.
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
