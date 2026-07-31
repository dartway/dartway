import 'package:dartway_flutter/dartway_flutter.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class _FeatureBox extends StatelessWidget implements DwFeature {
  const _FeatureBox(this.spec);

  final DwFeatureSpec spec;

  @override
  DwFeatureSpec get dwFeature => spec;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// A feature that hosts a subtree — the shape of a card that may or may not
/// build a nested feature of its own.
class _FeatureGroup extends StatelessWidget implements DwFeature {
  const _FeatureGroup(this.spec, {this.child});

  final DwFeatureSpec spec;
  final Widget? child;

  @override
  DwFeatureSpec get dwFeature => spec;

  @override
  Widget build(BuildContext context) => child ?? const SizedBox.shrink();
}

/// A [DwFeature] widget with a concrete, hit-testable size — [_FeatureBox]
/// renders a zero-size box, which never intersects a hit-test point. A
/// [child] gets the same size as its parent (`SizedBox` imposes tight
/// constraints), which is exactly what a card's nested row does.
class _SizedFeature extends StatelessWidget implements DwFeature {
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
  testWidgets('DwFeature.scanMounted collects mounted features, deduped by id',
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

    final ids = DwFeature.scanMounted().map((f) => f.id).toList();
    expect(ids.toSet(), {'a', 'b'});
    expect(ids.length, 2);
  });

  // Deduplication is per id, not per subtree, and the walk never stops at a
  // feature it has already seen. It matters for a list of near-identical cards:
  // collapsing to the first card's subtree would lose a nested feature only
  // some cards build — a "more actions" row on the one card that has extras.
  testWidgets('DwFeature.scanMounted keeps a nested feature only one instance '
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

    final ids = DwFeature.scanMounted().map((feature) => feature.id).toList();
    expect(ids.toSet(), {'ad/card', 'ad/card/more-actions'});
    expect(ids.length, 2);
  });

  testWidgets('DwFeature.scanMounted is empty with no DwFeature widgets',
      (tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    expect(DwFeature.scanMounted(), isEmpty);
  });

  // Mounted is not the same as on screen. An app that keeps a bottom-nav tab
  // alive behind an IndexedStack, or a route under a pushed one, leaves those
  // subtrees mounted — and reporting them would claim every screen hosts the
  // whole app.
  testWidgets('DwFeature.scanMounted skips unselected IndexedStack children',
      (tester) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: IndexedStack(
          index: 1,
          children: [
            _FeatureBox(_spec('behind')),
            _FeatureBox(_spec('shown')),
          ],
        ),
      ),
    );

    expect(DwFeature.scanMounted().map((f) => f.id), ['shown']);
  });

  testWidgets('DwFeature.scanMounted skips an offstage subtree',
      (tester) async {
    await tester.pumpWidget(
      Column(
        children: [
          Offstage(child: _FeatureBox(_spec('parked'))),
          _FeatureBox(_spec('shown')),
        ],
      ),
    );

    expect(DwFeature.scanMounted().map((f) => f.id), ['shown']);
  });

  testWidgets('DwFeature.scanMounted skips a disabled TickerMode subtree',
      (tester) async {
    await tester.pumpWidget(
      Column(
        children: [
          // What Overlay wraps the routes below an opaque one in.
          TickerMode(enabled: false, child: _FeatureBox(_spec('under-route'))),
          TickerMode(enabled: true, child: _FeatureBox(_spec('shown'))),
        ],
      ),
    );

    expect(DwFeature.scanMounted().map((f) => f.id), ['shown']);
  });

  group('DwFeature.hitTest', () {
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

      expect(DwFeature.hitTest(centerOf('left'))?.id, 'left');
      expect(DwFeature.hitTest(centerOf('right'))?.id, 'right');
    });

    testWidgets('is null over a point nothing declared covers', (
      tester,
    ) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: _SizedFeature(_spec('only')),
        ),
      );

      expect(DwFeature.hitTest(const Offset(9999, 9999)), isNull);
    });

    // A card and a "more actions" row it may or may not build can both cover
    // the same point — the tap landed on whichever is actually drawn there,
    // and that is the nested one.
    testWidgets(
      'returns the innermost feature when nested features overlap',
      (tester) async {
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
        expect(DwFeature.hitTest(center)?.id, 'ad/card/more-actions');
      },
    );

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

      expect(DwFeature.hitTest(const Offset(50, 50)), isNull);
    });
  });
}
