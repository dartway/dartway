import 'package:dartway_router/dartway_router.dart';
import 'package:dartway_studio_bridge/dartway_studio_bridge.dart';

import '../../../core/router/router.dart';

/// Adapter from the app's typed routes to the bridge's path-based specs:
/// the only place where the router types and Studio declarations meet.
StudioScreenSpec studioSpecForRoute(
  DwNavigationRoute<AppRouterState> route, {
  required String title,
  required String purpose,
  List<String> featureSpec = const [],
  List<String> discussionQuestions = const [],
}) =>
    StudioScreenSpec(
      path: route.fullPath,
      parentPath: route.descriptor.parent?.fullPath,
      title: title,
      purpose: purpose,
      featureSpec: featureSpec,
      discussionQuestions: discussionQuestions,
    );
