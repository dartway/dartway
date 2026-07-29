import 'package:dartway_studio_bridge/dartway_studio_bridge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StudioFeatureInfo', () {
    test('json round-trip', () {
      const info = StudioFeatureInfo(
        id: 'x',
        title: 'X',
        purpose: 'why it exists',
        behaviors: ['tapping opens details'],
        requirements: ['signed-in users only'],
        implementationNotes: ['preview image in the row'],
      );
      final decoded = StudioFeatureInfo.fromJson(info.toJson());
      expect(decoded.id, 'x');
      expect(decoded.title, 'X');
      expect(decoded.purpose, 'why it exists');
      expect(decoded.behaviors, ['tapping opens details']);
      expect(decoded.requirements, ['signed-in users only']);
      expect(decoded.implementationNotes, ['preview image in the row']);
    });

    test('an app built against an older bridge still decodes', () {
      final decoded = StudioFeatureInfo.fromJson(const {
        'id': 'a',
        'title': 'A',
        'description': 'a field this bridge no longer knows',
      });
      expect(decoded.id, 'a');
      expect(decoded.title, 'A');
      expect(decoded.purpose, isNull);
      expect(decoded.behaviors, isEmpty);
    });

    test('fromJson tolerates missing fields', () {
      final decoded = StudioFeatureInfo.fromJson(const {});
      expect(decoded.id, '');
      expect(decoded.title, '');
      expect(decoded.behaviors, isEmpty);
      expect(decoded.requirements, isEmpty);
      expect(decoded.implementationNotes, isEmpty);
    });

    test('empty lists and a null purpose stay out of the wire payload', () {
      const info = StudioFeatureInfo(id: 'x', title: 'X');
      expect(info.toJson().keys, ['id', 'title']);
    });

    test('listFromJson tolerates non-list and foreign items', () {
      expect(StudioFeatureInfo.listFromJson(null), isEmpty);
      expect(StudioFeatureInfo.listFromJson('nope'), isEmpty);
      expect(
        StudioFeatureInfo.listFromJson([
          {'id': 'a', 'title': 'A'},
          42,
        ]).single.id,
        'a',
      );
    });
  });
}
