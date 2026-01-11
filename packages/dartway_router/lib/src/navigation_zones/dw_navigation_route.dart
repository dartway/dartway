import 'package:flutter/material.dart';

import 'dw_navigation_route_descriptor.dart';
import 'dw_navigation_types.dart';

abstract class DwNavigationRoute<NavigationNotifier extends Listenable>
    implements Enum {
  final DwNavigationRouteDescriptor descriptor;

  DwNavigationRoute(this.descriptor);

  String get zoneRoot;

  DwShellRoutePageBuilder? get shellRouteBuilder;

  List<DwNavigationGuard<NavigationNotifier>> get zoneGuards;
}
