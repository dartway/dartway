import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Type definition for navigation guards.
///
/// A guard is a function that can redirect navigation based on the router state.
/// Guards are executed in order when navigating to a route. If a guard returns
/// a non-null path, the user will be redirected to that path instead of the
/// intended route.
///
/// Guards receive the [RouterState] instance (which extends [Listenable]) and
/// can check authentication, permissions, or any other condition.
///
/// Return `null` to allow navigation to proceed, or return a path string to
/// redirect to a different route.
///
/// Example:
/// ```dart
/// List<DwNavigationGuard<AppSession>> get zoneGuards => [
///   (session) {
///     if (!session.isAuthenticated) {
///       return '/login';
///     }
///     return null; // Allow navigation
///   },
/// ];
/// ```
typedef DwNavigationGuard<RouterState extends Listenable> = String? Function(
  RouterState refreshListenable,
);

/// Type definition for shell route page builders.
///
/// A shell route builder wraps child routes in a common UI shell, such as
/// a scaffold with a bottom navigation bar, sidebar, or persistent header.
///
/// The builder receives:
/// - [context] - The build context
/// - [state] - The current GoRouter state
/// - [child] - The child widget (the actual route content)
///
/// It should return a [Page] that wraps the child in the desired shell UI.
///
/// Example:
/// ```dart
/// DwShellRoutePageBuilder? get shellRouteBuilder =>
///     (context, state, child) {
///       return MaterialPage(
///         child: Scaffold(
///           body: child,
///           bottomNavigationBar: MyBottomNav(),
///         ),
///       );
///     };
/// ```
typedef DwShellRoutePageBuilder = Page<dynamic> Function(
  BuildContext context,
  GoRouterState state,
  Widget child,
);
