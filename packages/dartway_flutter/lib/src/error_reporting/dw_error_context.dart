import 'package:flutter/foundation.dart';

import '../features/dw_feature_scanner.dart';

/// Immutable snapshot of the app state captured at the moment an error is
/// reported. On web builds the stack trace is minified noise — this snapshot
/// is what makes the report actionable.
class DwErrorContextSnapshot {
  const DwErrorContextSnapshot({
    required this.platform,
    this.appVersion,
    this.route,
    this.featureIds = const [],
    this.entries = const {},
  });

  /// `web/android`, `web/ios`, `android`, `ios`, `macos`, ...
  final String platform;

  final String? appVersion;

  /// Current route path, when a route source is registered.
  final String? route;

  /// Ids of the `DwFeature` widgets mounted on the current screen.
  final List<String> featureIds;

  /// App-defined entries (user, tenant, ...), insertion-ordered.
  final Map<String, String> entries;
}

/// Registry of lazy context sources, pulled once per error report. Every
/// source runs under try/catch — a broken provider is skipped and can never
/// break error reporting itself.
class DwErrorContext {
  String Function()? _routeSource;
  final Map<String, String? Function()> _providers = {};

  /// The framework has no access to the app's router — register a lazy getter
  /// once, e.g.:
  /// ```dart
  /// dw.errorContext.registerRouteSource(
  ///   () => router.routerDelegate.currentConfiguration.uri.path,
  /// );
  /// ```
  /// Re-registering replaces the previous source.
  void registerRouteSource(String Function() currentRoute) =>
      _routeSource = currentRoute;

  /// Registers a lazy entry (`'user'`, `'tenant'`, ...). A `null` result
  /// omits the entry from the snapshot. Re-registering replaces the provider.
  void register(String key, String? Function() provider) =>
      _providers[key] = provider;

  /// Sets a static entry; `null` removes it. Sugar over [register].
  void set(String key, String? value) {
    if (value == null) {
      _providers.remove(key);
    } else {
      _providers[key] = () => value;
    }
  }

  /// Captures the current app state. Never throws.
  DwErrorContextSnapshot capture({String? appVersion}) {
    final entries = <String, String>{};
    for (final entry in _providers.entries) {
      try {
        final value = entry.value();
        if (value != null) entries[entry.key] = value;
      } catch (_) {
        // A context provider must never break error reporting.
      }
    }

    return DwErrorContextSnapshot(
      platform: kIsWeb
          ? 'web/${defaultTargetPlatform.name}'
          : defaultTargetPlatform.name,
      appVersion: appVersion,
      route: _guard(_routeSource),
      featureIds: _capturedFeatureIds(),
      entries: entries,
    );
  }

  static String? _guard(String Function()? source) {
    if (source == null) return null;
    try {
      return source();
    } catch (_) {
      return null;
    }
  }

  static List<String> _capturedFeatureIds() {
    try {
      return [for (final feature in scanMountedFeatures()) feature.id];
    } catch (_) {
      return const [];
    }
  }
}
