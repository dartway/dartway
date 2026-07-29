import 'package:flutter/widgets.dart';

/// A product feature present on a screen, discovered at runtime from the widgets
/// that declare it (see [DwFeature]). The semantic layer of the app: feature
/// catalogs, error-report context, analytics, docs — and DartWay Studio
/// passports (delivered over the bridge by the app's binding).
class DwFeatureSpec {
  const DwFeatureSpec({
    required this.id,
    required this.title,
    this.purpose,
    this.behaviors = const [],
    this.requirements = const [],
    this.implementationNotes = const [],
  });

  /// Stable id — deduplicates a feature declared by multiple widget instances,
  /// and is the name everything outside the code refers the feature by: Studio
  /// passports, feedback, tracker items. It is a contract, so it survives the
  /// folder being moved or renamed: never rewrite an id in place — add a new
  /// one and retire the old.
  final String id;

  /// Short human name, as the team would say it out loud.
  final String title;

  /// Why the feature exists for the user. Optional on purpose: a card or a row
  /// usually has no purpose of its own — it belongs to the screen it serves,
  /// and repeating the screen's purpose on every part of it is noise.
  final String? purpose;

  /// What the feature observably does, one checkable statement per entry
  /// ("tapping a card opens the details dialog", "with no subtitle the second
  /// line is not rendered").
  ///
  /// The rule that keeps this field useful: every entry must be verifiable by
  /// looking at the running app. The moment "works nicely with long titles"
  /// appears here, the field has turned back into prose.
  final List<String> behaviors;

  /// What the feature must honour, imposed from outside it: signed-in users
  /// only, no price before confirmation, works offline. Anything that can be
  /// phrased as an observable action belongs in [behaviors] instead.
  final List<String> requirements;

  /// Decisions a reader would otherwise re-open: why the preview image in the
  /// row and the full one in the list, why the height lives in the kit.
  ///
  /// Written for the team, not for the client — Studio shows it on the
  /// technical side, away from the product panel.
  final List<String> implementationNotes;
}

/// Implemented by a widget that *is* a product feature on a screen. A contract,
/// not behavior: the widget only declares its descriptor. Discover the mounted
/// features of the current screen with [DwFeature.scanMounted].
///
/// ```dart
/// class ScheduleSessionList extends ConsumerWidget implements DwFeature {
///   @override
///   DwFeatureSpec get dwFeature => const DwFeatureSpec(
///         id: 'schedule/session_list',
///         title: 'Session list',
///         behaviors: ['A session with no seats left is shown as full'],
///       );
/// }
/// ```
abstract interface class DwFeature {
  DwFeatureSpec get dwFeature;

  /// The [DwFeatureSpec]s of every [DwFeature] widget currently *on screen*,
  /// keyed by id (a feature declared by several instances appears once).
  ///
  /// Scans from the app root — not a [BuildContext] — on purpose: this is the
  /// whole current screen's feature set, which is exactly what an error report
  /// or a Studio passport wants. Call from a post-frame callback after the
  /// route settles; a widget mounted asynchronously afterwards is picked up by
  /// the next scan.
  ///
  /// Being mounted is not the same as being on screen, and the difference is
  /// not an edge case: an inactive bottom-nav tab kept alive behind an
  /// `IndexedStack`, or the route sitting under a pushed opaque one, stays in
  /// the element tree. Counting those would report roughly the whole app on
  /// every screen. So the walk stops at the three widgets Flutter itself uses
  /// to park a subtree out of sight: an offstage [Offstage], an invisible
  /// [Visibility] (what `IndexedStack` wraps its unselected children in) and a
  /// disabled [TickerMode] (what `Overlay` wraps the routes below an opaque
  /// one in).
  static List<DwFeatureSpec> scanMounted() {
    final root = WidgetsBinding.instance.rootElement;
    if (root == null) return const [];

    final found = <String, DwFeatureSpec>{};
    void visit(Element element) {
      final widget = element.widget;
      if (widget is Offstage && widget.offstage) return;
      if (widget is Visibility && !widget.visible) return;
      if (widget is TickerMode && !widget.enabled) return;
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
