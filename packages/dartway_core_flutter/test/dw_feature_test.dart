import 'package:dartway_core_flutter/dartway_core_flutter.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class _FeatureBox extends StatelessWidget implements DwFeatureWidget {
  const _FeatureBox(this.spec);

  final DwFeatureSpec spec;

  @override
  DwFeatureSpec get dwFeature => spec;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// A feature that hosts a subtree — the shape of a card that may or may not
/// build a nested feature of its own.
class _FeatureGroup extends StatelessWidget implements DwFeatureWidget {
  const _FeatureGroup(this.spec, {this.child});

  final DwFeatureSpec spec;
  final Widget? child;

  @override
  DwFeatureSpec get dwFeature => spec;

  @override
  Widget build(BuildContext context) => child ?? const SizedBox.shrink();
}

/// A [DwFeatureWidget] widget with a concrete, hit-testable size — [_FeatureBox]
/// renders a zero-size box, which never intersects a hit-test point. A
/// [child] gets the same size as its parent (`SizedBox` imposes tight
/// constraints), which is exactly what a card's nested row does.
class _SizedFeature extends StatelessWidget implements DwFeatureWidget {
  const _SizedFeature(this.spec, {this.child});

  final DwFeatureSpec spec;
  final Widget? child;

  @override
  DwFeatureSpec get dwFeature => spec;

  @override
  Widget build(BuildContext context) =>
      SizedBox(width: 100, height: 100, child: child);
}

DwFeatureSpec _spec(String id) =>
    DwFeatureSpec(id: id, title: id, behaviors: const ['does a thing']);

