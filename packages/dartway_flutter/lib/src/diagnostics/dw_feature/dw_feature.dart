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

  /// What the code cannot say about itself: why it is done this way, a trap
  /// invisible from the outside, a decision someone would otherwise re-open.
  ///
  /// Written for the team, not for the client — Studio shows it on the
  /// technical side, away from the product panel.
  ///
  /// The name invites a wider reading than it should, so it comes with a test:
  /// *would this still be worth reading after the feature is rewritten?* A
  /// reason survives ("the list is not cached: it changes more often than it is
  /// read"); a trap survives ("the server sends the date in UTC, the screen
  /// shows it local"). A map of the code does not — "the list comes from
  /// `dw.repo.modelList` and is drawn by a `ListView`" is what the file already
  /// says, and unlike the file it starts lying the moment someone moves the
  /// widget. Nothing checks it: not the compiler, not `dartway check`.
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
  ///
  /// A feature is matched on the area it actually *paints* into — see
  /// [_paintedGlobalRect] for what that excludes. This is a walk of the widget
  /// tree, not Flutter's own hit test: going from the hit render objects back
  /// to the widgets that declared them needs an element, and a `RenderObject`
  /// has no way back to one outside debug mode.
  static DwFeatureSpec? hitTest(Offset globalPosition) {
    final root = WidgetsBinding.instance.rootElement;
    if (root == null) return null;

    DwFeatureSpec? found;
    void visit(Element element) {
      if (_isParkedOffscreen(element.widget)) return;
      if (element.widget case DwFeature feature) {
        final rect = _paintedGlobalRect(element.renderObject);
        if (rect != null && rect.contains(globalPosition)) {
          found = feature.dwFeature;
        }
      }
      element.visitChildren(visit);
    }

    root.visitChildren(visit);
    return found;
  }

  /// Where [renderObject] lands on screen, in global coordinates — or null if
  /// it lands nowhere visible.
  ///
  /// Two things a plain `localToGlobal(Offset.zero) & size` gets wrong, and
  /// both of them make [hitTest] name a feature the user cannot see at that
  /// point:
  ///
  /// * **Transforms.** The size is the *unscaled* one, so a subtree under a
  ///   `Transform.scale(0.5)` (a zoomable canvas, a running page transition)
  ///   claims twice the area it draws. The full transform to the root fixes
  ///   both the scale and any rotation's bounding box.
  /// * **Clips.** A list item scrolled past the edge of its viewport keeps its
  ///   layout position and answers for a point where it paints nothing — and
  ///   being deeper in the tree, it would beat the visible feature there.
  ///   Every ancestor clip cuts the rect down; an empty result means the
  ///   feature is scrolled or clipped away entirely.
  static Rect? _paintedGlobalRect(RenderObject? renderObject) {
    if (renderObject is! RenderBox ||
        !renderObject.attached ||
        !renderObject.hasSize) {
      return null;
    }

    var rect = MatrixUtils.transformRect(
      renderObject.getTransformTo(null),
      Offset.zero & renderObject.size,
    );

    var child = renderObject as RenderObject;
    for (
      var ancestor = child.parent;
      ancestor != null;
      child = ancestor, ancestor = ancestor.parent
    ) {
      final clip = ancestor.describeApproximatePaintClip(child);
      if (clip == null) continue;
      rect = rect.intersect(
        MatrixUtils.transformRect(ancestor.getTransformTo(null), clip),
      );
      if (rect.isEmpty) return null;
    }
    return rect;
  }

  /// Whether [widget] roots a subtree Flutter itself parks out of sight:
  /// see [scanMounted] for why being mounted is not the same as being on
  /// screen.
  static bool _isParkedOffscreen(Widget widget) =>
      (widget is Offstage && widget.offstage) ||
      (widget is Visibility && !widget.visible) ||
      (widget is TickerMode && !widget.enabled);
}
