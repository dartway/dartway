import 'package:flutter/widgets.dart';

/// A product feature present on a screen, discovered at runtime from the widgets
/// that declare it (see [DwFeature]). The semantic layer of the app: feature
/// catalogs, error-report context, analytics, docs — and DartWay Studio
/// passports (delivered over the bridge by the app's binding).
class DwFeatureSpec {
  const DwFeatureSpec({
    required this.id,
    required this.title,
    required this.description,
  });

  /// Stable id — deduplicates a feature declared by multiple widget instances.
  final String id;

  final String title;
  final String description;
}

/// Implemented by a widget that *is* a product feature on a screen. A contract,
/// not behavior: the widget only declares its descriptor. Discover the mounted
/// features of the current screen with [DwFeature.scanMounted].
///
/// ```dart
/// class ScheduleSessionList extends ConsumerWidget implements DwFeature {
///   @override
///   DwFeatureSpec get dwFeature => const DwFeatureSpec(id: 'schedule-list', ...);
/// }
/// ```
abstract interface class DwFeature {
  DwFeatureSpec get dwFeature;

  /// The [DwFeatureSpec]s of every mounted [DwFeature] widget, keyed by id (a
  /// feature declared by several instances appears once).
  ///
  /// Scans from the app root — not a [BuildContext] — on purpose: only the
  /// active route's subtree is mounted, so this is the whole current screen's
  /// feature set, which is exactly what an error report or a Studio passport
  /// wants. Call from a post-frame callback after the route settles; a widget
  /// mounted asynchronously afterwards is picked up by the next scan.
  static List<DwFeatureSpec> scanMounted() {
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
}
