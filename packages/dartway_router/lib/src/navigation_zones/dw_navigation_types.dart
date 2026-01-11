import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

typedef DwNavigationGuard<NavigationNotifier extends Listenable> = String?
    Function(
  NavigationNotifier refreshListenable,
);

typedef DwShellRoutePageBuilder = Page<dynamic> Function(
  BuildContext context,
  GoRouterState state,
  Widget child,
);
