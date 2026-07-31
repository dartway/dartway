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
    this.knownIssues = const [],
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

  /// What is wrong here and worth taking into work: a setting nothing reads,
  /// a screen still wired to mock data, a sort order that was commented out
  /// while the field feeding it stayed in the form.
  ///
  /// The line between this and [implementationNotes] is what the reader is
  /// meant to do about the entry. A note says "this is deliberate, leave it";
  /// an issue says "this is not right, fix it" — and an agent editing the
  /// feature must be able to tell them apart before it touches anything. The
  /// test: *if someone fixed it, would the entry disappear?* If yes, it is an
  /// issue; if it would survive as an explanation, it is a note.
  ///
  /// Keep entries to one sentence: what is wrong and what it costs. This is a
  /// pointer for whoever picks the feature up, not a tracker — the tracker
  /// item is written from it, and this entry is deleted once the fix lands.
  final List<String> knownIssues;

  /// Whether the feature carries anything worth taking into work. Studio
  /// filters on this, so it lives here rather than in every caller.
  bool get hasKnownIssues => knownIssues.isNotEmpty;
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
  /// Deduplication is per id and never prunes a subtree: the walk continues
  /// through a feature it has already seen. A list of near-identical cards
  /// therefore yields one entry for the card, plus any nested feature that only
  /// some of the cards build — collapsing to the first card's subtree instead
  /// would silently drop the extras the later ones carry.
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
      if (_isParkedOffscreen(element.widget)) return;
      if (element.widget case DwFeature feature) {
        found[feature.dwFeature.id] = feature.dwFeature;
      }
      element.visitChildren(visit);
    }

    root.visitChildren(visit);
    return found.values.toList();
  }

  /// The [DwFeatureSpec] at [globalPosition] (Studio's inspect-by-tap: pick a
  /// screen point, describe whatever is there), or null over nothing declared.
  ///
  /// The last match wins rather than the first: a card and a "more actions"
  /// row inside it can both contain the same point, and the row is what the
  /// tap actually landed on. Depth-first order with no early return already
  /// gives this for free — a child is visited, and so overwrites `found`,
  /// after its parent.
  static DwFeatureSpec? hitTest(Offset globalPosition) {
    final root = WidgetsBinding.instance.rootElement;
    if (root == null) return null;

    DwFeatureSpec? found;
    void visit(Element element) {
      if (_isParkedOffscreen(element.widget)) return;
      if (element.widget case DwFeature feature) {
        final renderObject = element.renderObject;
        if (renderObject is RenderBox && renderObject.attached) {
          final rect = renderObject.localToGlobal(Offset.zero) &
              renderObject.size;
          if (rect.contains(globalPosition)) found = feature.dwFeature;
        }
      }
      element.visitChildren(visit);
    }

    root.visitChildren(visit);
    return found;
  }

  /// Whether [widget] roots a subtree Flutter itself parks out of sight:
  /// see [scanMounted] for why being mounted is not the same as being on
  /// screen.
  static bool _isParkedOffscreen(Widget widget) =>
      (widget is Offstage && widget.offstage) ||
      (widget is Visibility && !widget.visible) ||
      (widget is TickerMode && !widget.enabled);
}
