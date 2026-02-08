import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Runtime configuration options for the underlying [GoRouter].
///
/// These options are passed through to [GoRouter] when [DwRouter] builds
/// its router. See [GoRouter] and [GoRouterDelegate] for semantics of
/// each option.
class DwGoRouterOptions {
  /// Default value for [redirectLimit] when not specified.
  ///
  /// Matches [GoRouter]'s default to avoid infinite redirect loops.
  static const int defaultRedirectLimit = 5;

  /// Creates options for the underlying [GoRouter].
  const DwGoRouterOptions({
    this.navigatorKey,
    this.initialLocation,
    this.initialExtra,
    this.errorBuilder,
    this.redirect,
    this.redirectLimit = defaultRedirectLimit,
    this.routerNeglect = false,
    this.debugLogDiagnostics = false,
    this.overridePlatformDefaultLocation = false,
    this.requestFocus = true,
    this.restorationScopeId,
    this.observers,
    this.onException,
    this.extraCodec,
  });

  /// Optional [GlobalKey] for the root navigator.
  final GlobalKey<NavigatorState>? navigatorKey;

  /// Initial location (path) when the router is created.
  final String? initialLocation;

  /// Initial extra state passed to the first route.
  final Object? initialExtra;

  /// Builder for the error page when no route matches or navigation fails.
  final Widget Function(BuildContext, GoRouterState)? errorBuilder;

  /// Optional global redirect; can override the current location.
  final String? Function(
    BuildContext context,
    GoRouterState state,
  )? redirect;

  /// Maximum number of redirects before treating as a redirect loop.
  final int redirectLimit;

  /// Whether the router should neglect handling back button / system nav.
  final bool routerNeglect;

  /// When true, logs routing diagnostics to the console (e.g. redirects, matches).
  final bool debugLogDiagnostics;

  /// Whether to override the platform default deep link location.
  final bool overridePlatformDefaultLocation;

  /// Whether to request focus after navigation.
  final bool requestFocus;

  /// Optional restoration scope id for state restoration.
  final String? restorationScopeId;

  /// Optional list of [NavigatorObserver]s for the root navigator.
  final List<NavigatorObserver>? observers;

  /// Callback when the router encounters an exception.
  final void Function(
    BuildContext context,
    GoRouterState state,
    GoRouter router,
  )? onException;

  /// Optional codec for encoding/decoding [extra] state in the location.
  final Codec<Object?, Object?>? extraCodec;
}
