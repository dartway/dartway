import 'package:dartway_router/dartway_router.dart';
import 'package:dartway_studio_bridge/dartway_studio_bridge.dart';

import '../../../core/router/router.dart';

/// Adapter from the app's typed routes to the bridge's path-based specs:
/// the only place where the router types and Studio declarations meet.
StudioScreenSpec studioSpecForRoute(
  DwNavigationRoute<AppRouterState> route, {
  required StudioText title,
  required StudioText purpose,
  List<StudioText> featureSpec = const [],
  List<StudioText> discussionQuestions = const [],
}) =>
    StudioScreenSpec(
      path: route.fullPath,
      parentPath: route.descriptor.parent?.fullPath,
      title: title,
      purpose: purpose,
      featureSpec: featureSpec,
      discussionQuestions: discussionQuestions,
    );
