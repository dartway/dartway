import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class DwGoRouterOptions {
  static const int defaultRedirectLimit = 5;

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

  final GlobalKey<NavigatorState>? navigatorKey;
  final String? initialLocation;
  final Object? initialExtra;

  final Widget Function(BuildContext, GoRouterState)? errorBuilder;

  final String? Function(
    BuildContext context,
    GoRouterState state,
  )? redirect;

  final int redirectLimit;
  final bool routerNeglect;
  final bool debugLogDiagnostics;

  final bool overridePlatformDefaultLocation;
  final bool requestFocus;
  final String? restorationScopeId;

  final List<NavigatorObserver>? observers;

  final void Function(
    BuildContext context,
    GoRouterState state,
    GoRouter router,
  )? onException;

  final Codec<Object?, Object?>? extraCodec;
}
