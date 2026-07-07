import 'package:flutter/widgets.dart';

import '../models/dw_feature_spec.dart';
import 'dw_feature.dart';

/// Collects the [DwFeatureSpec]s of every mounted [DwFeature] widget, keyed by
/// id (so a feature declared by many instances appears once). Only the active
/// route's subtree is mounted, so this yields the current screen's features.
///
/// Call from a post-frame callback after the route settles — a widget mounted
/// asynchronously afterwards is picked up by the next scan.
List<DwFeatureSpec> scanMountedFeatures() {
  final root = WidgetsBinding.instance.rootElement;
  if (root == null) return const [];

  final found = <String, DwFeatureSpec>{};
  void visit(Element element) {
    final widget = element.widget;
    if (widget is DwFeature) {
      final feature = (widget as DwFeature).dwFeature;
      found[feature.id] = feature;
    }
    element.visitChildren(visit);
  }

  root.visitChildren(visit);
  return found.values.toList();
}
