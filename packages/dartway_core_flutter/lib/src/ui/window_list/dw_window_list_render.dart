part of 'dw_window_list_view.dart';

/// What the physics and the end clamp ask the list.
abstract interface class _DwWindowScrollGate {
  /// The list showed the newest items of the sequence in the last frame, so
  /// standing at its end means following them.
  bool get followsNewest;

  /// Nobody is scrolling: blank space under the newest item is a position to
  /// correct, not an overscroll to leave alone.
  bool get clampsEnd;
}

/// The platform's physics, plus staying at the end: when the list stood at
/// its end and the end moves (a new item, a picture that loaded, a taller
/// edited message), the position moves with it in the same layout — nothing
/// is seen to jump.
final class _DwWindowScrollPhysics extends ScrollPhysics {
  _DwWindowScrollPhysics(this._gate, {super.parent});

  final _DwWindowScrollGate _gate;

  @override
  _DwWindowScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      _DwWindowScrollPhysics(_gate, parent: buildParent(ancestor));

  @override
  double adjustPositionForNewDimensions({
    required ScrollMetrics oldPosition,
    required ScrollMetrics newPosition,
    required bool isScrolling,
    required double velocity,
  }) {
    if (!isScrolling &&
        _gate.followsNewest &&
        oldPosition.pixels >= oldPosition.maxScrollExtent - 0.5 &&
        newPosition.maxScrollExtent != oldPosition.maxScrollExtent) {
      return newPosition.maxScrollExtent;
    }
    return super.adjustPositionForNewDimensions(
      oldPosition: oldPosition,
      newPosition: newPosition,
      isScrolling: isScrolling,
      velocity: velocity,
    );
  }
}

/// The last sliver: while nobody scrolls, a position past the end — an
/// opening offset that assumed more items after the anchor than there are,
/// an item removed at the end — is corrected during the same layout, so the
/// list never shows blank space under its newest item and never springs
/// back into place.
class _DwEndClamp extends LeafRenderObjectWidget {
  const _DwEndClamp({required this.gate});

  final _DwWindowScrollGate gate;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _DwRenderEndClamp(gate);

  @override
  void updateRenderObject(
    BuildContext context,
    _DwRenderEndClamp renderObject,
  ) {
    renderObject.gate = gate;
  }
}

class _DwRenderEndClamp extends RenderSliver {
  _DwRenderEndClamp(this.gate);

  _DwWindowScrollGate gate;

  @override
  void performLayout() {
    // Laid out after every sliver below the split, so what is left of the
    // viewport past them — plus whatever they fell short of reaching — is
    // exactly how far the position overshoots the end.
    final overshoot =
        constraints.scrollOffset + constraints.remainingPaintExtent;
    if (overshoot > 0.5 && gate.clampsEnd) {
      geometry = SliverGeometry(scrollOffsetCorrection: -overshoot);
      return;
    }
    geometry = SliverGeometry.zero;
  }
}
