import 'package:flutter/material.dart';

import 'dw_navigation_params_mixin.dart';
import 'dw_navigation_route.dart';

abstract class DwNavigationRouteDescriptor {
  const DwNavigationRouteDescriptor({
    required this.page,
    this.parent,
  });

  final Widget page;
  final DwNavigationRoute? parent;

  String? get path => null;
}

class SimpleNavigationRouteDescriptor extends DwNavigationRouteDescriptor {
  const SimpleNavigationRouteDescriptor({
    required super.page,
    super.parent,
    this.isZoneRoot = false,
  });

  final bool isZoneRoot;

  @override
  String? get path => isZoneRoot ? '' : super.path;
}

const String dwParameterSubstitutionPattern = 'dwParameterSubstitutionPattern';

class ParameterizedNavigationRouteDescriptor<ParameterType>
    extends DwNavigationRouteDescriptor {
  const ParameterizedNavigationRouteDescriptor({
    required this.parameter,
    required super.page,
    required super.parent,
    this.extraPathSegment,
  });
  final DwNavigationParamsMixin<ParameterType> parameter;
  final String? extraPathSegment;

  @override
  String get path => extraPathSegment != null
      ? '$extraPathSegment/:${parameter.name}'
      : ':${parameter.name}';
}
