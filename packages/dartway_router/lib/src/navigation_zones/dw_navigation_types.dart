import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// A location a navigation hook is asked about: where a navigation was going
/// when a guard decides on it, or the location being left when a route's
/// exit hook decides whether to let it go.
///
/// A guard that turns someone away can name the place it turned them away
/// from — the one thing "back to it after signing in" needs (#288). An exit
/// hook ([DwNavigationExitGuard]) learns which route is being left and with
/// which parameters, so it can tell whether its question applies. The
/// router's own value rather than go_router's `GoRouterState`: a hook needs
/// the address, not the transport's whole state.
final class DwNavigationTarget {
  const DwNavigationTarget({
    required this.uri,
    this.routeName,
    this.pathParameters = const {},
  });

  /// The location, query included: `/orders/42?tab=items`. For a guard,
  /// the location asked for; for an exit hook, the location being left.
  final Uri uri;

  /// The name of the route it resolves to; `null` for a location no route
  /// of this router names. For an exit hook, the route being left — which
  /// may be a parent of the route [uri] shows, when it leaves together with
  /// a nested child.
  final String? routeName;

  /// The route's path parameters: `{'id': '42'}` for `/orders/:id`.
  final Map<String, String> pathParameters;

  /// [uri] as a string, to hand back to `go` later.
  String get location => uri.toString();

  @override
  bool operator ==(Object other) =>
      other is DwNavigationTarget &&
      other.uri == uri &&
      other.routeName == routeName &&
      _sameEntries(other.pathParameters, pathParameters);

  @override
  int get hashCode => Object.hash(
    uri,
    routeName,
    Object.hashAllUnordered(
      pathParameters.entries.map((e) => Object.hash(e.key, e.value)),
    ),
  );

  @override
  String toString() => 'DwNavigationTarget($location)';

  static bool _sameEntries(Map<String, String> a, Map<String, String> b) =>
      a.length == b.length && a.entries.every((e) => b[e.key] == e.value);
}

/// Type definition for navigation guards.
///
/// A guard is a function that can redirect navigation based on the router state.
/// Guards are executed in order when navigating to a route. If a guard returns
/// a non-null path, the user will be redirected to that path instead of the
/// intended route.
///
/// Guards receive the current [RouterState] value — what the router's
/// `routerState` provider holds — to check authentication, permissions or any
/// other condition, and the [DwNavigationTarget] being entered, so a guard
/// that says no can say where the person was going.
///
/// Return `null` to allow navigation to proceed, or return a path string to
/// redirect to a different route.
///
/// Example — a sign-in gate that brings the person back afterwards:
/// ```dart
/// List<DwNavigationGuard<AppSession>> get zoneGuards => [
///   (session, target) => session.isAuthenticated
///       ? null
///       : Uri(path: '/login', queryParameters: {'from': target.location})
///           .toString(),
/// ];
/// ```
typedef DwNavigationGuard<RouterState> = String? Function(
  RouterState state,
  DwNavigationTarget target,
);

/// Type definition for route exit hooks.
///
/// Set as [DwNavigationRouteDescriptor.onExit], it is asked before the person
/// leaves the route — on a pop, a system back, and on any change of address:
/// browser back and forward, a typed URL, a link, `go`. Return `true` to let
/// the navigation go on, `false` to keep the person on the route.
///
/// [context] is the navigator's context, so a sheet or a dialog opens from
/// it. [leaving] is the location being left, with the name and path
/// parameters of the route the hook belongs to. Where the person is going is
/// not known at this point.
///
/// Descriptors are `const`, so the hook is a static method or a top-level
/// function, not a closure. Whether to ask is a fact of app state — read it
/// through the context (a Riverpod `ProviderScope.containerOf(context)`)
/// rather than from the page.
///
/// Example:
/// ```dart
/// Future<bool> askBeforeLeavingCourse(
///   BuildContext context,
///   DwNavigationTarget leaving,
/// ) async {
///   final container = ProviderScope.containerOf(context);
///   if (!container.read(pendingRatingProvider)) return true;
///   final answer = await showModalBottomSheet<bool>(
///     context: context,
///     builder: (_) => const RateLessonSheet(),
///   );
///   return answer ?? false;
/// }
/// ```
typedef DwNavigationExitGuard = FutureOr<bool> Function(
  BuildContext context,
  DwNavigationTarget leaving,
);

/// Type definition for shell route page builders.
///
/// A shell route builder wraps child routes in a common UI shell, such as
/// a scaffold with a bottom navigation bar, sidebar, or persistent header.
/// Navigation state is **not** preserved when switching tabs — the page
/// is rebuilt each time. For state-preserving tabs use [DwStatefulShellRouteBuilder].
///
/// The builder receives:
/// - [context] - The build context
/// - [state] - The current GoRouter state
/// - [child] - The child widget (the actual route content)
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

/// Type definition for stateful shell route page builders.
///
/// Used with [DwNavigationRoute.statefulShellRouteBuilder] to create a
/// [StatefulShellRoute] where each root route of the zone is an independent
/// navigation branch. Each branch keeps its own navigator stack, so navigation
/// state is **preserved** when the user switches tabs.
///
/// Unlike [DwShellRoutePageBuilder], the builder receives a
/// [StatefulNavigationShell] instead of a plain [Widget] child:
/// - [StatefulNavigationShell.currentIndex] — index of the active branch
/// - [StatefulNavigationShell.goBranch] — switch to a branch by index
/// - The shell itself is the body widget
///
/// Example:
/// ```dart
/// @override
/// DwStatefulShellRouteBuilder? get statefulShellRouteBuilder =>
///     (context, state, navigationShell) {
///       return MaterialPage(
///         child: Scaffold(
///           body: navigationShell,
///           bottomNavigationBar: BottomNavigationBar(
///             currentIndex: navigationShell.currentIndex,
///             onTap: (i) => navigationShell.goBranch(
///               i,
///               initialLocation: i == navigationShell.currentIndex,
///             ),
///             items: const [
///               BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
///               BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
///             ],
///           ),
///         ),
///       );
///     };
/// ```
typedef DwStatefulShellRouteBuilder = Page<dynamic> Function(
  BuildContext context,
  GoRouterState state,
  StatefulNavigationShell navigationShell,
);
