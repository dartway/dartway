import 'package:dartway_studio_bridge/dartway_studio_bridge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StudioFeatureInfo', () {
    test('json round-trip', () {
      const info = StudioFeatureInfo(id: 'x', title: 'X', description: 'd');
      final decoded = StudioFeatureInfo.fromJson(info.toJson());
      expect(decoded.id, 'x');
      expect(decoded.title, 'X');
      expect(decoded.description, 'd');
    });

    test('fromJson tolerates missing fields', () {
      final decoded = StudioFeatureInfo.fromJson(const {});
      expect(decoded.id, '');
      expect(decoded.title, '');
      expect(decoded.description, '');
    });

    test('listFromJson tolerates non-list and foreign items', () {
      expect(StudioFeatureInfo.listFromJson(null), isEmpty);
      expect(StudioFeatureInfo.listFromJson('nope'), isEmpty);
      expect(
        StudioFeatureInfo.listFromJson([
          {'id': 'a', 'title': 'A', 'description': ''},
          42,
        ]).single.id,
        'a',
      );
    });
  });
}