void main() {
  testWidgets(
    'DwFeatureWidget.scanMounted collects mounted features, deduped by id',
    (tester) async {
      await tester.pumpWidget(
        Column(
          children: [
            _FeatureBox(_spec('a')),
            _FeatureBox(_spec('b')),
            _FeatureBox(_spec('a')), // duplicate id — collapses to one
          ],
        ),
      );

      final ids = DwFeatureWidget.scanMounted().map((f) => f.id).toList();
      expect(ids.toSet(), {'a', 'b'});
      expect(ids.length, 2);
    },
  );

  // Deduplication is per id, not per subtree, and the walk never stops at a
  // feature it has already seen. It matters for a list of near-identical cards:
  // collapsing to the first card's subtree would lose a nested feature only
  // some cards build — a "more actions" row on the one card that has extras.
  testWidgets('DwFeatureWidget.scanMounted keeps a nested feature only one instance '
      'of a repeated card builds', (tester) async {
    await tester.pumpWidget(
      Column(
        children: [
          _FeatureGroup(_spec('ad/card')),
          _FeatureGroup(_spec('ad/card')),
          _FeatureGroup(
            _spec('ad/card'),
            child: _FeatureBox(_spec('ad/card/more-actions')),
          ),
        ],
      ),
    );

    final ids = DwFeatureWidget.scanMounted().map((feature) => feature.id).toList();
    expect(ids.toSet(), {'ad/card', 'ad/card/more-actions'});
    expect(ids.length, 2);
  });

  testWidgets('DwFeatureWidget.scanMounted is empty with no DwFeatureWidget widgets', (
    tester,
  ) async {
    await tester.pumpWidget(const SizedBox.shrink());
    expect(DwFeatureWidget.scanMounted(), isEmpty);
  });

  // Mounted is not the same as on screen. An app that keeps a bottom-nav tab
  // alive behind an IndexedStack, or a route under a pushed one, leaves those
  // subtrees mounted — and reporting them would claim every screen hosts the
  // whole app.
  testWidgets('DwFeatureWidget.scanMounted skips unselected IndexedStack children', (
    tester,
  ) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: IndexedStack(
          index: 1,
          children: [_FeatureBox(_spec('behind')), _FeatureBox(_spec('shown'))],
        ),
      ),
    );

    expect(DwFeatureWidget.scanMounted().map((f) => f.id), ['shown']);
  });

  testWidgets('DwFeatureWidget.scanMounted skips an offstage subtree', (
    tester,
  ) async {
    await tester.pumpWidget(
      Column(
        children: [
          Offstage(child: _FeatureBox(_spec('parked'))),
          _FeatureBox(_spec('shown')),
        ],
      ),
    );

    expect(DwFeatureWidget.scanMounted().map((f) => f.id), ['shown']);
  });

  testWidgets('DwFeatureWidget.scanMounted skips a disabled TickerMode subtree', (
    tester,
  ) async {
    await tester.pumpWidget(
      Column(
        children: [
          // What Overlay wraps the routes below an opaque one in.
          TickerMode(enabled: false, child: _FeatureBox(_spec('under-route'))),
          TickerMode(enabled: true, child: _FeatureBox(_spec('shown'))),
        ],
      ),
    );

    expect(DwFeatureWidget.scanMounted().map((f) => f.id), ['shown']);
  });

  group('DwFeatureWidget.hitTest', () {
    testWidgets('returns the feature under the point', (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SizedFeature(_spec('left')),
              _SizedFeature(_spec('right')),
            ],
          ),
        ),
      );

      Offset centerOf(String id) => tester.getCenter(
        find.byWidgetPredicate(
          (widget) => widget is _SizedFeature && widget.spec.id == id,
        ),
      );

      expect(DwFeatureWidget.hitTest(centerOf('left'))?.id, 'left');
      expect(DwFeatureWidget.hitTest(centerOf('right'))?.id, 'right');
    });

    testWidgets('is null over a point nothing declared covers', (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: _SizedFeature(_spec('only')),
        ),
      );

      expect(DwFeatureWidget.hitTest(const Offset(9999, 9999)), isNull);
    });

    // A card and a "more actions" row it may or may not build can both cover
    // the same point — the tap landed on whichever is actually drawn there,
    // and that is the nested one.
    testWidgets('returns the innermost feature when nested features overlap', (
      tester,
    ) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: _SizedFeature(
            _spec('ad/card'),
            child: _SizedFeature(_spec('ad/card/more-actions')),
          ),
        ),
      );

      final center = tester.getCenter(
        find.byWidgetPredicate(
          (widget) => widget is _SizedFeature && widget.spec.id == 'ad/card',
        ),
      );
      expect(DwFeatureWidget.hitTest(center)?.id, 'ad/card/more-actions');
    });

    // hitTest bypasses Flutter's own hit-testing (it checks render bounds
    // directly), so it must repeat the offstage/invisible/disabled-ticker
    // skip itself — an offstage subtree still lays out with a real size.
    testWidgets('skips an offstage feature', (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Offstage(child: _SizedFeature(_spec('parked'))),
        ),
      );

      expect(DwFeatureWidget.hitTest(const Offset(50, 50)), isNull);
    });

    // A scaled subtree draws smaller than it lays out. Matching on the
    // unscaled size would claim the empty space next to it — the case a
    // zoomable canvas or a running page transition puts on screen.
    testWidgets('matches the scaled area, not the laid-out one', (
      tester,
    ) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: Transform.scale(
              scale: 0.5,
              alignment: Alignment.topLeft,
              child: _SizedFeature(_spec('scaled')),
            ),
          ),
        ),
      );

      // Laid out 100x100, drawn 50x50 at the top-left corner.
      expect(DwFeatureWidget.hitTest(const Offset(20, 20))?.id, 'scaled');
      expect(DwFeatureWidget.hitTest(const Offset(70, 70)), isNull);
    });

    // A list item scrolled past the edge of its viewport keeps its layout
    // position and paints nothing. Being deeper in the tree it would win the
    // last-match-wins rule, so it has to be cut by the viewport's clip.
    testWidgets('skips a feature clipped away by a scroll viewport', (
      tester,
    ) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 100,
              height: 100, // one item tall
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _SizedFeature(_spec('in-view')),
                    _SizedFeature(_spec('below-the-fold')),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      expect(DwFeatureWidget.hitTest(const Offset(50, 50))?.id, 'in-view');
      // 'below-the-fold' lays out at y 100..200 — outside the viewport, drawn
      // nowhere.
      expect(DwFeatureWidget.hitTest(const Offset(50, 150)), isNull);
    });
  });
}
