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

DwFeatureSpec _spec(String id) =>
    DwFeatureSpec(id: id, title: id, description: 'd');

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
}
