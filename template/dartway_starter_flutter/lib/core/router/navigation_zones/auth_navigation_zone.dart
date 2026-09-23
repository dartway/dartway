part of '../router.dart';

/// Auth zone. Guard sends a signed-in user on to where a gate turned them
/// away from ([signInFrom]), or to the app zone.
enum AuthNavigationZone implements DwNavigationRoute<AppRouterState> {
  auth(DwNavigationRouteDescriptor.simple(pageWidget: AuthPage()));

  const AuthNavigationZone(this.descriptor);

  @override
  final DwNavigationRouteDescriptor<AppRouterState> descriptor;

  @override
  String get zoneRoot => '';

  @override
  DwShellRoutePageBuilder? get shellRouteBuilder => null;

  @override
  DwStatefulShellRouteBuilder? get statefulShellRouteBuilder => null;

  @override
  List<DwNavigationGuard<AppRouterState>> get zoneGuards => [
    (state, target) => state.isSignedIn
        ? _returnTo(target) ?? AppNavigationZone.home.fullPath
        : null,
  ];

  /// Sign-in, remembering [target] — what a gate says to someone signed out,
  /// so a link opened without a session still ends where it pointed.
  static String signInFrom(DwNavigationTarget target) => Uri(
    path: auth.fullPath,
    queryParameters: target.location == '/' ? null : {'from': target.location},
  ).toString();

  /// The location [signInFrom] remembered on this sign-in page, when it is
  /// one of this app's own paths.
  static String? _returnTo(DwNavigationTarget target) {
    final from = target.uri.queryParameters['from'];
    final ownPath =
        from != null && from.startsWith('/') && !from.startsWith('//');
    return ownPath ? from : null;
  }
}
