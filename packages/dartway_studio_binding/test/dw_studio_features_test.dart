import 'package:dartway_flutter/dartway_flutter.dart';
import 'package:dartway_studio_binding/dartway_studio_binding.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _NewsListFeature extends StatelessWidget implements DwFeature {
  const _NewsListFeature();

  @override
  DwFeatureSpec get dwFeature =>
      const DwFeatureSpec(id: 'news.list', title: 'News list');

  @override
  Widget build(BuildContext context) => const Text('news');
}

void main() {
  test('a passport crosses to the wire whole', () {
    const spec = DwFeatureSpec(
      id: 'schedule.week',
      title: 'Week schedule',
      purpose: 'See what is on this week.',
      behaviors: ['tapping a slot opens the booking sheet'],
      requirements: ['signed-in users only'],
      implementationNotes: ['the week starts on Monday, server-side'],
      knownIssues: ['the empty state is untranslated'],
    );

    final wire = dwStudioFeatureInfo(spec);

    // Field by field on purpose: a field added to DwFeatureSpec and forgotten
    // here would travel as silence — Studio would render a passport missing a
    // section, with nothing anywhere reporting a fault.
    expect(wire.id, 'schedule.week');
    expect(wire.title, 'Week schedule');
    expect(wire.purpose, 'See what is on this week.');
    expect(wire.behaviors, ['tapping a slot opens the booking sheet']);
    expect(wire.requirements, ['signed-in users only']);
    expect(wire.implementationNotes, [
      'the week starts on Monday, server-side',
    ]);
    expect(wire.knownIssues, ['the empty state is untranslated']);
  });

  test(
    'a feature that declares only the required two carries no leftovers',
    () {
      final wire = dwStudioFeatureInfo(
        const DwFeatureSpec(id: 'news.card', title: 'News card'),
      );

      expect(wire.purpose, isNull);
      expect(wire.behaviors, isEmpty);
      expect(wire.requirements, isEmpty);
      expect(wire.implementationNotes, isEmpty);
      expect(wire.knownIssues, isEmpty);
    },
  );

  testWidgets('only the features actually mounted are reported', (
    tester,
  ) async {
    expect(dwStudioMountedFeatures(), isEmpty);

    await tester.pumpWidget(const MaterialApp(home: _NewsListFeature()));

    expect(dwStudioMountedFeatures().map((f) => f.id), ['news.list']);

    // Dart cannot enumerate specs that are not on screen — that is the whole
    // reason the catalog is a job for static analysis and this is a job for
    // the running app.
    await tester.pumpWidget(const MaterialApp(home: Text('nothing')));

    expect(dwStudioMountedFeatures(), isEmpty);
  });
}
