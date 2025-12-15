import 'package:dartway_router/dartway_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Configuration builder for DwRouter
class DwRouterConfig {
  final List<List<NavigationZoneRoute>> _navigationZones = [];
  Widget? _notFoundPageWidget;
  String? _initialLocation;
  Listenable? _refreshListenable;
  NavigationZoneRoute? Function(
      BuildContext context, NavigationZoneRoute? route)? _redirect;
  NavigationZoneRoute? Function(BuildContext context, GoRouterState state)?
      _manualRedirect;
  DwPageBuilder _pageFactory = DwPageBuilders.material;
  Provider<RedirectsStateModel>? redirectsProvider;

  /// Add navigation zones
  DwRouterConfig addNavigationZones(List<List<NavigationZoneRoute>> zones) {
    _navigationZones.addAll(zones);
    return this;
  }

  /// Set the not found page widget
  DwRouterConfig setNotFoundPage(Widget notFoundPage) {
    _notFoundPageWidget = notFoundPage;
    return this;
  }

  /// Set initial location
  DwRouterConfig setInitialLocation(String location) {
    _initialLocation = location;
    return this;
  }

  /// Set refresh listenable
  DwRouterConfig setRefreshListenable(Listenable listenable) {
    _refreshListenable = listenable;
    return this;
  }

  /// Set redirect function
  DwRouterConfig setRedirect(
      NavigationZoneRoute? Function(
              BuildContext context, NavigationZoneRoute? route)
          redirect) {
    _redirect = redirect;
    return this;
  }

  /// Set manual redirect function
  DwRouterConfig setManualRedirect(
      NavigationZoneRoute? Function(BuildContext context, GoRouterState state)
          redirect) {
    _manualRedirect = redirect;
    return this;
  }

  /// Set page factory
  DwRouterConfig setPageFactory(DwPageBuilder factory) {
    _pageFactory = factory;
    return this;
  }

  /// Set redirects provider
  DwRouterConfig setRedirectsProvider(Provider<RedirectsStateModel> provider) {
    redirectsProvider = provider;
    return this;
  }

  /// Create a copy of this config with redirects applied
  DwRouterConfig withRedirects(RedirectsStateModel? redirects) {
    final newConfig = DwRouter.config();

    // Copy all settings
    newConfig.addNavigationZones(_navigationZones);

    if (_notFoundPageWidget != null) {
      newConfig.setNotFoundPage(_notFoundPageWidget!);
    }

    if (_initialLocation != null) {
      newConfig.setInitialLocation(_initialLocation!);
    }

    if (_refreshListenable != null) {
      newConfig.setRefreshListenable(_refreshListenable!);
    }

    if (_redirect != null) {
      newConfig.setRedirect(_redirect!);
    }

    if (_manualRedirect != null) {
      newConfig.setManualRedirect(_manualRedirect!);
    }

    newConfig.setPageFactory(_pageFactory);

    // Apply redirects if available
    if (redirects != null) {
      newConfig.setRedirect((context, route) {
        return redirects.redirects[route];
      });
    }

    return newConfig;
  }

  /// Build the GoRouter
  GoRouter build() {
    _validateConfiguration();

    return DwRouter.prepareRouter(
      navigationZones: _navigationZones,
      notFoundPageWidget: _notFoundPageWidget ??
          NotFoundPageWidget(
            redirectRoute: _navigationZones.first.first,
          ),
      initialLocation: _initialLocation,
      refreshListenable: _refreshListenable,
      redirect: _redirect,
      manualRedirect: _manualRedirect,
      pageFactory: _pageFactory,
    );
  }

  /// Validate the configuration before building
  void _validateConfiguration() {
    if (_navigationZones.isEmpty) {
      throw ArgumentError('At least one navigation zone must be provided');
    }

    if (_navigationZones.any((zone) => zone.isEmpty)) {
      throw ArgumentError('Navigation zones cannot contain empty zones');
    }

    // Validate initial location if provided
    if (_initialLocation != null) {
      if (!_initialLocation!.startsWith('/')) {
        throw ArgumentError('Initial location must start with "/"');
      }

      // Check if initial location matches any route
      final allRoutes = _navigationZones.expand((zone) => zone).toList();
      final hasMatchingRoute = allRoutes.any((route) =>
          route.routePath == _initialLocation ||
          _initialLocation!.startsWith(route.routePath));

      if (!hasMatchingRoute) {
        throw ArgumentError(
            'Initial location "$_initialLocation" does not match any defined route');
      }
    }
  }
}
