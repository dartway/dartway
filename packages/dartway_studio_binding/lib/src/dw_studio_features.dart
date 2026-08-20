import 'package:dartway_flutter/dartway_flutter.dart';
import 'package:dartway_studio_bridge/dartway_studio_bridge.dart';
import 'package:flutter/widgets.dart';

/// Maps a feature's own passport onto the bridge wire model — the join between
/// the app's semantic layer (`DwFeatureSpec`, declared next to the widget) and
/// what Studio renders beside the running app.
StudioFeatureInfo dwStudioFeatureInfo(DwFeatureSpec feature) =>
    StudioFeatureInfo(
      id: feature.id,
      title: feature.title,
      purpose: feature.purpose,
      behaviors: feature.behaviors,
      requirements: feature.requirements,
      implementationNotes: feature.implementationNotes,
      knownIssues: feature.knownIssues,
    );

/// Every feature mounted right now, in wire form. Dart cannot enumerate specs
/// that are not on screen — the whole-project catalog is a job for static
/// analysis, not for the running app.
List<StudioFeatureInfo> dwStudioMountedFeatures() => [
  for (final feature in DwFeature.scanMounted()) dwStudioFeatureInfo(feature),
];

/// Answers Studio's "pencil" tap-to-inspect flow: the point arrives as
/// fractions of the app's own logical viewport, converted here (not by Studio,
/// which only knows how it is displaying the preview — framed, scaled — and
/// not what the app thinks its size is) into an [Offset] for
/// [DwFeature.hitTest].
StudioFeatureInfo? dwStudioFeatureAtPoint(
  double horizontalFraction,
  double verticalFraction,
) {
  final view = WidgetsBinding.instance.platformDispatcher.views.first;
  final logicalSize = view.physicalSize / view.devicePixelRatio;
  final feature = DwFeature.hitTest(
    Offset(
      horizontalFraction * logicalSize.width,
      verticalFraction * logicalSize.height,
    ),
  );
  return feature == null ? null : dwStudioFeatureInfo(feature);
}
