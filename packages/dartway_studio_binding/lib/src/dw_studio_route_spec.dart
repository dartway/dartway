import 'package:dartway_router/dartway_router.dart';
import 'package:dartway_studio_bridge/dartway_studio_bridge.dart';
import 'package:flutter/foundation.dart';

/// Builds a screen passport from a typed route — the only place where the
/// router's enums and Studio's path-based declarations meet.
///
/// Taking the route rather than a string is the point: the path is derived,
/// so a path refactor cannot leave the manifest pointing at a screen that no
/// longer exists.
StudioScreenSpec dwStudioSpecForRoute(
  DwNavigationRoute<Listenable> route, {
  required String title,
  required String purpose,
  List<String> discussionQuestions = const [],
}) => StudioScreenSpec(
  path: route.fullPath,
  parentPath: route.descriptor.parent?.fullPath,
  title: title,
  purpose: purpose,
  discussionQuestions: discussionQuestions,
);
