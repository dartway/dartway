import 'package:dartway_studio_bridge/dartway_studio_bridge.dart';
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
    DwFeatureSpec(id: id, title: StudioText(id, id), description: const StudioText('d', 'д'));

void main() {
  group('DwFeatureSpec', () {
    test('json round-trip', () {
      final decoded = DwFeatureSpec.fromJson(_spec('x').toJson());
      expect(decoded.id, 'x');
      expect(decoded.title.en, 'x');
      expect(decoded.description.ru, 'д');
    });

    test('listFromJson tolerates non-list', () {
      expect(DwFeatureSpec.listFromJson(null), isEmpty);
      expect(DwFeatureSpec.listFromJson('nope'), isEmpty);
    });
  });

  testWidgets('scanMountedFeatures collects mounted features, deduped by id',
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

    final ids = scanMountedFeatures().map((f) => f.id).toList();
    expect(ids.toSet(), {'a', 'b'});
    expect(ids.length, 2);
  });

  testWidgets('scanMountedFeatures is empty with no DwFeature widgets',
      (tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    expect(scanMountedFeatures(), isEmpty);
  });
}
